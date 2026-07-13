#!/usr/bin/env python3
"""PreToolUse hook: bloqueia comandos no-op usados como "flush" de resultados.

Motivação: resultados de tool às vezes renderizam atrasados; o agente
interpreta como "buffer pendente" e tenta esvaziar com comandos no-op
(`true`, `:`, `sleep N`). Não existe buffer pra flush — o resultado chega
sozinho. Cada no-op é um round-trip completo que incha o contexto e custa
token (relido em toda rodada seguinte). Ver memória
feedback_no_op_flush_antipattern.md.

Escopo deliberadamente estreito (baixo falso-positivo): só bloqueia o
comando quando ele se reduz a um no-op puro. `echo`/`printf`/query-ping
NÃO entram aqui (exigem julgamento de intenção) — ficam na camada de
memória/CLAUDE.md.

Lê PreToolUse JSON do stdin. Retorna JSON {"decision":"block","reason":...}
pra bloquear, ou exit 0 silencioso pra permitir.

Kill switch: NOOP_GUARD_DISABLED=1 → bypass.
"""

import json
import os
import re
import sys

# Comando (já desembrulhado de wrappers rtk) que é exatamente um destes → no-op.
_EXACT_NOOPS = {"true", ":", "false"}
# `sleep 5`, `sleep 0.3` etc. isolado → espera inútil (foreground sleep já é
# bloqueado pelo harness, mas reforçamos a intenção aqui).
_SLEEP_RE = re.compile(r"^sleep\s+\d+(\.\d+)?$")

_REASON = (
    "no-op detectado ('{cmd}'). Resultados de tool chegam sozinhos — não há "
    "buffer pra flush; render atrasado é artefato visual, não algo que comando "
    "no-op resolve. Faça apenas chamadas reais e aguarde. "
    "(kill switch: NOOP_GUARD_DISABLED=1)"
)


def _unwrap(cmd: str) -> str:
    """Remove prefixos de wrapper (rtk) pra avaliar o comando real."""
    cmd = cmd.strip()
    for prefix in ("rtk proxy ", "rtk "):
        if cmd.startswith(prefix):
            return cmd[len(prefix):].strip()
    return cmd


def is_noop(command: str) -> bool:
    if not command:
        return False
    cmd = _unwrap(command)
    if cmd in _EXACT_NOOPS:
        return True
    if _SLEEP_RE.match(cmd):
        return True
    return False


def main() -> int:
    if os.environ.get("NOOP_GUARD_DISABLED") == "1":
        return 0
    try:
        payload = json.load(sys.stdin)
    except (json.JSONDecodeError, ValueError):
        return 0  # não é nosso problema; deixa passar
    if payload.get("tool_name") != "Bash":
        return 0
    command = payload.get("tool_input", {}).get("command", "")
    if is_noop(command):
        print(json.dumps({
            "decision": "block",
            "reason": _REASON.format(cmd=_unwrap(command)),
        }))
        return 0
    return 0


if __name__ == "__main__":
    sys.exit(main())
