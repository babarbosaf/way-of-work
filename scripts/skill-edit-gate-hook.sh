#!/usr/bin/env bash
# skill-edit-gate-hook.sh — nudge ao editar SKILL.md user-level.
#
# Aplica a Regra 10 do CLAUDE.md ("Toda skill user-level criada/editada segue
# best practices do skill-creator") como reforço da máquina, não só texto.
#
# PostToolUse em Edit|Write|MultiEdit. Nunca bloqueia: sai 0 sempre.

set -u

command -v jq >/dev/null 2>&1 || exit 0

payload=$(cat 2>/dev/null || true)
[[ -z "$payload" ]] && exit 0

path=$(jq -r '.tool_input.file_path // empty' <<<"$payload" 2>/dev/null)
[[ -z "$path" ]] && exit 0

case "$path" in
    "$HOME/.claude/skills/"*"/SKILL.md")
        skill_name=$(basename "$(dirname "$path")")
        printf '🔒 Skill gate: %s/SKILL.md alterada. Antes de fechar a sessão, rode skill-creator pra validar frontmatter pushy + trigger explícito + alinhamento descrição↔conteúdo (Regra 10 do CLAUDE.md).\n' "$skill_name" >&2
        ;;
esac

exit 0
