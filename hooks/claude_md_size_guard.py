#!/usr/bin/env python3
"""PreToolUse hook: bloqueia Edit/Write que faria CLAUDE.md/AGENT.md/departments.md/MEMORY.md
estourar o teto de linhas.

Limites (linhas):
  CLAUDE.md                      80
  AGENT.md / AGENTS.md          130
  departments.md                 40
  MEMORY.md                     200  (índice automem; alinhado ao warning de boot)

Aplica em CLAUDE.md raiz E `<depto>/CLAUDE.md`. Calcula tamanho final pós-edit.

Override por env: MEMORY_MD_LINE_LIMIT (ex.: MEMORY_MD_LINE_LIMIT=150)
Kill switch: CLAUDE_MD_GUARD_DISABLED=1
"""

import json
import os
import sys
from pathlib import Path

LIMITS = {
    "CLAUDE.md": 80,
    "AGENT.md": 130,
    "AGENTS.md": 130,
    "departments.md": 40,
    "MEMORY.md": 200,
}


def predicted_lines(path: Path, tool_name: str, tool_input: dict) -> int | None:
    """Retorna número de linhas estimado após a operação, ou None se não puder estimar."""
    if tool_name == "Write":
        content = tool_input.get("content", "")
        return content.count("\n") + (0 if content.endswith("\n") else 1) if content else 0

    if tool_name in ("Edit", "MultiEdit"):
        if not path.exists():
            return None
        try:
            current = path.read_text(errors="ignore")
        except Exception:
            return None
        current_lines = current.count("\n") + (0 if current.endswith("\n") or not current else 1)

        if tool_name == "Edit":
            old_s = tool_input.get("old_string", "")
            new_s = tool_input.get("new_string", "")
            replace_all = tool_input.get("replace_all", False)
            count = current.count(old_s) if replace_all else (1 if old_s in current else 0)
            delta = (new_s.count("\n") - old_s.count("\n")) * count
            return current_lines + delta

        # MultiEdit
        edits = tool_input.get("edits", [])
        delta_total = 0
        running = current
        for e in edits:
            old_s, new_s = e.get("old_string", ""), e.get("new_string", "")
            replace_all = e.get("replace_all", False)
            count = running.count(old_s) if replace_all else (1 if old_s in running else 0)
            delta_total += (new_s.count("\n") - old_s.count("\n")) * count
            running = running.replace(old_s, new_s, count if not replace_all else -1)
        return current_lines + delta_total

    return None


def main():
    if os.environ.get("CLAUDE_MD_GUARD_DISABLED") == "1":
        sys.exit(0)
    try:
        data = json.load(sys.stdin)
    except Exception:
        sys.exit(0)

    tool_name = data.get("tool_name", "")
    if tool_name not in ("Edit", "Write", "MultiEdit"):
        sys.exit(0)

    tool_input = data.get("tool_input", {})
    file_path = tool_input.get("file_path", "")
    if not file_path:
        sys.exit(0)

    path = Path(file_path)
    basename = path.name
    if basename not in LIMITS:
        sys.exit(0)

    limit = LIMITS[basename]
    if basename == "MEMORY.md":
        try:
            limit = int(os.environ.get("MEMORY_MD_LINE_LIMIT", limit))
        except ValueError:
            pass
    predicted = predicted_lines(path, tool_name, tool_input)
    if predicted is None or predicted <= limit:
        sys.exit(0)

    print(json.dumps({
        "decision": "block",
        "reason": (
            f"{basename} excederia {limit} linhas (estimado: {predicted}). "
            f"Mover detalhe pra docs/status-log.md ou docs/reference/ e linkar com @. "
            f"Kill switch: CLAUDE_MD_GUARD_DISABLED=1."
        )
    }))
    sys.exit(0)


if __name__ == "__main__":
    main()
