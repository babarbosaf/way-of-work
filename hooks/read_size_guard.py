#!/usr/bin/env python3
"""PreToolUse hook: Read de arquivo grande não entra inteiro na janela.

Threshold e mensagem de rota vivem em hooks/shunt_policy.py (dado na
model-policy.json, não número mágico aqui). O par deste hook é o
bash_read_guard, que cobre o mesmo despejo por `cat`/`head`/`rtk read`.

Kill switch: READ_GUARD_DISABLED=1
"""

import json
import os
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import shunt_policy  # noqa: E402


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

    # Já pagina: deixa passar.
    if tool_input.get("limit") or tool_input.get("offset"):
        sys.exit(0)

    cfg = shunt_policy.load()
    if shunt_policy.is_exempt(file_path, cfg):
        sys.exit(0)

    line_count = shunt_policy.count_lines(file_path)
    if line_count is None:
        sys.exit(0)

    if shunt_policy.route(line_count, cfg) != "inline":
        print(json.dumps({
            "decision": "block",
            "reason": shunt_policy.block_reason(
                line_count, [os.path.abspath(file_path)], cfg),
        }, ensure_ascii=False))

    sys.exit(0)


if __name__ == "__main__":
    main()
