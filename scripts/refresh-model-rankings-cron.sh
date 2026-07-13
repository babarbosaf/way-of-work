#!/usr/bin/env bash
# Runner quinzenal do /refresh-model-rankings (SPEC-2026-002 T8).
# Chamado pelo cron local (dias 1 e 15); roda claude headless com a skill.
# A skill só COLETA e PROPÕE (proposta em gate/model-rankings/ + linha no
# inbox); a policy nunca muda sem aprovação — ver a própria skill.
set -uo pipefail
export PATH="/opt/homebrew/bin:/usr/local/bin:$HOME/.local/bin:$PATH"
LOG="$HOME/.claude/gate/model-rankings/cron.log"
mkdir -p "$(dirname "$LOG")"
{
    echo "=== $(date -u +%Y-%m-%dT%H:%M:%SZ) refresh-model-rankings ==="
    claude -p "Execute a skill /refresh-model-rankings — apenas as fases 1 (coleta) e 2 (proposta + linha no inbox). Nunca edite a model-policy.json." \
        --allowedTools "WebSearch,WebFetch,Read,Write,Glob,Grep,Bash(agy *),Bash(codex --version),Bash(jq *),Bash(mkdir *),Bash(date *)" \
        2>&1 | tail -20
    echo "=== fim (rc=$?) ==="
} >> "$LOG"
