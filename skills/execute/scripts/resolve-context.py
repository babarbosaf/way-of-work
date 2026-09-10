#!/usr/bin/env python3
"""Resolve o contexto de uma rodada de /execute e devolve JSON.

Lê, a partir da raiz do repo:
  - `.claude/project.yaml` (tracker.backend, repo.trunk, repo.branch_prefix,
    verify_cmd, smoke_cmd)
  - `docs/specs/<slug>/spec.md`
  - `docs/specs/<slug>/tickets/*.md` (backend none), header parseado
  - `_tmp/execute/<slug>.md` (brief), se existir

    resolve-context.py <slug> [--root <repo>] [--simplify-min 6]

Exit 0 contexto completo, 1 com erro bloqueante listado em `errors`,
2 erro de uso. Aviso não trava: vai em `warnings`.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

SIMPLIFY_MIN = 6
PLACEHOLDER = re.compile(r"<\s*TODO", re.IGNORECASE)
HEADER = re.compile(r"^(?P<nn>\d{2})\s+\[(?P<size>XS|S|M|L)\]\s+(?:\[(?P<p>P)\]\s+)?(?P<title>.+?)\s*$")
FIELD = re.compile(r"^(?P<key>files|blocked_by|delega|verify|status|bloqueado):\s*(?P<val>.*)$")


def read_yaml_flat(path: Path) -> dict:
    """Parser mínimo pro project.yaml: chave: valor, um nível de aninhamento.

    Sem PyYAML como dependência. Cobre o que o template usa; comentário `#` cai.
    """
    out: dict = {}
    section = None
    if not path.exists():
        return out
    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.split("#", 1)[0].rstrip()
        if not line.strip():
            continue
        indent = len(line) - len(line.lstrip())
        key, _, val = line.strip().partition(":")
        val = val.strip().strip('"').strip("'")
        if indent == 0:
            if val == "":
                section = key
                out.setdefault(section, {})
            else:
                section = None
                out[key] = val
        elif section is not None:
            out[section][key] = val
    return out


def parse_ticket(path: Path) -> dict:
    lines = path.read_text(encoding="utf-8").splitlines()
    t: dict = {"file": str(path), "id": path.stem, "files": [], "aceite_total": 0, "aceite_ok": 0}
    m = HEADER.match(lines[0]) if lines else None
    if m:
        t.update(nn=m["nn"], size=m["size"], parallel=bool(m["p"]), title=m["title"].strip())
    else:
        t["header_invalid"] = True
    last_key = None
    for line in lines[1:]:
        f = FIELD.match(line)
        if f:
            last_key = f["key"]
            if last_key == "files":
                t["files"] = [f["val"].strip()] if f["val"].strip() else []
            else:
                t[last_key] = f["val"].strip()
            continue
        if last_key == "files" and line.startswith((" ", "\t")) and line.strip():
            t["files"].append(line.strip())
            continue
        last_key = None
        if re.match(r"^- \[[ xX]\]", line):
            t["aceite_total"] += 1
            if re.match(r"^- \[[xX]\]", line):
                t["aceite_ok"] += 1
    t.setdefault("status", "ready")
    return t


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("slug")
    ap.add_argument("--root", default=".")
    ap.add_argument("--simplify-min", type=int, default=SIMPLIFY_MIN)
    args = ap.parse_args(argv)

    root = Path(args.root).resolve()
    errors: list[str] = []
    warnings: list[str] = []

    yaml = read_yaml_flat(root / ".claude" / "project.yaml")
    tracker = yaml.get("tracker", {}) if isinstance(yaml.get("tracker"), dict) else {}
    repo = yaml.get("repo", {}) if isinstance(yaml.get("repo"), dict) else {}
    backend = tracker.get("backend", "none") or "none"
    verify_cmd = yaml.get("verify_cmd", "")
    smoke_cmd = yaml.get("smoke_cmd", "")

    if not (root / ".claude" / "project.yaml").exists():
        warnings.append("sem .claude/project.yaml: backend none, trunk main assumidos")
    if not verify_cmd or PLACEHOLDER.search(verify_cmd):
        errors.append("verify_cmd ausente ou placeholder no project.yaml: nenhum ticket fecha sem verify real")
    if smoke_cmd and PLACEHOLDER.search(smoke_cmd):
        warnings.append("smoke_cmd é placeholder: cenário não roda até preencher")
        smoke_cmd = ""

    spec = root / "docs" / "specs" / args.slug / "spec.md"
    if not spec.exists():
        errors.append(f"spec não encontrada: {spec.relative_to(root)}")

    tickets: list[dict] = []
    tickets_dir = spec.parent / "tickets"
    if backend == "none":
        if tickets_dir.is_dir():
            tickets = [parse_ticket(p) for p in sorted(tickets_dir.glob("*.md"))]
            if not tickets:
                errors.append(f"nenhum ticket em {tickets_dir.relative_to(root)}: rodar /to-tickets antes")
            for t in tickets:
                if t.get("header_invalid"):
                    errors.append(f"{t['id']}: header fora do formato `NN [tamanho] [P] título`")
                for k in ("files", "blocked_by", "delega", "verify"):
                    if not t.get(k):
                        errors.append(f"{t['id']}: campo `{k}:` ausente")
                if t.get("size") == "L":
                    errors.append(f"{t['id']}: tamanho L, quebrar antes de executar")
        elif spec.exists():
            errors.append(f"sem diretório de tickets: {tickets_dir.relative_to(root)}")
    else:
        warnings.append(f"backend {backend}: tickets vivem no tracker, buscar por spec/label")

    brief = root / "_tmp" / "execute" / f"{args.slug}.md"
    ticket_count = len(tickets)

    out = {
        "slug": args.slug,
        "root": str(root),
        "spec": str(spec) if spec.exists() else None,
        "brief": str(brief) if brief.exists() else None,
        "tracker_backend": backend,
        "trunk": repo.get("trunk", "main") or "main",
        "branch_prefix": repo.get("branch_prefix", "feature") or "feature",
        "verify_cmd": verify_cmd,
        "smoke_cmd": smoke_cmd,
        "tickets": tickets,
        "ticket_count": ticket_count,
        "simplify_suggested": ticket_count >= args.simplify_min,
        "warnings": warnings,
        "errors": errors,
    }
    print(json.dumps(out, ensure_ascii=False, indent=2))
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
