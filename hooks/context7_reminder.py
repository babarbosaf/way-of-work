#!/usr/bin/env python3
"""PreToolUse (Edit|Write|MultiEdit) — lembra 'use context7' antes de mexer
em dependência ou import novo. Não bloqueia (exit 0), só avisa via stderr.
Kill: CONTEXT7_REMINDER_DISABLED=1
"""
import json
import os
import re
import sys

if os.environ.get("CONTEXT7_REMINDER_DISABLED") == "1":
    sys.exit(0)

MANIFESTS = {
    "package.json", "requirements.txt", "pyproject.toml", "pipfile",
    "go.mod", "gemfile", "composer.json", "cargo.toml",
}

IMPORT_RE = re.compile(
    r'^\s*(import\s+[\w.]+|from\s+[\w.]+\s+import|const\s+.+=\s*require\(|'
    r'import\s*\{.*\}\s*from\s+["\']|import\s+\w+\s+from\s+["\']|use\s+[\w:]+;)',
    re.MULTILINE,
)


def old_new_pairs(tool_name, tool_input):
    if tool_name == "Write":
        return [("", tool_input.get("content", ""))]
    if tool_name == "Edit":
        return [(tool_input.get("old_string", ""), tool_input.get("new_string", ""))]
    if tool_name == "MultiEdit":
        return [(e.get("old_string", ""), e.get("new_string", "")) for e in tool_input.get("edits", [])]
    return []


def main():
    try:
        data = json.load(sys.stdin)
    except Exception:
        sys.exit(0)

    tool_name = data.get("tool_name", "")
    tool_input = data.get("tool_input", {})
    file_path = tool_input.get("file_path", "")
    basename = os.path.basename(file_path).lower()

    if basename in MANIFESTS:
        print("", file=sys.stderr)
        print("context7 — arquivo de dependências mexido:", basename, file=sys.stderr)
        print("  Antes de fixar versão/lib nova: `use context7` pra doc atual.", file=sys.stderr)
        print("  (Aviso apenas — edição prossegue)", file=sys.stderr)
        sys.exit(0)

    new_libs = set()
    for old, new in old_new_pairs(tool_name, tool_input):
        old_imports = set(IMPORT_RE.findall(old))
        new_imports = set(IMPORT_RE.findall(new))
        added = new_imports - old_imports
        new_libs.update(added)

    if new_libs:
        print("", file=sys.stderr)
        print(f"context7 — import novo detectado em {basename}:", file=sys.stderr)
        for lib in sorted(new_libs)[:5]:
            print(f"   {lib.strip()}", file=sys.stderr)
        print("  API/assinatura incerta? `use context7` antes de fechar a chamada.", file=sys.stderr)
        print("  (Aviso apenas — edição prossegue)", file=sys.stderr)

    sys.exit(0)


if __name__ == "__main__":
    main()
