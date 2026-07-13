#!/usr/bin/env bash
# PreCommit branch-age warning — avisa quando branch local tem >72h sem PR aberto.
# Não bloqueia. Roda em PreToolUse de Bash quando comando é `git commit` ou `git push`.
#
# Suporta Bitbucket Cloud (remote api.bitbucket.org via ~/.netrc) e GitHub (via `gh`).
# Em outros remotes, faz check só de idade (sem cruzar com PR).
#
# Kill switch: BRANCH_AGE_WARN_DISABLED=1
# Threshold custom: BRANCH_AGE_WARN_HOURS=72 (default 72)

set -euo pipefail

[[ "${BRANCH_AGE_WARN_DISABLED:-}" == "1" ]] && exit 0

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('tool_name',''))" 2>/dev/null || echo "")
COMMAND=$(echo "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('tool_input',{}).get('command',''))" 2>/dev/null || echo "")

[[ "$TOOL_NAME" != "Bash" ]] && exit 0
echo "$COMMAND" | grep -qE 'git[[:space:]]+(commit|push)' || exit 0

GIT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || exit 0
cd "$GIT_ROOT"

BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null) || exit 0

# Ignora trunks
case "$BRANCH" in
  main|master|stg|staging|develop|HEAD) exit 0 ;;
esac

THRESHOLD_H=${BRANCH_AGE_WARN_HOURS:-72}
THRESHOLD_S=$((THRESHOLD_H * 3600))

# Idade do branch = idade do oldest commit que não está no trunk
TRUNK=""
for cand in origin/stg origin/main origin/master origin/develop; do
  if git rev-parse --verify "$cand" >/dev/null 2>&1; then
    TRUNK="$cand"; break
  fi
done
[[ -z "$TRUNK" ]] && exit 0

OLDEST_TS=$(git log "$TRUNK..HEAD" --format=%ct --reverse 2>/dev/null | head -1)
[[ -z "$OLDEST_TS" ]] && exit 0

NOW=$(date +%s)
AGE_S=$((NOW - OLDEST_TS))
[[ $AGE_S -lt $THRESHOLD_S ]] && exit 0

AGE_H=$((AGE_S / 3600))

# Checa PR aberto
REMOTE_URL=$(git config --get remote.origin.url 2>/dev/null || echo "")
HAS_PR=0
PR_CHECK_RAN=0

if [[ "$REMOTE_URL" == *"bitbucket.org"* ]] && [[ -f ~/.netrc ]] && grep -q "api.bitbucket.org" ~/.netrc; then
  PR_CHECK_RAN=1
  WS_REPO=$(echo "$REMOTE_URL" | sed -E 's#.*[:/]([^/:]+/[^/]+)\.git$#\1#')
  if [[ -n "$WS_REPO" && "$WS_REPO" != "$REMOTE_URL" ]]; then
    RESP=$(curl -n -s --max-time 5 \
      "https://api.bitbucket.org/2.0/repositories/${WS_REPO}/pullrequests?q=state%3D%22OPEN%22+AND+source.branch.name%3D%22${BRANCH}%22" 2>/dev/null || echo "")
    if [[ -n "$RESP" ]]; then
      COUNT=$(echo "$RESP" | python3 -c "import sys,json
try: d=json.load(sys.stdin); print(d.get('size',0))
except: print(0)" 2>/dev/null || echo 0)
      [[ "$COUNT" -gt 0 ]] && HAS_PR=1
    fi
  fi
elif [[ "$REMOTE_URL" == *"github.com"* ]] && command -v gh >/dev/null 2>&1; then
  PR_CHECK_RAN=1
  COUNT=$(gh pr list --head "$BRANCH" --state open --json number 2>/dev/null | python3 -c "import sys,json
try: print(len(json.load(sys.stdin)))
except: print(0)" 2>/dev/null || echo 0)
  [[ "$COUNT" -gt 0 ]] && HAS_PR=1
fi

[[ $HAS_PR -eq 1 ]] && exit 0

echo "" >&2
echo "⚠️  Higiene de branches — '$BRANCH' tem ${AGE_H}h sem PR aberto (limite: ${THRESHOLD_H}h)" >&2
if [[ $PR_CHECK_RAN -eq 1 ]]; then
  echo "   Nenhum PR aberto encontrado pra esta branch." >&2
else
  echo "   (Não consegui consultar PRs no remote — só checagem de idade.)" >&2
fi
echo "" >&2
echo "   Regra: branch local >${THRESHOLD_H}h sem PR é dívida — abrir PR ou deletar." >&2
echo "   → docs/runbooks/branch-hygiene.md" >&2
echo "   (Aviso apenas — commit/push prossegue)" >&2
echo "" >&2

exit 0
