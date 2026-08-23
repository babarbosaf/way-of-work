#!/usr/bin/env bash
# Aplica o manifesto de plugins do repo. Dry-run por default: imprime os comandos
# e não muda nada. Com --apply, executa.
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
for arg in "$@"; do
  case "$arg" in
    --apply) APPLY=1 ;;
    --manifest=*) MANIFEST="${arg#--manifest=}" ;;
    -h|--help) sed -n '2,12p' "${BASH_SOURCE[0]}"; exit 0 ;;
    *) echo "uso: $(basename "$0") [--apply] [--manifest=PATH]" >&2; exit 1 ;;
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
