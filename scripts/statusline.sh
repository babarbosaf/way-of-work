#!/usr/bin/env bash
# Statusline: badge do perfil multi-conta + modelo + cwd + badge do caveman.
# Perfil vem de CLAUDE_CONFIG_DIR (ver docs/multi-conta.md).
set -uo pipefail

payload=$(cat)

cfg="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
case "$(basename "$cfg")" in
  .claude)           profile="PESSOAL" ; color=$'\033[38;5;39m' ;;
  .claude-trabalho)  profile="TRABALHO"; color=$'\033[38;5;203m' ;;
  *)                 profile="$(basename "$cfg")"; color=$'\033[38;5;245m' ;;
esac
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

cave=$(find "$HOME/.claude/plugins/cache/caveman" -name caveman-statusline.sh -type f 2>/dev/null | head -1)
if [ -n "$cave" ]; then
  badge=$(printf '%s' "$payload" | bash "$cave" 2>/dev/null | tr -d '\n')
  [ -n "$badge" ] && line="$line $badge"
fi

printf '%s' "$line"
