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
SPLIT = re.compile(r"\|\||&&|[|;\n]")
NUMFLAG = re.compile(r"^-(\d+)$")


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

    # Redirect manda a saída pro disco, não pro transcript. Heredoc idem.
    if re.search(r"(?<![0-9<>])>>?\s*\S", command) or "<<" in command:
        sys.exit(0)

    segments = [s.strip() for s in SPLIT.split(command) if s.strip()]
    if not segments:
        sys.exit(0)

    # Despejo consumido por filtro é leitura apontada: libera.
    consumers = set()
    for seg in segments[1:]:
        try:
            argv = shlex.split(seg)
        except ValueError:
            sys.exit(0)
        if argv:
            consumers.add(Path(argv[0]).name)
    if consumers & FILTERS:
        sys.exit(0)

    cfg = shunt_policy.load()
    exempt = set(cfg.get("exempt_suffixes") or [])

    for seg in segments:
        try:
            argv = shlex.split(seg)
        except ValueError:
            sys.exit(0)
        if not argv:
            continue
        name = Path(argv[0]).name
        rest = argv[1:]
        if name == "rtk":
            if not rest or rest[0] != "read":
                continue
            rest = rest[1:]
        elif name == "sed":
            if "-n" not in rest:
                continue
            span = sed_span(rest)
            if span is None or span <= cfg["grep_max"]:
                continue
        elif name not in DUMP_CMDS:
            continue

        # `-N`/`-n N` dentro do teto é paginação declarada, não despejo.
        cap = cap_from_flags(rest)
        if cap is not None and cap <= cfg["grep_max"]:
            continue

        paths, total = [], 0
        for arg in rest:
            if arg.startswith("-"):
                continue
            if Path(arg).suffix.lower() in exempt:
                continue
            lines = shunt_policy.count_lines(arg)
            if lines is None:
                continue
            paths.append(str(Path(arg).resolve()))
            total += lines
        if not paths:
            continue
        if cap is not None and cap < total:
            total = cap
        if shunt_policy.route(total, cfg) != "inline":
            block(shunt_policy.block_reason(total, paths, cfg))

    sys.exit(0)


if __name__ == "__main__":
    main()
