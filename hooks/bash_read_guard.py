#!/usr/bin/env python3
"""PreToolUse hook: despejo de arquivo grande por Bash apanha igual ao Read.

Existe porque o enforcement era assimétrico. `read_size_guard` bloqueia Read
acima do threshold, e `cat` do mesmo arquivo passava: o wrapper do rtk reescreve
pra `rtk read`, que no nível default devolve os mesmos bytes. O caminho honesto
apanhava e o silencioso passava, e o modo auto do harness instrui ler com
`cat`/`head`/`sed -n`.

Leitura apontada continua livre, que é a regra do check-bash-read do Portal:
pipe que filtra, `head -N` dentro do teto, redirect pra arquivo (não entra no
transcript). Roda ANTES do rtk-hook-wrapper na cadeia.

Kill switch: BASH_READ_GUARD_DISABLED=1
"""

import json
import os
import re
import shlex
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import shunt_policy  # noqa: E402

# Comandos que despejam arquivo inteiro no transcript.
DUMP_CMDS = {"cat", "bat", "less", "more", "head", "tail", "nl", "view"}
# Consumidores que reduzem: se o despejo vai pra um deles, a leitura é apontada.
FILTERS = {"grep", "rg", "egrep", "fgrep", "ag", "ack", "jq", "yq", "wc", "awk",
           "sed", "sort", "uniq", "cut", "head", "tail", "python3", "python",
           "xargs", "diff", "comm", "tr", "fzf", "column", "rtk"}
# Dois níveis, e a diferença é o bug que a revisão adversarial pegou: `;`, `&&` e
# `||` separam COMANDOS independentes, então filtro num deles não filtra o
# despejo do vizinho. Só `|` encadeia saída.
STMT = re.compile(r"\|\||&&|[;\n]")
NUMFLAG = re.compile(r"^-(\d+)$")
REDIRECT = re.compile(r"(?<![0-9<>])>>?\s*\S")


def block(reason):
    print(json.dumps({"decision": "block", "reason": reason}, ensure_ascii=False))
    sys.exit(0)


def sed_span(argv):
    """Span de `sed -n '1,40p'`. None quando não é range explícito."""
    for arg in argv:
        m = re.match(r"^'?(\d+),(\d+)p'?$", arg)
        if m:
            return int(m.group(2)) - int(m.group(1)) + 1
    return None


def cap_from_flags(argv):
    """Teto de linhas declarado no próprio comando (-50, -n 50, --max-lines 50)."""
    for i, arg in enumerate(argv):
        m = NUMFLAG.match(arg)
        if m:
            return int(m.group(1))
        if arg in ("-n", "-m", "--lines", "--max-lines", "--tail-lines"):
            nxt = argv[i + 1] if i + 1 < len(argv) else ""
            if nxt.isdigit():
                return int(nxt)
        for pref in ("-n", "--lines=", "--max-lines=", "--tail-lines="):
            if arg.startswith(pref) and arg[len(pref):].isdigit():
                return int(arg[len(pref):])
    return None


def effective_lines(files, cap, exempt):
    """Linhas que o comando realmente despeja. `cap` de head/tail/sed é teto POR
    ARQUIVO, não do comando: `head -n 150 a b` imprime 300 linhas."""
    paths, total = [], 0
    for arg in files:
        if Path(arg).suffix.lower() in exempt:
            continue
        lines = shunt_policy.count_lines(arg)
        if lines is None:
            continue
        paths.append(os.path.abspath(arg))
        total += min(cap, lines) if cap is not None else lines
    return paths, total


def scan_statement(stmt, cfg, exempt):
    """(paths, linhas) do despejo deste comando, ou None quando não há despejo."""
    # Redirect e heredoc mandam a saída pro disco, não pro transcript — e valem
    # só pra ESTE comando, não pra linha inteira.
    if REDIRECT.search(stmt) or "<<" in stmt:
        return None

    stages = [x.strip() for x in stmt.split("|") if x.strip()]
    if not stages:
        return None
    try:
        parsed = [shlex.split(x) for x in stages]
    except ValueError:
        return None

    # Despejo consumido por filtro é leitura apontada.
    consumers = {Path(a[0]).name for a in parsed[1:] if a}
    if consumers & FILTERS:
        return None

    for argv in parsed:
        if not argv:
            continue
        name = Path(argv[0]).name
        rest = argv[1:]
        cap = None
        if name == "rtk":
            if not rest or rest[0] != "read":
                continue
            rest = rest[1:]
        elif name == "sed":
            if "-n" not in rest:
                continue
            cap = sed_span(rest)
            if cap is None:
                continue
        elif name not in DUMP_CMDS:
            continue

        if cap is None:
            cap = cap_from_flags(rest)
        paths, total = effective_lines([a for a in rest if not a.startswith("-")], cap, exempt)
        if paths:
            return paths, total
    return None


def main():
    if os.environ.get("BASH_READ_GUARD_DISABLED") == "1":
        sys.exit(0)
    try:
        data = json.load(sys.stdin)
    except Exception:
        sys.exit(0)
    if data.get("tool_name") != "Bash":
        sys.exit(0)
    command = (data.get("tool_input") or {}).get("command") or ""
    if not command.strip():
        sys.exit(0)

    cfg = shunt_policy.load()
    exempt = set(cfg.get("exempt_suffixes") or [])

    for stmt in (x.strip() for x in STMT.split(command)):
        if not stmt:
            continue
        found = scan_statement(stmt, cfg, exempt)
        if found and shunt_policy.route(found[1], cfg) != "inline":
            block(shunt_policy.block_reason(found[1], found[0], cfg))

    sys.exit(0)


if __name__ == "__main__":
    main()
