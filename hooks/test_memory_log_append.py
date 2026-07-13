"""Tests for memory_log_append.py hook.

6 scenarios from SPEC-2026-021 T5 AC:
1. Edit em feedback_x.md sem append em log.md → exit 2
2. Edit em feedback_x.md com append em log.md → exit 0
3. Edit em log.md → exit 0 (sem checagem; evita loop)
4. Edit em MEMORY.md → exit 0
5. MEMORY_HOOK_DISABLED=1 → exit 0 + linha em kill_switch.log
6. Path fora de memory/ → exit 0 (não é nosso escopo)
"""

import json
import os
import subprocess
import sys
import tempfile
import time
from pathlib import Path

HOOK = Path(__file__).parent / "memory_log_append.py"


def run_hook(payload: dict, env_extra: dict | None = None) -> subprocess.CompletedProcess:
    """Execute hook with PostToolUse payload via stdin."""
    env = os.environ.copy()
    if env_extra:
        env.update(env_extra)
    return subprocess.run(
        [sys.executable, str(HOOK)],
        input=json.dumps(payload),
        capture_output=True,
        text=True,
        env=env,
    )


def make_payload(file_path: str, tool: str = "Edit") -> dict:
    return {
        "tool_name": tool,
        "tool_input": {"file_path": file_path},
        "session_id": "test-session-001",
    }


def setup_memory_dir(tmp: Path) -> Path:
    """Mimic the real path structure ~/.claude/projects/X/memory/."""
    mem = tmp / ".claude" / "projects" / "-Users-test-project" / "memory"
    mem.mkdir(parents=True)
    return mem


def write_log_with_entry(log_path: Path, entry_target: str | None) -> None:
    """Write log.md. If entry_target is given, add a recent entry for it."""
    content = "# Memory Log\n\n## Convenção\n\n"
    if entry_target:
        content += f"## [2026-04-22] update | {entry_target} (session=test-session-001)\nTest entry.\n"
    log_path.write_text(content)


def scenario_1_edit_without_append() -> bool:
    """Edit feedback_x.md sem append em log.md → exit 2."""
    with tempfile.TemporaryDirectory() as tmp:
        mem = setup_memory_dir(Path(tmp))
        log = mem / "log.md"
        write_log_with_entry(log, entry_target=None)  # log sem entrada relevante
        target = mem / "feedback_x.md"
        target.write_text("# x")
        # Hook precisa receber path real do filesystem do hook (HOME-relativo via env não funciona)
        # Mas como a regra é "path sob ~/.claude/projects/*/memory/", e estamos usando tmp/.claude/...,
        # passamos HOME=tmp pra que o hook resolva paths corretamente
        proc = run_hook(make_payload(str(target)), env_extra={"HOME": tmp})
        return proc.returncode == 2


def scenario_2_edit_with_append() -> bool:
    """Edit feedback_x.md com append em log.md → exit 0."""
    with tempfile.TemporaryDirectory() as tmp:
        mem = setup_memory_dir(Path(tmp))
        log = mem / "log.md"
        target = mem / "feedback_x.md"
        target.write_text("# x")
        time.sleep(0.05)
        write_log_with_entry(log, entry_target="feedback_x.md")
        proc = run_hook(make_payload(str(target)), env_extra={"HOME": tmp})
        return proc.returncode == 0


def scenario_3_edit_log_itself() -> bool:
    """Edit em log.md → exit 0 (evita loop)."""
    with tempfile.TemporaryDirectory() as tmp:
        mem = setup_memory_dir(Path(tmp))
        log = mem / "log.md"
        write_log_with_entry(log, entry_target=None)
        proc = run_hook(make_payload(str(log)), env_extra={"HOME": tmp})
        return proc.returncode == 0


def scenario_4_edit_memory_md() -> bool:
    """Edit em MEMORY.md → exit 0."""
    with tempfile.TemporaryDirectory() as tmp:
        mem = setup_memory_dir(Path(tmp))
        target = mem / "MEMORY.md"
        target.write_text("# Index")
        proc = run_hook(make_payload(str(target)), env_extra={"HOME": tmp})
        return proc.returncode == 0


def scenario_5_kill_switch() -> bool:
    """MEMORY_HOOK_DISABLED=1 → exit 0 + linha em kill_switch.log."""
    with tempfile.TemporaryDirectory() as tmp:
        mem = setup_memory_dir(Path(tmp))
        log = mem / "log.md"
        write_log_with_entry(log, entry_target=None)
        target = mem / "feedback_x.md"
        target.write_text("# x")
        kill_log = Path(tmp) / ".claude" / "memory_kill_switch.log"
        proc = run_hook(
            make_payload(str(target)),
            env_extra={"HOME": tmp, "MEMORY_HOOK_DISABLED": "1"},
        )
        if proc.returncode != 0:
            return False
        if not kill_log.exists():
            return False
        content = kill_log.read_text()
        return "session=test-session-001" in content and "feedback_x.md" in content


def scenario_6_path_outside_scope() -> bool:
    """Path fora de memory/ → exit 0 (não é nosso escopo)."""
    with tempfile.TemporaryDirectory() as tmp:
        setup_memory_dir(Path(tmp))
        # File fora de memory/
        outside = Path(tmp) / ".claude" / "settings.json"
        outside.write_text("{}")
        proc = run_hook(make_payload(str(outside)), env_extra={"HOME": tmp})
        return proc.returncode == 0


def main() -> int:
    scenarios = [
        ("1. edit sem append → exit 2", scenario_1_edit_without_append),
        ("2. edit com append → exit 0", scenario_2_edit_with_append),
        ("3. edit log.md → exit 0", scenario_3_edit_log_itself),
        ("4. edit MEMORY.md → exit 0", scenario_4_edit_memory_md),
        ("5. kill switch → exit 0 + log", scenario_5_kill_switch),
        ("6. path fora do escopo → exit 0", scenario_6_path_outside_scope),
    ]
    failures = 0
    for name, fn in scenarios:
        try:
            ok = fn()
        except Exception as e:
            ok = False
            print(f"  EXCEPTION: {e}")
        status = "PASS" if ok else "FAIL"
        print(f"[{status}] {name}")
        if not ok:
            failures += 1
    print(f"\n{len(scenarios) - failures}/{len(scenarios)} green")
    return 0 if failures == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
