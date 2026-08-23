#!/usr/bin/env bash
# Statusline: badge do perfil multi-conta + modelo + cwd + badge do caveman.
# Perfil vem de CLAUDE_CONFIG_DIR (ver docs/multi-conta.md).
set -uo pipefail

payload=$(cat)

# Rótulo derivado do nome do dir: `.claude-foo` vira FOO, `.claude` vira DEFAULT.
# Nenhum nome de perfil no código — funciona pra qualquer conta sem editar nada.
cfg="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
base="$(basename "$cfg")"
label="${base#.}"; label="${label#claude-}"
[ "$label" = "claude" ] && label="default"
profile="${CLAUDE_PROFILE_LABEL:-$(printf '%s' "$label" | tr 'a-z-' 'A-Z_')}"

# Cor estável por perfil, sorteada do rótulo — o mesmo perfil sai sempre da mesma cor,
# e dois perfis diferentes tendem a sair de cores diferentes.
if [ -n "${CLAUDE_PROFILE_COLOR:-}" ]; then
  color=$'\033[38;5;'"${CLAUDE_PROFILE_COLOR}"'m'
else
  paleta=(39 220 203 78 141 208)
  soma=0
  for (( i=0; i<${#profile}; i++ )); do
    c=$(printf '%d' "'${profile:$i:1}" 2>/dev/null || echo 0)
    soma=$(( soma + c ))
  done
  color=$'\033[38;5;'"${paleta[$(( soma % ${#paleta[@]} ))]}"'m'
fi
reset=$'\033[0m'

info=$(printf '%s' "$payload" | python3 -c '
import json, os, sys
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(0)
model = (d.get("model") or {}).get("display_name") or ""
cwd = (d.get("workspace") or {}).get("current_dir") or ""
home = os.path.expanduser("~")
if cwd.startswith(home):
    cwd = "~" + cwd[len(home):]
print(" · ".join(p for p in (model, cwd) if p))
' 2>/dev/null)

line="${color}[${profile}]${reset}"
[ -n "$info" ] && line="$line $info"

# Badge do caveman, opcional: sem o plugin instalado o find não acha nada e a
# statusline segue sem badge. Ver config/plugins.json.
cave=$(find "$HOME/.claude/plugins/cache/caveman" -name caveman-statusline.sh -type f 2>/dev/null | head -1)
if [ -n "$cave" ]; then
  badge=$(printf '%s' "$payload" | bash "$cave" 2>/dev/null | tr -d '\n')
  [ -n "$badge" ] && line="$line $badge"
fi

printf '%s' "$line"
