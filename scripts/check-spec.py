#!/usr/bin/env python3
"""Ponte para o lint de spec, que mora na skill dona dele.

Aqui não pode ser symlink. No Windows o clone escreve o link como arquivo de
texto com o caminho dentro, e o interpretador executa esse texto como script:
a suíte inteira cai, e cai dizendo erro de sintaxe, que manda quem lê procurar
defeito no lugar errado. O shim resolve o caminho relativo a si mesmo e delega
com runpy, então vale nos dois sistemas sem duplicar lógica.
"""

import runpy
import sys
from pathlib import Path

REAL = Path(__file__).resolve().parent.parent / "skills" / "to-spec" / "scripts" / "check-spec.py"
sys.argv[0] = str(REAL)
runpy.run_path(str(REAL), run_name="__main__")
