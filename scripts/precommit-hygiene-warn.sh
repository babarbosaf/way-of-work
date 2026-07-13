#!/usr/bin/env bash
# PreCommit hygiene warning — não bloqueia, só avisa.
# Dispara em PreToolUse de Bash quando o comando é git commit.
# Avisa sobre arquivos suspeitos staged: *PENDENCIAS*, *HANDOVER*, *.bak, scratch*, draft-*, *OLD*

set -euo pipefail

# Lê input do hook (JSON via stdin)
INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('tool_name',''))" 2>/dev/null || echo "")
COMMAND=$(echo "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('tool_input',{}).get('command',''))" 2>/dev/null || echo "")

# Só age em git commit
if [[ "$TOOL_NAME" != "Bash" ]]; then exit 0; fi
if ! echo "$COMMAND" | grep -qE 'git[[:space:]]+commit'; then exit 0; fi

# Detecta diretório git
GIT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || exit 0

# Lista arquivos staged
STAGED=$(cd "$GIT_ROOT" && git diff --cached --name-only --diff-filter=ACM 2>/dev/null) || exit 0

[[ -z "$STAGED" ]] && exit 0

# Patterns suspeitos (case-insensitive em basename)
SUSPECT=()
while IFS= read -r f; do
  [[ -z "$f" ]] && continue
  base=$(basename "$f")
  if echo "$base" | grep -qiE '(PENDENCIAS|HANDOVER|^scratch|^draft-|\.bak$|^OLD-|-OLD\.|~$)'; then
    SUSPECT+=("$f")
  fi
done <<< "$STAGED"

if [[ ${#SUSPECT[@]} -eq 0 ]]; then exit 0; fi

# Emite warning (não bloqueia — exit 0)
echo "" >&2
echo "⚠️  Higiene PreCommit — arquivos suspeitos staged:" >&2
for f in "${SUSPECT[@]}"; do
  echo "   • $f" >&2
done
echo "" >&2
echo "   Padrões PENDENCIAS/HANDOVER/scratch/draft/.bak/OLD geralmente indicam" >&2
echo "   trabalho temporário que não deveria entrar no histórico do repo." >&2
echo "   → Ver memória feedback_pendencias_antipattern.md" >&2
echo "   → Mover para docs/specs/ongoing/ ou TODOS.md, ou delete antes de commitar." >&2
echo "   (Aviso apenas — commit prossegue normalmente)" >&2
echo "" >&2

exit 0
