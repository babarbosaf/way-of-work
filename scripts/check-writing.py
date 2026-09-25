#!/usr/bin/env python3
"""Ponte para o lint de escrita, que mora na skill dona dele.

Aqui não pode ser symlink. No Windows o clone escreve o link como arquivo de
texto com o caminho dentro, e o interpretador executa esse texto como script.
Este é o caminho que o `AGENTS.md` manda rodar antes de todo commit, então um
link morto aqui desarma o gate de escrita sem ninguém perceber. O shim resolve
o caminho relativo a si mesmo e delega com runpy, e vale nos dois sistemas.
"""

import runpy
import sys
from pathlib import Path

REAL = Path(__file__).resolve().parent.parent / "skills" / "writing" / "scripts" / "check-writing.py"
sys.argv[0] = str(REAL)
runpy.run_path(str(REAL), run_name="__main__")
