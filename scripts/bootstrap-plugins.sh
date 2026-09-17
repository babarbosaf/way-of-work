#!/usr/bin/env bash
# Aplica o manifesto de plugins do repo. Dry-run por default: imprime os comandos
# e não muda nada. Com --apply, executa.
#
# Dois modos. Sem flag: instala o que falta (marketplaces, plugins, MCP).
# Com --update: puxa o upstream do que já está instalado (marketplace update +
# plugin update), e não instala nada. MCP fica de fora do update porque cada
# servidor resolve versão sozinho (`npx @latest`, endpoint remoto).
#
# Manifesto base: config/plugins.json. Overlay privado: config/plugins.local.json
# (gitignored), deep-merge via jq `*`, local vence. Mesma convenção do
# model-policy. Plugin de conta (Slack, Linear, Notion) vive só no local: o nome
# do workspace conta quem você é.
#
# Idempotente: marketplace ou plugin já presente faz o comando falhar, e a falha
# é reportada sem abortar o resto.
set -uo pipefail

MANIFEST="${MANIFEST:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/config/plugins.json}"
APPLY=0
UPDATE=0
for arg in "$@"; do
  case "$arg" in
    --apply) APPLY=1 ;;
    --update) UPDATE=1 ;;
    --manifest=*) MANIFEST="${arg#--manifest=}" ;;
    -h|--help) sed -n '2,17p' "${BASH_SOURCE[0]}"; exit 0 ;;
    *) echo "uso: $(basename "$0") [--apply] [--update] [--manifest=PATH]" >&2; exit 1 ;;
  esac
done

command -v jq >/dev/null || { echo "bootstrap-plugins: jq é pré-requisito" >&2; exit 1; }
[[ -f "$MANIFEST" ]] || { echo "bootstrap-plugins: manifesto não encontrado: $MANIFEST" >&2; exit 1; }
jq -e . "$MANIFEST" >/dev/null 2>&1 || { echo "bootstrap-plugins: JSON inválido: $MANIFEST" >&2; exit 1; }

LOCAL="${MANIFEST%.json}.local.json"
if [[ -f "$LOCAL" ]] && jq -e . "$LOCAL" >/dev/null 2>&1; then
  EFETIVO=$(jq -s '.[0] * .[1]' "$MANIFEST" "$LOCAL")
  echo "# overlay local aplicado: $LOCAL"
else
  EFETIVO=$(cat "$MANIFEST")
fi

# Marketplace referenciado e não declarado é erro de manifesto, não de execução:
# o install falharia lá na frente com mensagem pior.
ORFAOS=$(jq -r '
  (.marketplaces // {}) as $m
  | (.plugins // [])
  | map(select(.marketplace as $k | ($m | has($k)) | not))
  | map("\(.name)@\(.marketplace)")
  | join(", ")' <<<"$EFETIVO")
if [[ -n "$ORFAOS" ]]; then
  echo "bootstrap-plugins: plugin aponta pra marketplace não declarada: $ORFAOS" >&2
  exit 1
fi

CMDS=()
if (( UPDATE == 1 )); then
  while IFS= read -r nome; do
    [[ -z "$nome" ]] && continue
    CMDS+=("claude plugin marketplace update $nome")
  done < <(jq -r '(.marketplaces // {}) | to_entries[] | select(.value.builtin != true) | .key' <<<"$EFETIVO")

  while IFS=$'\t' read -r nome mercado; do
    [[ -z "$nome" ]] && continue
    CMDS+=("claude plugin update $nome@$mercado")
  done < <(jq -r '(.plugins // [])[] | "\(.name)\t\(.marketplace)"' <<<"$EFETIVO")
else
  while IFS=$'\t' read -r nome repo; do
    [[ -z "$nome" ]] && continue
    CMDS+=("claude plugin marketplace add $repo")
  done < <(jq -r '(.marketplaces // {}) | to_entries[]
    | select(.value.builtin != true)
    | "\(.key)\t\(.value.github // .value.source // .key)"' <<<"$EFETIVO")

  while IFS=$'\t' read -r nome mercado; do
    [[ -z "$nome" ]] && continue
    CMDS+=("claude plugin install $nome@$mercado")
  done < <(jq -r '(.plugins // [])[] | "\(.name)\t\(.marketplace)"' <<<"$EFETIVO")

  # MCP: `url` é remoto (http), `command` é local (stdio). Escopo user, porque o
  # servidor serve o perfil inteiro, não um repo.
  # Tab é IFS-whitespace e colapsa campo vazio no meio, então o tipo vem primeiro
  # e o valor é o resto da linha.
  while IFS=$'\t' read -r tipo nome valor; do
    [[ -z "$nome" ]] && continue
    if [[ "$tipo" == "http" ]]; then
      CMDS+=("claude mcp add --transport http $nome $valor -s user")
    else
      CMDS+=("claude mcp add $nome -s user -- $valor")
    fi
  done < <(jq -r '(.mcp // {}) | to_entries[]
    | if .value.url then "http\t\(.key)\t\(.value.url)" else "stdio\t\(.key)\t\(.value.command)" end' <<<"$EFETIVO")
fi

if (( APPLY == 0 )); then
  echo "# dry-run: nada foi executado. Rode com --apply pra valer."
  printf '%s\n' "${CMDS[@]}"
  exit 0
fi

falhas=0
for cmd in "${CMDS[@]}"; do
  echo "+ $cmd"
  if ! $cmd; then
    echo "  falhou (já instalado, ou erro do CLI). Segue." >&2
    falhas=$((falhas+1))
  fi
done
echo "bootstrap-plugins: ${#CMDS[@]} comando(s), $falhas com falha."
