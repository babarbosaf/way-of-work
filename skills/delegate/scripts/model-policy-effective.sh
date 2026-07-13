#!/usr/bin/env bash
# Emite a policy EFETIVA: base * <base>.local.json (deep-merge via jq `*` — local
# vence; objetos mesclam recursivo, arrays do local substituem os da base).
# Ausência de local, ou qualquer um dos dois inválido → base crua (caller trata).
#
# Fonte única do merge pra TODO consumidor da policy (delegate.sh inlina a mesma
# lógica no hot-path; triage/skills leem via este script). Override project-specific
# (scope_pattern, env_file, finding_routing) vive só em model-policy.local.json
# (gitignored) — a base pública fica genérica.
set -euo pipefail
BASE="${1:-$HOME/.claude/config/model-policy.json}"
LOCAL="${BASE%.json}.local.json"
if [[ -f "$LOCAL" ]] && jq -e . "$BASE" >/dev/null 2>&1 && jq -e . "$LOCAL" >/dev/null 2>&1; then
    jq -s '.[0] * .[1]' "$BASE" "$LOCAL"
else
    cat "$BASE"
fi
