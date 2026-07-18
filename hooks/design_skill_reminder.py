#!/usr/bin/env python3
"""PreToolUse (Edit|Write|MultiEdit) — lembra de rodar a skill/plugin de design
(ex.: impeccable) ao mexer em arquivo de UI, quando o projeto mantém DESIGN.md.
Não bloqueia (exit 0), só avisa via stderr.
Kill: DESIGN_SKILL_REMINDER_DISABLED=1
"""
import json
import os
import sys

if os.environ.get("DESIGN_SKILL_REMINDER_DISABLED") == "1":
    sys.exit(0)

UI_EXTENSIONS = (
    ".tsx", ".jsx", ".vue", ".svelte", ".css", ".scss",
)


def find_design_md(start_dir):
    d = os.path.abspath(start_dir)
    for _ in range(20):
        candidate = os.path.join(d, "DESIGN.md")
        if os.path.isfile(candidate):
            return candidate
        parent = os.path.dirname(d)
        if parent == d:
            break
        d = parent
    return None


def main():
    try:
        data = json.load(sys.stdin)
    except Exception:
        sys.exit(0)

    tool_input = data.get("tool_input", {})
    file_path = tool_input.get("file_path", "")
    if not file_path.lower().endswith(UI_EXTENSIONS):
        sys.exit(0)

    cwd = data.get("cwd") or os.getcwd()
    design_md = find_design_md(os.path.dirname(file_path) or cwd)
    if not design_md:
        sys.exit(0)

    print("", file=sys.stderr)
    print(f"design — {os.path.basename(file_path)} mexe em superfície de UI, projeto tem DESIGN.md ({design_md}):", file=sys.stderr)
    print("  Rode a skill/plugin de design (ex.: `impeccable audit`/`critique`) antes de fechar o incremento.", file=sys.stderr)
    print("  Achado de craft (bom ou ruim) vira entrada em docs/design/exemplars.md, não só memória.", file=sys.stderr)
    print("  (Aviso apenas — edição prossegue)", file=sys.stderr)
    sys.exit(0)


if __name__ == "__main__":
    main()
