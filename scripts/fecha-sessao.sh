#!/usr/bin/env bash
# Fecha uma sessão dirigida, gravando a tela antes.
#
# Uso: fecha-sessao.sh <aba|painel>   fecha aquela sessão, no ato
#      fecha-sessao.sh --ociosas      varre e fecha as que passaram do prazo
#
# A aba nascia num despacho e nunca morria: quem fechava era o dono, uma por uma,
# sem nada dizendo quais já tinham sido integradas. Fechar por tempo sem gravar
# apagaria o material que ele quer ler depois, porque o que a ferramenta devolve
# de uma aba é o buffer da tela, não um arquivo.
#
# Sessão órfã, cujo despachante morreu, não fecha por tempo nenhum: worker vivo
# sem dono é o caso que precisa aparecer, e o prazo esconderia justo ele.
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$HERE/.."
POLICY="${DELEGATE_POLICY:-$ROOT/config/model-policy.json}"

die() { printf '%s\n' "$*" >&2; exit 1; }

# shellcheck disable=SC1091
source "$ROOT/skills/delegate/scripts/lib-visivel.sh" \
    || die "fecha-sessao: lib-visivel.sh não carregou"
visivel_configurar "$POLICY" || die "fecha-sessao: policy ilegível em $POLICY"
ADAPTADOR=$(visivel_adaptador)
[[ -x "$ADAPTADOR" ]] || die "fecha-sessao: adaptador não encontrado em $ADAPTADOR"

DIR=$(visivel_sessoes_dir)
GATE=$(dirname "$DIR")
TELAS="$DIR/telas"
LOG="$GATE/delegate.log"

fecha_um() { # registro → grava a tela, loga o caminho, fecha a aba, some o registro
    local arq="$1" nome tab pane tela
    nome=$(jq -r '.nome // "sessao"' "$arq")
    tab=$(jq -r '.tab // empty' "$arq")
    pane=$(jq -r '.pane // empty' "$arq")
    mkdir -p "$TELAS"
    tela="$TELAS/$nome-$(date -u +%Y-%m-%dT%H%M%SZ).txt"
    # ANTES de fechar, sempre: depois não há mais aba de onde ler.
    "$ADAPTADOR" ler "$pane" 400 > "$tela" 2>/dev/null
    # Caminho, nunca conteúdo: a conversa da sessão pode carregar o repo inteiro,
    # e despejar isso no log é vazamento, não diagnóstico.
    mkdir -p "$GATE"; touch "$LOG"; chmod 600 "$LOG"
    jq -cn --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" --arg nome "$nome" \
        --arg tab "$tab" --arg material "$tela" \
        '{ts:$ts,task:"sessao",backend:"",status:"fechada",detail:$nome,
          pool:"",material:$material,tab:$tab}' >> "$LOG"
    [[ -n "$tab" ]] && "$ADAPTADOR" fechar "$tab"
    rm -f "$arq"
}

ALVO="${1:-}"
[[ -n "$ALVO" ]] || die "fecha-sessao: falta a aba, o painel ou --ociosas"

if [[ "$ALVO" != "--ociosas" ]]; then
    for arq in "$DIR"/*.json; do
        [[ -f "$arq" ]] || continue
        if [[ "$(jq -r '.tab // empty' "$arq")" == "$ALVO" \
           || "$(jq -r '.pane // empty' "$arq")" == "$ALVO" ]]; then
            fecha_um "$arq"; exit 0
        fi
    done
    die "fecha-sessao: nenhuma sessão registrada em $ALVO"
fi

prazo=$(visivel_prazo_ocioso)
[[ -n "$prazo" ]] || die "fecha-sessao: a policy não declara prazo de ociosidade"
agora=$(date +%s)
for arq in "$DIR"/*.json; do
    [[ -f "$arq" ]] || continue
    dono=$(jq -r '.dono // empty' "$arq")
    # Órfã fica. A D-09 já decidiu que worker vivo sem dono é o que precisa
    # aparecer, e o prazo é justamente o que o esconderia.
    [[ -n "$dono" ]] && kill -0 "$dono" 2>/dev/null || continue
    pane=$(jq -r '.pane // empty' "$arq")
    estado=$("$ADAPTADOR" estado "$pane")
    if [[ "$estado" != idle && "$estado" != done && "$estado" != blocked ]]; then
        # Voltou a trabalhar: o relógio da ociosidade recomeça do zero.
        jq 'del(.parada_desde)' "$arq" > "$arq.novo" && mv "$arq.novo" "$arq"
        continue
    fi
    desde=$(jq -r '.parada_desde // empty' "$arq")
    if [[ -z "$desde" ]]; then
        # Primeira vez parada: marca a hora e deixa o prazo correr.
        jq --arg t "$agora" '.parada_desde = ($t|tonumber)' "$arq" > "$arq.novo" \
            && mv "$arq.novo" "$arq"
        continue
    fi
    (( agora - desde >= prazo * 60 )) && fecha_um "$arq"
done
