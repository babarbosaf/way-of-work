#!/usr/bin/env python3
"""Lint de spec e de tickets.

Checa sintoma, não tamanho: o que separa uma spec de 270 linhas de uma de 1700
não é contagem, são as seções que não deviam estar lá.

    check-spec.py --spec docs/specs/<slug>/spec.md
    check-spec.py --tickets docs/specs/<slug>/tickets/

Exit 0 limpo, 1 com achado, 2 erro de uso.
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

# ---------------------------------------------------------------- utilidades


def strip_frontmatter(text: str) -> tuple[str, int]:
    """Devolve (corpo, linha_inicial_do_corpo). Frontmatter não é conteúdo."""
    if not text.startswith("---\n"):
        return text, 1
    end = text.find("\n---\n", 4)
    if end == -1:
        return text, 1
    corpo = text[end + 5 :]
    offset = text[: end + 5].count("\n") + 1
    return corpo, offset


def fenced_ranges(lines: list[str]) -> set[int]:
    """Índices (0-based) de linhas dentro de bloco cercado por ```."""
    dentro: set[int] = set()
    aberto = False
    for i, ln in enumerate(lines):
        if ln.lstrip().startswith("```"):
            dentro.add(i)
            aberto = not aberto
            continue
        if aberto:
            dentro.add(i)
    return dentro


class Achados:
    """Bloqueante trava o gate; aviso só informa (pode ser leitura legítima)."""

    def __init__(self) -> None:
        self.itens: list[tuple[str, int, str, bool]] = []

    def add(self, arquivo: str, linha: int, msg: str, aviso: bool = False) -> None:
        self.itens.append((arquivo, linha, msg, aviso))

    def report(self) -> int:
        for arquivo, linha, msg, aviso in self.itens:
            local = f"{arquivo}:{linha}" if linha else arquivo
            print(f"{local}: {'aviso: ' if aviso else ''}{msg}")

        bloqueiam = sum(1 for *_, aviso in self.itens if not aviso)
        avisos = len(self.itens) - bloqueiam

        if bloqueiam:
            resumo = f"{bloqueiam} achado{'s' if bloqueiam > 1 else ''}"
            if avisos:
                resumo += f", {avisos} aviso{'s' if avisos > 1 else ''}"
            print(f"\n{resumo}.")
            return 1

        if avisos:
            print(f"\nsem bloqueio; {avisos} aviso{'s' if avisos > 1 else ''} pra conferir.")
            return 0

        print("limpo.")
        return 0


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

    # frontmatter: status de processo e coautoria
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

    # seções obrigatórias
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

CAMPOS = ["files", "blocked_by", "delega", "verify"]
HEADER = re.compile(r"^\s*(\d+)\s*\[(XS|S|M|L|XL)\]\s*(\[P\])?\s*(.+)$", re.I)
TODO = re.compile(r"<\s*TODO|<\.\.\.>|TBD", re.I)
ID_OK = re.compile(r"^(?:nenhum|none|-)$|^#\d+$")


def parse_ticket(path: Path) -> dict:
    texto = path.read_text(encoding="utf-8", errors="replace")
    linhas = texto.splitlines()
    dados: dict = {"path": path, "campos": {}, "linha_campo": {}, "aceite": 0, "header": None}

    for i, ln in enumerate(linhas, start=1):
        if dados["header"] is None:
            m = HEADER.match(re.sub(r"^#+\s*", "", ln).strip())
            if m:
                dados["header"] = {"nn": m.group(1), "tam": m.group(2).upper(), "par": bool(m.group(3)), "linha": i}
        m = re.match(rf"^\s*({'|'.join(CAMPOS)})\s*:\s*(.*)$", ln, re.I)
        if m:
            campo = m.group(1).lower()
            valor = [m.group(2).strip()] if m.group(2).strip() else []
            # continuação indentada (lista de files em várias linhas)
            for cont in linhas[i:]:
                if re.match(r"^\s{4,}\S", cont) and not re.match(rf"^\s*({'|'.join(CAMPOS)})\s*:", cont, re.I):
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

        delega = " ".join(t["campos"].get("delega", [])).strip().lower()
        if delega in ("sim", "yes", "true"):
            ach.add(nome, t["linha_campo"]["delega"], "`delega: sim` não resolve worker; usar task-type ou `não`")

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


# --------------------------------------------------------------------- main


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    g = ap.add_mutually_exclusive_group(required=True)
    g.add_argument("--spec", type=Path, help="caminho do spec.md")
    g.add_argument("--tickets", type=Path, help="diretório de tickets, ou um ticket")
    args = ap.parse_args()

    alvo = args.spec or args.tickets
    if not alvo.exists():
        print(f"não existe: {alvo}", file=sys.stderr)
        return 2

    ach = Achados()
    if args.spec:
        check_spec(args.spec, ach)
    else:
        check_tickets(args.tickets, ach)
    return ach.report()


if __name__ == "__main__":
    sys.exit(main())
