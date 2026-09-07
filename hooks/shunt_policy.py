#!/usr/bin/env python3
"""Threshold de leitura como dado, e a mensagem de rota num lugar só.

Lido de `config/model-policy.json`, chave `.shunt` (com merge do
`.local.json`, se existir). Dois degraus, porque os dois tiers de leitura têm
custo de latência muito diferente:

    <= grep_max            resolve inline, compressor local nem paga o overhead
    grep_max .. worker_min  grep + Read paginado
    >  worker_min           shunt pro worker (delegate --task scan)

Overrides de env: SHUNT_GREP_MAX, SHUNT_MIN_LINES (worker_min), SHUNT_POLICY.
Rodado como script, imprime a config efetiva em JSON (é assim que a suíte lê).
"""

import json
import os
from pathlib import Path

DEFAULTS = {
    "grep_max": 200,
    "worker_min": 500,
    "exempt_suffixes": [".png", ".jpg", ".jpeg", ".gif", ".pdf", ".ipynb",
                        ".zip", ".woff", ".woff2", ".mp4", ".webp", ".ico"],
}


def _policy_path():
    env = os.environ.get("SHUNT_POLICY")
    if env:
        return Path(env)
    return Path(__file__).resolve().parent.parent / "config" / "model-policy.json"


def load():
    """Config efetiva. Policy ausente, ilegível ou corrompida devolve DEFAULTS:
    hook que quebra a sessão é pior que hook que não otimiza."""
    cfg = dict(DEFAULTS)
    base = _policy_path()
    for path in (base, base.with_suffix(".local.json")):
        try:
            with open(path) as f:
                shunt = json.load(f).get("shunt") or {}
            if isinstance(shunt, dict):
                cfg.update({k: v for k, v in shunt.items() if not k.startswith("$")})
        except Exception:
            continue

    for key, var in (("grep_max", "SHUNT_GREP_MAX"), ("worker_min", "SHUNT_MIN_LINES")):
        raw = os.environ.get(var)
        if raw and raw.strip().isdigit():
            cfg[key] = int(raw)

    for key in ("grep_max", "worker_min"):
        try:
            cfg[key] = int(cfg[key])
        except (TypeError, ValueError):
            cfg[key] = DEFAULTS[key]
    if cfg["worker_min"] < cfg["grep_max"]:
        cfg["worker_min"] = cfg["grep_max"]
    return cfg


def is_exempt(path, cfg=None):
    cfg = cfg or load()
    return Path(path).suffix.lower() in set(cfg.get("exempt_suffixes") or [])


def count_lines(path):
    """None quando não é arquivo de texto legível — chamador libera."""
    try:
        p = Path(path)
        if not p.is_file():
            return None
        with open(p, "r", errors="ignore") as f:
            return sum(1 for _ in f)
    except Exception:
        return None


def route(line_count, cfg=None):
    cfg = cfg or load()
    if line_count > cfg["worker_min"]:
        return "shunt"
    if line_count > cfg["grep_max"]:
        return "paginate"
    return "inline"


def _q(text):
    return text.replace('"', '\\"')


def block_reason(line_count, paths, cfg=None, question=None):
    """Mensagem única dos dois guards. Bloqueio que ensina a paginar mantém os
    tokens na janela cara; bloqueio que roteia troca de janela."""
    cfg = cfg or load()
    paths = [str(p) for p in (paths if isinstance(paths, (list, tuple)) else [paths])]
    plural = "s" if len(paths) > 1 else ""
    head = f"Leitura grande: {line_count} linhas em {len(paths)} arquivo{plural}."

    if route(line_count, cfg) == "shunt":
        q = question or "<a pergunta que essa leitura ia responder>"
        return (
            f"{head} Acima de {cfg['worker_min']} linhas o corpus não entra nesta "
            "janela: pergunte ao worker grátis, que devolve só a resposta.\n\n"
            "  ~/.claude/scripts/delegate.sh --task scan \\\n"
            f"    --paths {' '.join(paths)} \\\n"
            f'    --question "{_q(q)}"\n\n'
            "Precisa editar, e não perguntar? Grep pra achar a linha, depois Read "
            "com offset+limit só na seção. Skill: delegate."
        )
    return (
        f"{head} Grep primeiro pra localizar a seção, depois Read com "
        f"offset+limit (teto {cfg['grep_max']} linhas por leitura). "
        f"Acima de {cfg['worker_min']} linhas a rota muda pro worker "
        "(skill delegate)."
    )


if __name__ == "__main__":
    print(json.dumps(load()))
