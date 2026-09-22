#!/usr/bin/env bash
# Abre uma sessão visível: uma aba nomeada pelo trabalho, com um worker elegível
# rodando em modo interativo dentro dela, e devolve o endereço do painel.
#
# Uso: abre-sessao.sh --nome <trabalho> --backend <b> [--cwd <path>] [--model <m>]
# Saída: o pane_id em stdout. Recusa nomeando o worker quando ele não é elegível.
#
# O que este script NÃO faz: não escolhe worker, não mexe na cascata, não
# recupera sessão morta, e não fala com a ferramenta de terminal direto. Quem
# decide elegibilidade é a policy, via lib-visivel; quem sabe o nome da
# ferramenta é o adaptador.
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
# O nome vira componente de caminho quando a tela é gravada, e ele chega como
# texto livre de quem despacha. Sem esta recusa, `--visivel ../../../.ssh/algo`
# trunca o arquivo e o enche com o buffer da sessão.
case "$NOME" in
    */*|*..*|-*) die "abre-sessao: --nome vira nome de arquivo: sem barra, sem '..' e sem começar com '-'" ;;
esac
[[ -n "$BACKEND" ]] || die "abre-sessao: --backend é obrigatório"

# shellcheck disable=SC1091
source "$ROOT/skills/delegate/scripts/lib-visivel.sh" \
    || die "abre-sessao: lib-visivel.sh não carregou"
visivel_configurar "$POLICY" || die "abre-sessao: policy ilegível em $POLICY"
# Recusa ANTES de criar aba: recusar depois deixaria aba órfã na tela do dono.
visivel_exigir "$BACKEND" || exit 1

ADAPTADOR=$(visivel_adaptador)
[[ -x "$ADAPTADOR" ]] || die "abre-sessao: adaptador não encontrado em $ADAPTADOR"
"$ADAPTADOR" disponivel || exit 1

# Varredura antes de somar mais uma: o quadro que o dono vai olhar daqui a pouco
# inclui as sessões que ele abriu antes, e registro velho de sessão morta é o
# que faz a lista mentir.
visivel_sincronizar || true

# Prefixo do marcador: aba dirigida se distingue da que dirige pelo nome, e a
# receita de sidebar é quem transforma isso em contraste na tela.
grupo=$(visivel_espaco "$CWD") || grupo=""
IFS=$'\t' read -r ESPACO RAIZ_PANE RAIZ_TAB <<<"$grupo"
if [[ -n "${RAIZ_PANE:-}" ]]; then
    # Grupo recém-criado já veio com uma aba: reusar é o que evita uma aba vazia
    # por projeto encalhada na lista, que é o contrário do que o agrupamento quer.
    PANE="$RAIZ_PANE"; TAB="${RAIZ_TAB:-}"
    "$ADAPTADOR" rotular "$TAB" "$VISIVEL_MARCA_DIRIGIDA$NOME" || exit 1
else
    linha=$("$ADAPTADOR" abrir "$CWD" "$VISIVEL_MARCA_DIRIGIDA$NOME" "${ESPACO:-}") || exit 1
    IFS=$'\t' read -r PANE TAB <<<"$linha"
fi
[[ -n "$PANE" ]] || die "abre-sessao: o adaptador não devolveu o painel"

# O dono é quem PEDIU o despacho, não este script, que morre em segundos. Com
# `exec` vindo do despachante, o pai é a sessão que mandou abrir, e é a morte
# dela que torna esta sessão órfã.
visivel_registrar "$PANE" "$TAB" "$NOME" "${DELEGATE_DONO_PID:-$PPID}" \
    || die "abre-sessao: não consegui registrar a sessão"

cmd=$(visivel_invoke "$BACKEND")
[[ -n "$cmd" ]] || die "abre-sessao: $BACKEND é elegível e não declara comando interativo"
# O comando vai pro shell como texto, não como argv: nome de modelo do agy tem
# espaço e parêntese ("Gemini 3.1 Pro (High)"), e solto assim o shell nem sobe a
# sessão. Citar é o que faz o valor chegar inteiro, e escapar a aspa dentro do
# valor é o que impede o resto da linha de virar comando novo.
cita() { local v="${1//\'/\'\\\'\'}"; printf "'%s'" "$v"; }
cmd="${cmd//\{model\}/$(cita "$MODEL")}"
cmd="${cmd//\{effort\}/$(cita "$EFFORT")}"
# Marcador que sobrou é pior que erro: o worker sobe e roda com outra coisa.
[[ "$cmd" != *"{"*"}"* ]] || die "abre-sessao: o comando de $BACKEND ficou com marcador por preencher: $cmd"
# A API nunca entra em worker nenhum, e o modo visível não é exceção.
"$ADAPTADOR" rodar "$PANE" "env -u ANTHROPIC_API_KEY $cmd" \
    || die "abre-sessao: o worker não subiu no painel $PANE"

# Tela de abertura: o worker pede algo antes de aceitar prompt, e o item
# pré-selecionado difere entre workers. Tecla no escuro encerra a sessão num e
# dispara instalação no outro, então só sai tecla depois de o padrão casar.
telas=$(visivel_telas "$BACKEND")
if [[ -n "$telas" ]]; then
    # Responde TODA tela que aparecer, não só a primeira: o codex mostra update e
    # confiança em sequência, e parar na primeira deixa o worker na segunda.
    fim=$(( SECONDS + PRAZO ))
    viu=0
    while (( SECONDS < fim )); do
        tela=$("$ADAPTADOR" ler "$PANE" 60)
        casou=0
        while IFS= read -r t; do
            [[ -n "$t" ]] || continue
            # `// empty`: sem isso, entrada sem padrão vira a string "null" e
            # casa qualquer tela que tenha "null" dentro, que é tecla no escuro.
            padrao=$(jq -r '.padrao // empty' <<<"$t")
            [[ -n "$padrao" ]] || continue
            if grep -qiF "$padrao" <<<"$tela"; then
                while IFS= read -r tecla; do
                    "$ADAPTADOR" teclar "$PANE" "$tecla"
                done < <(jq -r '.teclas[]? // empty' <<<"$t")
                casou=1
            fi
        done <<<"$telas"
        if (( casou )); then viu=1; sleep 1; continue; fi
        (( viu )) && break
        sleep 2
    done
    # Tela de abertura que sobreviveu às teclas é worker travado, e devolver o
    # painel dali é reportar sucesso pra sessão que nunca vai responder.
    tela=$("$ADAPTADOR" ler "$PANE" 60)
    while IFS= read -r t; do
        [[ -n "$t" ]] || continue
        padrao=$(jq -r '.padrao // empty' <<<"$t")
        [[ -n "$padrao" ]] || continue
        grep -qiF "$padrao" <<<"$tela" \
            && die "abre-sessao: $BACKEND continua na tela de abertura ('$padrao') depois de ${PRAZO}s"
    done <<<"$telas"
fi

printf '%s\n' "$PANE"
