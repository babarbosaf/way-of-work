#!/usr/bin/env bash
# Adaptador da ferramenta de terminal. É o único arquivo do repo que sabe que a
# ferramenta se chama herdr, e existe por isso: trocar de ferramenta, ou não ter
# nenhuma, precisa ser um arquivo que muda e não uma caça ao nome espalhado.
#
# Uso: herdr-adapter.sh <verbo> [args]
#   disponivel                 rc 0 se a ferramenta está nesta máquina
#   abrir <cwd> <rotulo> [grupo]  cria a aba, devolve "pane_id<TAB>tab_id"
#   espacos                    "grupo<TAB>nome", um grupo por linha
#   criar-espaco <cwd> <nome>  cria o grupo; devolve "id<TAB>pane<TAB>tab" da raiz
#   rodar <pane> <comando>     entrega o comando ao shell da aba
#   ler <pane> [linhas]        devolve a tela visível
#   teclar <pane> <tecla>      manda uma tecla
#   listar                     "tab_id<TAB>rotulo<TAB>estado", uma aba por linha
#   rotular <tab> <rotulo>     renomeia a aba
#   fechar <tab>               fecha a aba
#   instruir <pane> <texto>    submete um prompt à sessão
#   estado <pane>              devolve o estado que a ferramenta observa
#   processo <pane>            devolve o pid do processo da sessão
#   focar <pane>               entrega o foco ao dono
#
# O adaptador traduz verbo em chamada, e só. Política de estado, de nome e de
# fechamento mora na lib do modo visível: adaptador que decide é adaptador que
# precisa ser reescrito inteiro quando a decisão muda.
set -uo pipefail

die() { printf '%s\n' "$*" >&2; exit 1; }
FERRAMENTA=herdr

