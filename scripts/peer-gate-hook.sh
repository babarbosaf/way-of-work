#!/usr/bin/env bash
# peer-gate-hook.sh — nudge automático do Adversarial Evaluator.
#
# Chamado por hooks do Claude Code (ver `.claude/settings.json`).
# Lê o payload JSON do Claude em stdin, identifica se a mudança toca código
# em prod (`agent/**`) ou spec em `docs/specs/ongoing/**`, e emite um lembrete
# pelo stderr — que o Claude recebe como system reminder sem bloquear a ação.
#
# Nunca bloqueia: sai 0 mesmo em erro, para não interromper o fluxo.
#
# Uso:
#   peer-gate-hook.sh            # PostToolUse em Edit/Write/MultiEdit
#   peer-gate-hook.sh commit     # PreToolUse em Bash → checa git commit

set -u

mode="${1:-edit}"

# Ignora ambiente sem jq — o nudge silencioso é aceitável.
if ! command -v jq >/dev/null 2>&1; then
    exit 0
fi

payload=$(cat 2>/dev/null || true)
[[ -z "$payload" ]] && exit 0

emit() {
    # stderr = visível ao Claude como system reminder
    printf '%s\n' "$1" >&2
}

case "$mode" in
    commit)
        cmd=$(jq -r '.tool_input.command // empty' <<<"$payload" 2>/dev/null)
        [[ -z "$cmd" ]] && exit 0
        case "$cmd" in
            *"git commit"*|*"git push"*)
                staged=$(git -C "${CLAUDE_PROJECT_DIR:-.}" diff --cached --name-only 2>/dev/null || true)
                relevant=$(printf '%s\n' "$staged" | grep -E '^(agent|docs/specs/ongoing)/' || true)
                if [[ -n "$relevant" ]]; then
                    emit "🔒 Adversarial Evaluator: commit toca agent/ ou docs/specs/ongoing/. Se ainda não rodou, execute antes: ~/.claude/scripts/peer-review.sh diff HEAD (teto 2 rounds/spec)."
                fi
                ;;
        esac
        ;;
    *)
        path=$(jq -r '.tool_input.file_path // empty' <<<"$payload" 2>/dev/null)
        [[ -z "$path" ]] && exit 0
        case "$path" in
            *"/docs/specs/ongoing/"*.md)
                emit "🔒 Adversarial Evaluator: spec em ongoing/ alterada (${path##*/}). Antes de começar BUILD, rode: ~/.claude/scripts/peer-review.sh spec \"$path\""
                ;;
            *"/agent/"*.py)
                emit "🔒 Adversarial Evaluator: código em agent/ alterado (${path##*/}). Antes de SHIP, rode: ~/.claude/scripts/peer-review.sh diff HEAD"
                ;;
        esac
        ;;
esac

exit 0
