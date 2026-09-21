#!/usr/bin/env python3
"""Lista ponteiro de doc que não resolve no disco: link markdown relativo e
caminho de script citado em code span. rc=1 se achou algum.

Usado por tests/agnostico.test.sh. Citar arquivo removido ao descrever a remoção
é correto; mandar o leitor abrir arquivo que não existe, não. O CHANGELOG fica de
fora por isso: release publicada nomeia o que existia na época.

Script é cobrado porque o repo mantém dois caminhos válidos pro mesmo arquivo (o
canônico dentro da skill e o symlink em scripts/), e o modo de falhar é um doc
citar o curto onde o symlink não existe. A checagem aceita qualquer um dos dois e
só reclama quando nenhum resolve.
"""
import os
import re
import subprocess
import sys

ALVO = re.compile(r"\]\(([^)\s]+)\)")
SCRIPT = re.compile(r"`(?:~/\.claude/)?((?:scripts|skills/[\w.-]+/scripts)/[\w.-]+\.(?:py|sh))[^`]*`")


def main():
    files = subprocess.run(
        ["git", "ls-files", "*.md"], capture_output=True, text=True
    ).stdout.split()
    ruins = []
    for f in files:
        # Fixture é entrada de teste, não doc: a ruim quebra link de propósito.
        if f.startswith("tests/fixtures/") or f == "CHANGELOG.md":
            continue
        base = os.path.dirname(f)
        for n, line in enumerate(open(f, encoding="utf-8"), 1):
            for m in ALVO.finditer(line):
                alvo = m.group(1).split("#")[0]
                if not alvo or alvo.startswith(("http", "mailto:")):
                    continue
                if not os.path.exists(os.path.join(base, alvo)):
                    ruins.append(f"{f}:{n}: {alvo}")
            for m in SCRIPT.finditer(line):
                alvo = m.group(1)
                # vale o caminho da raiz do repo ou o relativo ao doc (skill cita o próprio scripts/)
                if not (os.path.exists(alvo) or os.path.exists(os.path.join(base, alvo))):
                    ruins.append(f"{f}:{n}: {alvo}")
    for r in ruins:
        print(r)
    return 1 if ruins else 0


if __name__ == "__main__":
    sys.exit(main())
