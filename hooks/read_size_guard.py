#!/usr/bin/env python3
"""PreToolUse hook: bloqueia Read em arquivos > 200 linhas sem offset/limit.

Retorna JSON {"decision": "block", "reason": "..."} para forçar grep+offset.
Kill switch: READ_GUARD_DISABLED=1
"""

import json
import os
import sys
from pathlib import Path

LIMIT = 200


def main():
    if os.environ.get("READ_GUARD_DISABLED") == "1":
        sys.exit(0)

    try:
        data = json.load(sys.stdin)
    except Exception:
        sys.exit(0)

    if data.get("tool_name") != "Read":
        sys.exit(0)

    tool_input = data.get("tool_input", {})
    file_path = tool_input.get("file_path", "")

    if not file_path:
        sys.exit(0)

    # Se já usa offset ou limit, está paginando — deixa passar
    if tool_input.get("limit") or tool_input.get("offset"):
        sys.exit(0)

    path = Path(file_path)
    if not path.exists() or not path.is_file():
        sys.exit(0)

    # Não bloquear arquivos binários ou imagens
    suffix = path.suffix.lower()
    if suffix in {".png", ".jpg", ".jpeg", ".gif", ".pdf", ".ipynb"}:
        sys.exit(0)

    try:
        with open(path, "r", errors="ignore") as f:
            line_count = sum(1 for _ in f)
    except Exception:
        sys.exit(0)

    if line_count > LIMIT:
        print(json.dumps({
            "decision": "block",
            "reason": (
                f"Arquivo grande ({line_count} linhas). "
                "Grep primeiro para localizar a seção, depois Read com offset+limit."
            )
        }))

    sys.exit(0)


if __name__ == "__main__":
    main()
