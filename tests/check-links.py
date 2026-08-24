#!/usr/bin/env python3
"""Lista link markdown relativo que não resolve no disco. rc=1 se achou algum.

Usado por tests/agnostico.test.sh. Citar arquivo removido ao descrever a remoção
é correto; mandar o leitor abrir arquivo que não existe, não.
"""
import os
import re
import subprocess
import sys

ALVO = re.compile(r"\]\(([^)\s]+)\)")


def main():
    files = subprocess.run(
        ["git", "ls-files", "*.md"], capture_output=True, text=True
    ).stdout.split()
    ruins = []
    for f in files:
        base = os.path.dirname(f)
        for n, line in enumerate(open(f, encoding="utf-8"), 1):
            for m in ALVO.finditer(line):
                alvo = m.group(1).split("#")[0]
                if not alvo or alvo.startswith(("http", "mailto:")):
                    continue
                if not os.path.exists(os.path.join(base, alvo)):
                    ruins.append(f"{f}:{n}: {alvo}")
    for r in ruins:
        print(r)
    return 1 if ruins else 0


if __name__ == "__main__":
    sys.exit(main())
