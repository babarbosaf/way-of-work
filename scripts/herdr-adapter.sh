#!/usr/bin/env bash
# Adaptador da ferramenta de terminal. É o único arquivo do repo que sabe que a
# ferramenta se chama herdr, e existe por isso: trocar de ferramenta, ou não ter
# nenhuma, precisa ser um arquivo que muda e não uma caça ao nome espalhado.
#
# Uso: herdr-adapter.sh <verbo> [args]
#   disponivel                 rc 0 se a ferramenta está nesta máquina
#   abrir <cwd> <rotulo>       cria a aba, devolve "pane_id<TAB>tab_id"
#   rodar <pane> <comando>     entrega o comando ao shell da aba
#   ler <pane> [linhas]        devolve a tela visível
#   teclar <pane> <tecla>      manda uma tecla
#   listar                     "tab_id<TAB>rotulo<TAB>estado", uma aba por linha
#   rotular <tab> <rotulo>     renomeia a aba
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
        resposta=$("$FERRAMENTA" tab create --cwd "$1" --label "$2" --no-focus 2>&1) \
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
        "$FERRAMENTA" tab list 2>/dev/null \
            | jq -r '.result.tabs // [] | .[]
                | [.tab_id, .label, (.agent_status // "")] | @tsv' 2>/dev/null
        ;;
    rotular)
        [[ $# -ge 2 ]] || die "adaptador: rotular precisa de aba e rótulo"
        "$FERRAMENTA" tab rename "$1" "$2" >/dev/null 2>&1 \
            || die "adaptador: renomear a aba $1 falhou"
        ;;
    *) die "adaptador: verbo desconhecido: '$VERBO'" ;;
esac
