#!/usr/bin/env python3
"""Lint de spec e de tickets.

Checa sintoma, não tamanho: o que separa uma spec de 270 linhas de uma de 1700
não é contagem, são as seções que não deviam estar lá.

    check-spec.py --spec docs/specs/<slug>/spec.md
    check-spec.py --tickets docs/specs/<slug>/tickets/
    check-spec.py --chain   <raiz-do-projeto>

`--chain` prova a corrente que liga o PRD ao código: a spec aponta pro domínio do
PRD com âncora, cada critério de aceite tem ID estável, cada ticket declara a
spec que serve e os aceites que fecha, e nenhum aceite fica sem ticket. É o que
faz um ticket ser executável por agente sem contexto, e o que garante que o que
foi implementado é o que o PRD prometeu.

A corrente também cobra a **invariante de estágio único**: item que virou spec
sai do backlog. Promover é mover, não copiar, senão o backlog vira depósito de
coisa que já foi feita.

Exit 0 limpo, 1 com achado, 2 erro de uso.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

# ---------------------------------------------------------------- utilidades


def _carrega_comum():
    """Acha `scripts/lint_common.py` subindo a partir deste arquivo.

    O script é chamado tanto por `scripts/check-spec.py` (symlink) quanto pelo
    caminho real dentro da skill; subir procurando é o que sobrevive aos dois.
    """
    for base in Path(__file__).resolve().parents:
        alvo = base / "scripts" / "lint_common.py"
        if alvo.exists():
            sys.path.insert(0, str(alvo.parent))
            return
    raise SystemExit("scripts/lint_common.py não encontrado")


_carrega_comum()
from lint_common import Achados, fenced_ranges, headings, slugify, strip_frontmatter  # noqa: E402


# --------------------------------------------------------------------- spec

SECOES_SPEC = ["Problema", "Como fica", "Decis", "aceite", "Fora de escopo", "Slices"]

PROCESSO = re.compile(
    r"^#{1,4}\s+(?:"
    r"(?:Resposta\s+ao\s+)?(?:Codex\s+)?(?:Gate\s+)?Round\s+\d"
    r"|Resposta\s+ao\s+\w+"
    r"|Anexo\b"
    r"|Codex\s+Gate"
    r"|Findings?\b"
    r")",
    re.I,
)

STATUS_PROCESSO = re.compile(
    r"^\s*(?:status|revised):.*(?:post-reconciliation|round\s*\d|reconciliation\s*v\d"
    r"|pre\s+\w+\s+round|absorvendo)",
    re.I,
)

OWNER_CLAUDE = re.compile(r"^\s*owners?:.*claude", re.I)

DDL = re.compile(r"\b(?:CREATE|ALTER|DROP)\s+(?:TABLE|INDEX|VIEW|MATERIALIZED)\b", re.I)
PYDANTIC = re.compile(r"^\s*class\s+\w+\s*\(\s*(?:BaseModel|BaseSettings)\s*\)")
FENCE_CODIGO = re.compile(r"^\s*```\s*(sql|python|py|typescript|ts|go|rust|java)\b", re.I)

EXT_CODIGO = r"(?:py|ts|tsx|js|jsx|sql|go|rs|java|rb|sh|yaml|yml|toml)"
PATH_CODIGO = re.compile(rf"`[^`\n]*?[\w/-]+/[\w.-]+\.{EXT_CODIGO}[^`\n]*?`")

VAGO = re.compile(
    r"^\s*[-*]\s*(?:\[[ x]\]\s*)?(?:SIM|N[ÃA]O)?:?\s*.*"
    r"\b(?:funcionar?\s+corretamente|funcionar?\s+bem|estar?\s+ok"
    r"|sem\s+problemas?|conforme\s+esperado|de\s+forma\s+adequada)\b",
    re.I,
)


def check_spec(path: Path, ach: Achados) -> None:
    texto = path.read_text(encoding="utf-8", errors="replace")
    nome = str(path)

    corpo, offset = strip_frontmatter(texto)
    linhas_fm = texto[: len(texto) - len(corpo)].splitlines()
    linhas = corpo.splitlines()
    cercado = fenced_ranges(linhas)

    for i, ln in enumerate(linhas_fm, start=1):
        if STATUS_PROCESSO.search(ln):
            ach.add(nome, i, "status de processo no frontmatter; a spec fala do problema, não da rodada")
        if OWNER_CLAUDE.search(ln):
            ach.add(nome, i, "Claude não é coautor do doc; `Owner:` é o humano que decide")

    for i, ln in enumerate(linhas):
        n = i + offset

        if i in cercado and not FENCE_CODIGO.match(ln):
            continue

        if PROCESSO.match(ln):
            ach.add(nome, n, f"seção de processo na spec: {ln.strip()[:48]!r}; o finding vira ticket")
            continue

        if fence := FENCE_CODIGO.match(ln):
            ach.add(nome, n, f"bloco de código ({fence.group(1)}) na spec; design detalhado mora no ticket dono")
            continue

        if DDL.search(ln):
            ach.add(nome, n, "DDL na spec; o ticket que cria a migration é dono do schema")
            continue

        if PYDANTIC.match(ln):
            ach.add(nome, n, "contrato de tipo na spec; mora no ticket que o implementa")
            continue

        if caminho := PATH_CODIGO.search(ln):
            # Aviso, não bloqueio: nomear artefato que já existe (script legado,
            # config que o owner edita) é contexto legítimo. Só quem lê separa
            # isso de vazamento de design detalhado.
            ach.add(
                nome,
                n,
                f"caminho de arquivo na spec ({caminho.group(0)[:36]}); se for arquivo a criar, mora no ticket",
                aviso=True,
            )
            continue

        if VAGO.search(ln):
            ach.add(nome, n, "critério vago; reescrever em SIM/NÃO observável")

    faltando = [s for s in SECOES_SPEC if not re.search(rf"^#{{1,4}}\s+.*{s}", corpo, re.I | re.M)]
    if faltando:
        ach.add(nome, 0, f"seção obrigatória ausente: {', '.join(faltando)}")

    # arquivos irmãos de rodada de review
    irmaos = [
        p.name
        for p in path.parent.glob(f"{path.stem}.*.md")
        if re.search(r"\.(?:\w+-)?round-?\d", p.name, re.I)
    ]
    if irmaos:
        ach.add(nome, 0, f"arquivo de rodada ao lado da spec: {', '.join(sorted(irmaos)[:3])}; o registro é o ticket")


# ------------------------------------------------------------------ tickets

AC = re.compile(r"\bAC-(\d{2})\b")
CAMPOS = ["spec", "closes", "files", "blocked_by", "delega", "verify"]
# `tier:` só é obrigatório onde o task-type do `delega:` declara tier na policy:
# parseado sempre, cobrado condicionalmente.
CAMPOS_LIDOS = CAMPOS + ["tier"]
HEADER = re.compile(r"^\s*(\d+)\s*\[(XS|S|M|L|XL)\]\s*(\[P\])?\s*(.+)$", re.I)
TODO = re.compile(r"<\s*TODO|<\.\.\.>|TBD", re.I)
ID_OK = re.compile(r"^(?:nenhum|none|-)$|^#\d+$")


def tiers_por_task() -> dict[str, set[str]]:
    """Tier que cada task-type aceita, lido da policy: ela é a fonte, e não uma
    tupla aqui. `padrao` é o implícito, que a policy nunca declara porque é o
    próprio `tasks.<task>`. Policy ilegível não bloqueia ticket."""
    pol = Path.home() / ".claude" / "config" / "model-policy.json"
    try:
        tiers = json.loads(pol.read_text(encoding="utf-8")).get("tiers", {})
    except (OSError, ValueError):
        return {}
    return {
        k: {"padrao"} | set(v)
        for k, v in tiers.items()
        if not k.startswith("$") and isinstance(v, dict)
    }


def parse_ticket(path: Path) -> dict:
    texto = path.read_text(encoding="utf-8", errors="replace")
    linhas = texto.splitlines()
    dados: dict = {"path": path, "campos": {}, "linha_campo": {}, "aceite": 0, "header": None}

    for i, ln in enumerate(linhas, start=1):
        if dados["header"] is None:
            m = HEADER.match(re.sub(r"^#+\s*", "", ln).strip())
            if m:
                dados["header"] = {"nn": m.group(1), "tam": m.group(2).upper(), "par": bool(m.group(3)), "linha": i}
        m = re.match(rf"^\s*({'|'.join(CAMPOS_LIDOS)})\s*:\s*(.*)$", ln, re.I)
        if m:
            campo = m.group(1).lower()
            valor = [m.group(2).strip()] if m.group(2).strip() else []
            # continuação indentada (lista de files em várias linhas)
            for cont in linhas[i:]:
                if re.match(r"^\s{4,}\S", cont) and not re.match(rf"^\s*({'|'.join(CAMPOS_LIDOS)})\s*:", cont, re.I):
                    valor.append(cont.strip())
                else:
                    break
            dados["campos"][campo] = valor
            dados["linha_campo"][campo] = i
        if re.match(r"^\s*[-*]\s*\[[ x]\]", ln):
            dados["aceite"] += 1
    return dados


def check_tickets(alvo: Path, ach: Achados) -> None:
    arquivos = sorted(alvo.glob("*.md")) if alvo.is_dir() else [alvo]
    if not arquivos:
        ach.add(str(alvo), 0, "nenhum ticket encontrado")
        return

    paralelos: list[tuple[str, set[str], Path]] = []
    tiers_ok = tiers_por_task()

    for f in arquivos:
        nome = str(f)
        t = parse_ticket(f)

        if t["header"] is None:
            ach.add(nome, 1, "header fora do formato `NN [tamanho] [P] título`")
        else:
            h = t["header"]
            if h["tam"] in ("L", "XL"):
                ach.add(nome, h["linha"], f"ticket [{h['tam']}] não foi fatiado; quebrar em XS/S/M")

        for campo in CAMPOS:
            if campo not in t["campos"]:
                ach.add(nome, 0, f"campo obrigatório ausente: `{campo}:`")
                continue
            valor = t["campos"][campo]
            if not valor:
                ach.add(nome, t["linha_campo"][campo], f"`{campo}:` vazio")

        if t["aceite"] == 0:
            ach.add(nome, 0, "sem aceite em checkbox; não dá pra saber o que é done")

        verify = " ".join(t["campos"].get("verify", []))
        if verify and TODO.search(verify):
            ach.add(nome, t["linha_campo"]["verify"], "`verify:` é placeholder; o repo não tem gate, resolver antes")

        for ref in " ".join(t["campos"].get("blocked_by", [])).replace(",", " ").split():
            if not ID_OK.match(ref.strip()):
                ach.add(nome, t["linha_campo"]["blocked_by"], f"`blocked_by: {ref}` não é ID real; pseudo-ID não ordena nada")

        fecha = " ".join(t["campos"].get("closes", []))
        if fecha and not AC.search(fecha):
            ach.add(nome, t["linha_campo"]["closes"], f"`closes: {fecha[:24]}` não cita AC-NN; sem ID o aceite da spec não é rastreável")

        delega = " ".join(t["campos"].get("delega", [])).strip().lower()
        if delega in ("sim", "yes", "true"):
            ach.add(nome, t["linha_campo"]["delega"], "`delega: sim` não resolve worker; usar task-type ou `não`")

        tier = " ".join(t["campos"].get("tier", [])).strip().lower().replace("padrão", "padrao")
        validos = tiers_ok.get(delega)
        if validos and tier not in validos:
            ach.add(nome, t["linha_campo"]["delega"],
                    f"`delega: {delega}` exige `tier: {'|'.join(sorted(validos))}`; sem tier o dispatch entra "
                    "na fila no escuro (PADRÃO até 5 arquivos próprios sem tocar contrato, AMPLO toca "
                    "contrato ou passa de 5)")
        elif tier and not validos:
            ach.add(nome, t["linha_campo"]["tier"],
                    f"`tier: {tier}` não vale em `delega: {delega}`: a policy não declara tier pra esse task-type")

        files = {x.strip().rstrip(",") for x in t["campos"].get("files", []) if x.strip()}
        if t["header"] and t["header"]["par"] and files:
            paralelos.append((nome, files, f))

    # cruzamento de ownership entre tickets [P]
    for i in range(len(paralelos)):
        for j in range(i + 1, len(paralelos)):
            comum = paralelos[i][1] & paralelos[j][1]
            if comum:
                ach.add(
                    paralelos[i][0],
                    0,
                    f"[P] disputa arquivo com {paralelos[j][2].name}: {', '.join(sorted(comum))}",
                )


# ------------------------------------------------------------------ corrente

CAMPO_LIVRE = re.compile(r"^\s*(\w+)\s*:\s*(.*)$")
# Spec não contratada e spec já entregue não devem ticket pelo mesmo motivo por
# pontas opostas: uma ainda não foi assinada, a outra já foi provada pelo
# harvest. Medido no BIP em 2026-09-15: 37 dos 119 "nenhum ticket fecha esse
# aceite" vinham de dois rascunhos.
STATUS_RASCUNHO = {"rascunho", "draft", "esboço", "esboco", "proposta"}
STATUS_TERMINAL = {"feito", "feita", "entregue", "concluído", "concluida", "concluída", "done"}
BACKLOG = ("TODOS.md", "INBOX.md", "ROADMAP.md")


def campos_frontmatter(texto: str) -> dict[str, str]:
    corpo, _ = strip_frontmatter(texto)
    if corpo == texto:
        return {}
    bruto = texto[: len(texto) - len(corpo)]
    out = {}
    for ln in bruto.splitlines():
        if ln.strip() in ("---", ""):
            continue
        if m := CAMPO_LIVRE.match(ln):
            out[m.group(1).lower()] = m.group(2).strip()
    return out


def acs_da_spec(texto: str) -> dict[str, int]:
    """(AC-NN, linha) de cada critério de aceite numerado."""
    out: dict[str, int] = {}
    for n, ln in enumerate(texto.splitlines(), 1):
        if m := AC.search(ln):
            out.setdefault(f"AC-{m.group(1)}", n)
    return out


def check_chain(raiz: Path, ach: Achados) -> None:
    specs = sorted(raiz.glob("docs/specs/*/spec.md"))
    if not specs:
        ach.add(str(raiz), 0, "nenhuma spec em docs/specs/*/spec.md")
        return

    for spec in specs:
        rel = str(spec.relative_to(raiz))
        texto = spec.read_text(encoding="utf-8", errors="replace")
        fm = campos_frontmatter(texto)
        slug = spec.parent.name

        # 1. a spec aponta pro domínio do PRD, com âncora que existe
        alvo = fm.get("prd", "")
        if not alvo:
            ach.add(rel, 0, "sem campo `prd:`; spec que não cita o PRD não prova que segue o produto")
        else:
            destino, _, ancora = alvo.partition("#")
            arquivo = raiz / destino
            if not arquivo.exists():
                ach.add(rel, 0, f"`prd: {alvo}` não resolve")
            elif not ancora:
                ach.add(rel, 0, f"`prd: {alvo}` sem âncora; apontar pra seção, não pro arquivo inteiro")
            else:
                vivas = {slugify(t) for _, t in headings(arquivo.read_text(encoding="utf-8", errors="replace"))}
                if slugify(ancora) not in vivas:
                    ach.add(rel, 0, f"âncora morta em `prd: {alvo}`")

        # 2. aceite com ID estável e numeração sem furo
        acs = acs_da_spec(texto)
        if not acs:
            ach.add(rel, 0, "nenhum critério de aceite com ID `AC-NN`; sem ID o ticket não tem o que fechar")
        else:
            numeros = sorted(int(k[3:]) for k in acs)
            faltando = [f"AC-{n:02d}" for n in range(1, numeros[-1] + 1) if n not in numeros]
            if faltando:
                ach.add(rel, 0, f"furo na numeração dos aceites: {', '.join(faltando)}")

        # 3. spec terminal declara o que devolveu pro doc de estado
        terminal = fm.get("status", "").strip().lower() in STATUS_TERMINAL
        if terminal and not fm.get("harvest"):
            ach.add(rel, 0, "spec fechada sem `harvest:`; a verdade funcional tem que voltar pro PRD antes de a spec sumir")

        # 4. ticket declara a spec que serve e os aceites que fecha
        rascunho = fm.get("status", "").strip().lower() in STATUS_RASCUNHO
        fechados: set[str] = set()
        tickets = sorted((spec.parent / "tickets").glob("*.md")) if (spec.parent / "tickets").is_dir() else []
        # Spec entregue perde os tickets por desenho: quem prova a entrega é o
        # harvest, e cobrar ticket de spec fechada é cobrar lixo de volta.
        if not tickets and not terminal and not rascunho:
            ach.add(rel, 0, "spec sem tickets; contratado e não endereçado é estágio que não anda")
        for t in tickets:
            rel_t = str(t.relative_to(raiz))
            texto_t = t.read_text(encoding="utf-8", errors="replace")
            campos = {}
            for ln in texto_t.splitlines():
                if m := CAMPO_LIVRE.match(ln):
                    campos.setdefault(m.group(1).lower(), m.group(2).strip())

            if "spec" not in campos:
                ach.add(rel_t, 0, "sem campo spec:; agente sem contexto não sabe que contrato está servindo")
            elif slug not in campos["spec"]:
                ach.add(rel_t, 0, f"`spec: {campos['spec']}` não aponta pra spec que o contém ({slug})")

            citados = set(AC.findall(campos.get("closes", "")))
            if not citados:
                ach.add(rel_t, 0, "sem campo closes:; ticket que não fecha aceite não tem como ser aceito")
            for nn in sorted(citados):
                chave = f"AC-{nn}"
                if chave not in acs:
                    ach.add(rel_t, 0, f"`closes: {chave}` e a spec não tem esse aceite")
                else:
                    fechados.add(chave)

        if not terminal and not rascunho:
            for chave in sorted(set(acs) - fechados):
                ach.add(rel, acs[chave], f"{chave}: nenhum ticket fecha esse aceite")

        # 5. invariante de estágio único: promover é mover, não copiar
        for nome in BACKLOG:
            doc = raiz / nome
            if not doc.exists():
                continue
            for n, ln in enumerate(doc.read_text(encoding="utf-8", errors="replace").splitlines(), 1):
                if slug in ln:
                    ach.add(nome, n, f"rastro de {slug}, que já é spec; promover move o item, não copia")


# --------------------------------------------------------------------- main


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    g = ap.add_mutually_exclusive_group(required=True)
    g.add_argument("--spec", type=Path, help="caminho do spec.md")
    g.add_argument("--tickets", type=Path, help="diretório de tickets, ou um ticket")
    g.add_argument("--chain", type=Path, help="raiz do projeto (checa a corrente PRD, spec, ticket)")
    args = ap.parse_args()

    alvo = args.spec or args.tickets or args.chain
    if not alvo.exists():
        print(f"não existe: {alvo}", file=sys.stderr)
        return 2

    ach = Achados()
    if args.spec:
        check_spec(args.spec, ach)
    elif args.chain:
        check_chain(args.chain, ach)
    else:
        check_tickets(args.tickets, ach)
    return ach.report()


if __name__ == "__main__":
    sys.exit(main())