VERBO="${1:-}"; shift || true
case "$VERBO" in
    disponivel)
        command -v "$FERRAMENTA" >/dev/null 2>&1 \
            || die "adaptador: $FERRAMENTA não está nesta máquina"
        ;;
    abrir)
        [[ $# -ge 2 ]] || die "adaptador: abrir precisa de cwd e rótulo"
        # Sem `local`: o case roda em escopo global, e `local` aqui falha em
        # runtime sem parar o script, que é o pior dos dois mundos.
        onde=()
        [[ -n "${3:-}" ]] && onde=(--workspace "$3")
        resposta=$("$FERRAMENTA" tab create --cwd "$1" --label "$2" "${onde[@]}" --no-focus 2>&1) \
            || die "adaptador: criar aba falhou: $resposta"
        # Painel e aba juntos de propósito: quem abre dirige pelo painel e fecha
        # pela aba, e voltar a perguntar qual aba é de qual painel é uma chamada
        # a mais que pode responder outra coisa.
        pane=$(jq -r '.result.root_pane.pane_id // empty' <<<"$resposta" 2>/dev/null)
        tab=$(jq -r '.result.tab.tab_id // .result.root_pane.tab_id // empty' <<<"$resposta" 2>/dev/null)
        [[ -n "$pane" ]] || die "adaptador: a ferramenta não devolveu o painel: $resposta"
        printf '%s\t%s\n' "$pane" "$tab"
        ;;
    rodar)
        [[ $# -ge 2 ]] || die "adaptador: rodar precisa de painel e comando"
        "$FERRAMENTA" pane run "$1" "$2" >/dev/null 2>&1 \
            || die "adaptador: rodar falhou no painel $1"
        ;;
    ler)
        [[ $# -ge 1 ]] || die "adaptador: ler precisa do painel"
        # `visible` é a única fonte que devolve a tela dos três workers medidos:
        # `recent` volta vazia no agy, e `screen` não existe.
        "$FERRAMENTA" pane read "$1" --source visible --lines "${2:-60}" 2>/dev/null
        ;;
    teclar)
        [[ $# -ge 2 ]] || die "adaptador: teclar precisa de painel e tecla"
        "$FERRAMENTA" agent send-keys "$1" "$2" >/dev/null 2>&1
        ;;
    listar)
        # Vazio e ilegível não podem ser a mesma coisa: quem varre apaga registro
        # de sessão que sumiu da lista, e lista muda apagaria todas de uma vez.
        # `-e` faz o jq reprovar quando `.result.tabs` não existe.
        "$FERRAMENTA" tab list 2>/dev/null \
            | jq -er '.result.tabs | .[]
                | [.tab_id, .label, (.agent_status // "")] | @tsv' 2>/dev/null
        rc=$?
        # rc 1 do jq é "saída vazia ou falsa", e lista sem nenhuma aba é isso.
        (( rc == 0 || rc == 1 )) || die "adaptador: não consegui ler a lista de abas"
        ;;
    rotular)
        [[ $# -ge 2 ]] || die "adaptador: rotular precisa de aba e rótulo"
        "$FERRAMENTA" tab rename "$1" "$2" >/dev/null 2>&1 \
            || die "adaptador: renomear a aba $1 falhou"
        ;;
    fechar)
        [[ $# -ge 1 ]] || die "adaptador: fechar precisa da aba"
        "$FERRAMENTA" tab close "$1" >/dev/null 2>&1 \
            || die "adaptador: fechar a aba $1 falhou"
        ;;
    espacos)
        "$FERRAMENTA" workspace list 2>/dev/null \
            | jq -r '.result.workspaces // [] | .[] | [.workspace_id, .label] | @tsv' 2>/dev/null
        ;;
    criar-espaco)
        [[ $# -ge 2 ]] || die "adaptador: criar-espaco precisa de cwd e nome"
        resposta=$("$FERRAMENTA" workspace create --cwd "$1" --label "$2" 2>&1) \
            || die "adaptador: criar grupo falhou: $resposta"
        # A raiz vem junto: o grupo nasce com uma aba, e quem não a reusa deixa
        # uma aba vazia por projeto pra sempre na lista do dono.
        jq -r '.result | [.workspace.workspace_id, (.root_pane.pane_id // ""),
                          (.root_pane.tab_id // "")] | @tsv' <<<"$resposta" 2>/dev/null
        ;;
    instruir)
        [[ $# -ge 2 ]] || die "adaptador: instruir precisa de painel e texto"
        # Texto literal, e não o canal de prompt da ferramenta. Medido em
        # 22/set/2026: `agent prompt` entrega instrução longa como conteúdo
        # colado, e o worker a recusa como tentativa de injeção, respondendo "não
        # executei nada". O mesmo texto digitado foi obedecido na hora.
        #
        # Sem `--wait` em lugar nenhum: a espera embutida já pendurou além de
        # dois minutos com o worker já tendo respondido, e quem sincroniza é quem
        # chama.
        "$FERRAMENTA" pane send-text "$1" "$2" >/dev/null 2>&1 \
            || die "adaptador: a instrução não entrou no painel $1"
        "$FERRAMENTA" agent send-keys "$1" enter >/dev/null 2>&1 \
            || die "adaptador: a instrução ficou na linha sem ser submetida em $1"
        ;;
    estado)
        [[ $# -ge 1 ]] || die "adaptador: estado precisa do painel"
        "$FERRAMENTA" pane get "$1" 2>/dev/null \
            | jq -r '.result.pane.agent_status // "unknown"' 2>/dev/null
        ;;
    processo)
        [[ $# -ge 1 ]] || die "adaptador: processo precisa do painel"
        # O shell do painel é o que sobrevive ao worker e ao foco: é ele que
        # prova que a sessão não trocou de processo no meio do caminho.
        "$FERRAMENTA" pane process-info --pane "$1" 2>/dev/null \
            | jq -r '.result.process_info.shell_pid // empty' 2>/dev/null
        ;;
    focar)
        [[ $# -ge 1 ]] || die "adaptador: focar precisa do painel"
        "$FERRAMENTA" agent focus "$1" >/dev/null 2>&1 \
            || die "adaptador: focar o painel $1 falhou"
        ;;
    *) die "adaptador: verbo desconhecido: '$VERBO'" ;;
esac
