"""Tests for noop_flush_guard.py hook.

Cenários:
1. `true`               → block
2. `:`                  → block
3. `sleep 5`            → block
4. `rtk true`           → block (desembrulha wrapper)
5. `echo oi`            → allow (fora de escopo; vai pra memória)
6. `ls -la`             → allow (comando real)
7. tool != Bash         → allow
8. NOOP_GUARD_DISABLED  → allow mesmo sendo no-op
"""

import json
import os
import subprocess
import sys
from pathlib import Path

HOOK = str(Path(__file__).with_name("noop_flush_guard.py"))


def run_hook(command: str, tool: str = "Bash", env_extra=None) -> subprocess.CompletedProcess:
    payload = {"tool_name": tool, "tool_input": {"command": command}}
    env = dict(os.environ)
    if env_extra:
        env.update(env_extra)
    return subprocess.run(
        [sys.executable, HOOK],
        input=json.dumps(payload),
        capture_output=True,
        text=True,
        env=env,
    )


def is_block(proc: subprocess.CompletedProcess) -> bool:
    if not proc.stdout.strip():
        return False
    try:
        return json.loads(proc.stdout).get("decision") == "block"
    except (json.JSONDecodeError, ValueError):
        return False


CASES = [
    ("true", "Bash", None, True),
    (":", "Bash", None, True),
    ("sleep 5", "Bash", None, True),
    ("rtk true", "Bash", None, True),
    ("echo oi", "Bash", None, False),
    ("ls -la", "Bash", None, False),
    ("true", "Read", None, False),
    ("true", "Bash", {"NOOP_GUARD_DISABLED": "1"}, False),
]


def main() -> int:
    failures = 0
    for command, tool, env_extra, expect_block in CASES:
        proc = run_hook(command, tool, env_extra)
        got = is_block(proc)
        ok = got == expect_block
        status = "PASS" if ok else "FAIL"
        if not ok:
            failures += 1
        print(f"[{status}] cmd={command!r} tool={tool} env={env_extra} "
              f"expect_block={expect_block} got={got}")
    print(f"\n{len(CASES) - failures}/{len(CASES)} passou")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
