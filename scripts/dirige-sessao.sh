#!/usr/bin/env bash
# Caminho de mão dupla com uma sessão dirigida: instruir, ler, assumir.
#
# Uso: dirige-sessao.sh <verbo> <painel> [args]
#   instruir <pane> <texto>   manda a instrução e espera a sessão voltar a parar
#   ler <pane> [linhas]       devolve a tela da sessão
#   processo <pane>           devolve o pid da sessão
#   assumir <pane>            entrega o volante ao dono, sem trocar de painel
#
# Ver o worker sem poder corrigi-lo custa matar e recomeçar vinte minutos de
# trabalho por um desvio de trinta segundos. Este script é o que evita isso.
#
# O que este script NÃO faz: não abre sessão, não fecha sessão, não lê material
# por arquivo. O canal é a tela, e é isso que o aceite cobra.
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$HERE/.."
# Quanto esperar a sessão SAIR de parada depois da instrução. O estado parado
# aparece antes de a instrução ser absorvida, então sem esta fase a espera
# terminaria no mesmo instante em que começou.
PARTIDA="${DIRIGE_PRAZO_PARTIDA_S:-10}"
# E quanto esperar ela VOLTAR. Prazo deste lado de propósito: a espera embutida
# da ferramenta já pendurou além de dois minutos com o worker já tendo
# respondido, e sessão principal pendurada é o defeito que a camada remove.
PRAZO="${DIRIGE_PRAZO_S:-180}"

die() { printf '%s\n' "$*" >&2; exit 1; }

# shellcheck disable=SC1091
source "$ROOT/skills/delegate/scripts/lib-visivel.sh" \
    || die "dirige-sessao: lib-visivel.sh não carregou"
ADAPTADOR=$(visivel_adaptador)
[[ -x "$ADAPTADOR" ]] || die "dirige-sessao: adaptador não encontrado em $ADAPTADOR"

VERBO="${1:-}"; PANE="${2:-}"
[[ -n "$VERBO" ]] || die "dirige-sessao: falta o verbo"
[[ -n "$PANE"  ]] || die "dirige-sessao: falta o painel"

parada() { # → rc 0 quando a sessão não está trabalhando
    local e; e=$("$ADAPTADOR" estado "$PANE")
    [[ "$e" == idle || "$e" == done || "$e" == blocked ]]
}

# A TUI leva segundos pra terminar de desenhar, e `agent_status` já diz parado
# antes disso. Texto que chega no meio do desenho se perde sem erro nenhum, e a
# sessão principal fica esperando resposta de uma instrução que ninguém recebeu.
# Tela que não muda entre duas leituras é o sinal genérico de pronta, e vale pros
# três workers medidos sem cada um precisar do seu padrão.
espera_tela_parar() { # → rc 0 quando a tela repete
    local antes agora fim
    fim=$(( SECONDS + PARTIDA ))
    agora=$("$ADAPTADOR" ler "$PANE" 40)
    while (( SECONDS < fim )); do
        sleep 2
        antes="$agora"; agora=$("$ADAPTADOR" ler "$PANE" 40)
        [[ -n "$agora" && "$agora" == "$antes" ]] && return 0
    done
    return 1
}

case "$VERBO" in
    instruir)
        [[ $# -ge 3 ]] || die "dirige-sessao: instruir precisa do texto"
        espera_tela_parar || true
        antes=$("$ADAPTADOR" ler "$PANE" 40)
        "$ADAPTADOR" instruir "$PANE" "$3" || exit 1
        fim=$(( SECONDS + PARTIDA ))
        partiu=0
        while (( SECONDS < fim )); do
            parada || { partiu=1; break; }
            sleep 1
        done
        # Worker que nem começou e tela que não mudou é instrução que se perdeu no
        # caminho. Sair zero aqui faz a sessão principal ler o eco do prompt como
        # se fosse resposta, que é pior que demorar.
        if (( ! partiu )) && [[ "$("$ADAPTADOR" ler "$PANE" 40)" == "$antes" ]]; then
            die "dirige-sessao: $PANE não absorveu a instrução em ${PARTIDA}s"
        fi
        fim=$(( SECONDS + PRAZO ))
        while (( SECONDS < fim )); do
            parada && exit 0
            sleep 2
        done
        die "dirige-sessao: $PANE não voltou a parar em ${PRAZO}s"
        ;;
    ler)
        # A tela é a fonte, e a única. Material que voltasse por arquivo seria o
        # caminho antigo de captura sobrevivendo dentro do caminho novo.
        "$ADAPTADOR" ler "$PANE" "${3:-120}"
        ;;
    processo)
        "$ADAPTADOR" processo "$PANE"
        ;;
    assumir)
        # Focar, e nada mais: painel novo, split ou sessão recomeçada perderiam
        # a conversa inteira, que é justamente o que o dono quer herdar.
        "$ADAPTADOR" focar "$PANE" || exit 1
        ;;
    *) die "dirige-sessao: verbo desconhecido: '$VERBO'" ;;
esac
