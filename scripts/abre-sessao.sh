#!/usr/bin/env bash
# Abre uma sessão visível: uma aba nomeada pelo trabalho, com um worker elegível
# rodando em modo interativo dentro dela, e devolve o endereço do painel.
#
# Uso: abre-sessao.sh --nome <trabalho> --backend <b> [--cwd <path>] [--model <m>]
# Saída: o pane_id em stdout. Recusa nomeando o worker quando ele não é elegível.
#
# O que este script NÃO faz: não escolhe worker, não mexe na cascata, não
# recupera sessão morta. Quem decide elegibilidade é a policy, via lib-visivel.
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$HERE/.."
POLICY="${DELEGATE_POLICY:-$ROOT/config/model-policy.json}"
# Quanto esperar por uma tela de abertura antes de seguir sem ela. A TUI leva
# alguns segundos pra desenhar, e não existe sinal de "acabei de desenhar":
# `agent_status: idle` aparece ANTES de a tela aceitar input.
PRAZO="${ABRE_PRAZO_TELA_S:-20}"

die() { printf '%s\n' "$*" >&2; exit 1; }

NOME=""; BACKEND=""; CWD="$PWD"; MODEL=""; EFFORT=""
while (( $# )); do
    case "$1" in
        --nome)    NOME="${2:-}";    shift 2 ;;
        --backend) BACKEND="${2:-}"; shift 2 ;;
        --cwd)     CWD="${2:-}";     shift 2 ;;
        --model)   MODEL="${2:-}";   shift 2 ;;
        --effort)  EFFORT="${2:-}";  shift 2 ;;
        *) die "abre-sessao: opção desconhecida: $1" ;;
    esac
done
[[ -n "$NOME"    ]] || die "abre-sessao: --nome é obrigatório, e é o nome do trabalho"
[[ -n "$BACKEND" ]] || die "abre-sessao: --backend é obrigatório"

# shellcheck disable=SC1091
source "$ROOT/skills/delegate/scripts/lib-visivel.sh" \
    || die "abre-sessao: lib-visivel.sh não carregou"
visivel_configurar "$POLICY" || die "abre-sessao: policy ilegível em $POLICY"
# Recusa ANTES de criar aba: recusar depois deixaria aba órfã na tela do dono.
visivel_exigir "$BACKEND" || exit 1

resposta=$(herdr tab create --cwd "$CWD" --label "$NOME" --no-focus 2>&1) \
    || die "abre-sessao: herdr tab create falhou: $resposta"
PANE=$(jq -r '.result.root_pane.pane_id // empty' <<<"$resposta" 2>/dev/null)
[[ -n "$PANE" ]] || die "abre-sessao: herdr não devolveu o painel: $resposta"

cmd=$(visivel_invoke "$BACKEND")
[[ -n "$cmd" ]] || die "abre-sessao: $BACKEND é elegível e não declara comando interativo"
# O comando vai pro shell como texto, não como argv: nome de modelo do agy tem
# espaço e parêntese ("Gemini 3.1 Pro (High)"), e solto assim o shell nem sobe a
# sessão. Citar é o que faz o valor chegar inteiro.
cmd="${cmd//\{model\}/\'$MODEL\'}"
cmd="${cmd//\{effort\}/\'$EFFORT\'}"
# Marcador que sobrou é pior que erro: o worker sobe e roda com outra coisa.
[[ "$cmd" != *"{"*"}"* ]] || die "abre-sessao: o comando de $BACKEND ficou com marcador por preencher: $cmd"
# A API nunca entra em worker nenhum, e o modo visível não é exceção.
herdr pane run "$PANE" "env -u ANTHROPIC_API_KEY $cmd" >/dev/null 2>&1 \
    || die "abre-sessao: herdr pane run falhou no painel $PANE"

# Tela de abertura: o worker pede algo antes de aceitar prompt, e o item
# pré-selecionado difere entre workers. Tecla no escuro encerra a sessão num e
# dispara instalação no outro, então só sai tecla depois de o padrão casar.
telas=$(visivel_telas "$BACKEND")
if [[ -n "$telas" ]]; then
    fim=$(( SECONDS + PRAZO ))
    while (( SECONDS < fim )); do
        tela=$(herdr pane read "$PANE" --source visible --lines 60 2>/dev/null)
        casou=0
        while IFS= read -r t; do
            [[ -n "$t" ]] || continue
            padrao=$(jq -r '.padrao' <<<"$t")
            if grep -qiF "$padrao" <<<"$tela"; then
                while IFS= read -r tecla; do
                    herdr agent send-keys "$PANE" "$tecla" >/dev/null 2>&1
                done < <(jq -r '.teclas[]' <<<"$t")
                casou=1
            fi
        done <<<"$telas"
        (( casou )) && break
        sleep 2
    done
fi

printf '%s\n' "$PANE"
