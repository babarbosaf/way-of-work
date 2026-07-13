#!/usr/bin/env python3
"""PostToolUse hook: enforces append in memory/log.md for any Write/Edit in memory/*.md.

Spec: SPEC-2026-021 (memory-as-wiki).
Reads PostToolUse JSON from stdin. Returns exit 0 (allow) or exit 2 (block).

Kill switch: env var MEMORY_HOOK_DISABLED=1 → bypass with log entry in
~/.claude/memory_kill_switch.log (mode 0600).
"""

import json
import os
import re
import sys
from datetime import datetime, timezone
from pathlib import Path

WINDOW_SECONDS = 120
LOG_REGEX = re.compile(
    r"^## \[\d{4}-\d{2}-\d{2}\] (?:create|update|delete|lint|ingest) \| (.+?)(?:\s+\(session=([a-f0-9-]+)\))?$"
)


def home() -> Path:
    """Resolve HOME respecting env override (used by tests)."""
    return Path(os.environ.get("HOME", os.path.expanduser("~")))


def is_under_memory_dir(file_path: Path) -> bool:
    """Validate path is under ~/.claude/projects/*/memory/ (security boundary)."""
    try:
        resolved = file_path.resolve()
    except (OSError, RuntimeError):
        return False
    parts = resolved.parts
    try:
        idx = parts.index(".claude")
    except ValueError:
        return False
    # Expect: .../.claude/projects/<project>/memory/<file>
    return (
        idx + 3 < len(parts)
        and parts[idx + 1] == "projects"
        and parts[idx + 3] == "memory"
    )


def write_kill_switch_log(file_path: Path, session_id: str, cwd: str) -> None:
    """Append bypass record to ~/.claude/memory_kill_switch.log (mode 0600)."""
    kill_log = home() / ".claude" / "memory_kill_switch.log"
    kill_log.parent.mkdir(parents=True, exist_ok=True)
    ts = datetime.now(timezone.utc).isoformat()
    line = f"{ts} | session={session_id} | file={file_path} | cwd={cwd}\n"
    # Open with mode 0600 on first creation
    fd = os.open(str(kill_log), os.O_WRONLY | os.O_CREAT | os.O_APPEND, 0o600)
    with os.fdopen(fd, "a") as f:
        f.write(line)


def find_matching_entry(log_path: Path, target_basename: str, edit_mtime: float) -> bool:
    """Iterate all log entries; return True if any matches basename within 120s window."""
    if not log_path.exists():
        return False
    log_mtime = log_path.stat().st_mtime
    # Janela: log foi modificado dentro de [edit_mtime - 120s, edit_mtime + 120s]
    if log_mtime < edit_mtime - WINDOW_SECONDS:
        return False
    try:
        text = log_path.read_text()
    except OSError:
        return False
    for line in text.splitlines():
        m = LOG_REGEX.match(line)
        if m and target_basename in m.group(1):
            return True
    return False


def main() -> int:
    try:
        payload = json.load(sys.stdin)
    except (json.JSONDecodeError, ValueError):
        # Payload inválido → não bloqueia (defesa contra hook quebrar sessão)
        return 0

    tool_input = payload.get("tool_input") or {}
    file_path_str = tool_input.get("file_path")
    if not file_path_str:
        return 0

    file_path = Path(file_path_str)
    basename = file_path.name

    # Regra 1: log.md e MEMORY.md → exit 0 (evita loop)
    if basename in {"log.md", "MEMORY.md"}:
        return 0

    # Regra 2 (security): path precisa estar sob ~/.claude/projects/*/memory/
    if not is_under_memory_dir(file_path):
        return 0

    # Kill switch
    if os.environ.get("MEMORY_HOOK_DISABLED") == "1":
        session_id = payload.get("session_id", "unknown")
        cwd = payload.get("cwd", os.getcwd())
        try:
            write_kill_switch_log(file_path, session_id, cwd)
        except OSError as e:
            print(f"memory hook: failed to write kill_switch log: {e}", file=sys.stderr)
        return 0

    # Validação: log.md deve ter entrada correspondente na janela
    log_path = file_path.parent / "log.md"
    if not file_path.exists():
        # Arquivo recém-deletado ou não existe; usar mtime atual como referência
        edit_mtime = datetime.now().timestamp()
    else:
        edit_mtime = file_path.stat().st_mtime

    if find_matching_entry(log_path, basename, edit_mtime):
        return 0

    # Bloqueio
    today = datetime.now().strftime("%Y-%m-%d")
    msg = (
        f"memory hook: arquivo {basename} editado sem entrada correspondente "
        f"em log.md (na janela de {WINDOW_SECONDS}s). "
        f"Adicione: ## [{today}] <op> | {basename} (session=<id>)"
    )
    print(msg, file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main())
