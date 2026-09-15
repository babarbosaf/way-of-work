#!/usr/bin/env python3
"""Lint de doc de estado e do grafo de domínios do PRD.

    check-docs.py --grafo <raiz-do-projeto>
    check-docs.py --estado <arquivo.md> [<arquivo.md> ...]
    check-docs.py --ciclo <raiz-do-projeto>

`--grafo` prova que a documentação de produto é navegável e recíproca: link
resolve com âncora, todo subdoc de `docs/prd/` está no índice do `PRD.md`, todo
subdoc cita vizinho, toda aresta volta, ninguém é órfão de entrada. Duas páginas
que descrevem o mesmo assunto sem se citar é o caso de duplicação; se citam, uma
delega pra outra.

`--estado` prova que o doc fala do presente. Histórico mora no git e no
CHANGELOG. O sinal é estrutural (data no heading), não léxico: buscar "histórico"
no corpo dá falso positivo em produto cujo domínio é dado histórico.

`--ciclo` prova que a árvore de ADR e DDR só tem decisão vigente. Decisão não é
log: ela vale enquanto o status é vivo, e sai da árvore pro `archive/` quando é
superada. O git guarda a deliberação; a árvore guarda a regra em vigor. O check
também cobre o dano da remoção, quer dizer, o ponteiro que sobra apontando pra
decisão que não está mais lá.

Exit 0 limpo, 1 com achado, 2 erro de uso.
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from lint_common import Achados, headings, slugify  # noqa: E402

# ---------------------------------------------------------------------- grafo

LINK = re.compile(r"\[[^\]]*\]\(([^)\s]+)\)")
SUBDOCS = "docs/prd"


def links_de(path: Path) -> list[tuple[int, str, str]]:
    """(linha, alvo_sem_âncora, âncora) de cada link relativo do arquivo."""
    out = []
    for n, ln in enumerate(path.read_text(encoding="utf-8", errors="replace").splitlines(), 1):
        for m in LINK.finditer(ln):
            alvo = m.group(1)
            if alvo.startswith(("http://", "https://", "mailto:", "#")):
                continue
            destino, _, ancora = alvo.partition("#")
            if destino:
                out.append((n, destino, ancora))
    return out


def ancoras_de(path: Path) -> set[str]:
    texto = path.read_text(encoding="utf-8", errors="replace")
    return {slugify(t) for _, t in headings(texto)}


def check_grafo(raiz: Path, ach: Achados) -> None:
    prd = raiz / "PRD.md"
    if not prd.exists():
        ach.add(str(prd), 0, "raiz sem PRD.md; o índice de domínios mora nele")
        return

    dir_sub = raiz / SUBDOCS
    subdocs = sorted(p for p in dir_sub.glob("*.md")) if dir_sub.is_dir() else []

    # 1. link resolve, e a âncora existe no destino
    alvos_do_prd: set[str] = set()
    for origem in [prd, *subdocs]:
        rel_origem = str(origem.relative_to(raiz))
        for linha, destino, ancora in links_de(origem):
            alvo = (origem.parent / destino).resolve()
            if not alvo.exists():
                ach.add(rel_origem, linha, f"link não resolve: {destino}")
                continue
            if origem == prd:
                alvos_do_prd.add(str(alvo))
            if ancora and alvo.suffix == ".md" and slugify(ancora) not in ancoras_de(alvo):
                ach.add(rel_origem, linha, f"âncora morta: {destino}#{ancora}")

    if not subdocs:
        return

    # 2. todo subdoc citado no índice do PRD
    for sub in subdocs:
        if str(sub.resolve()) not in alvos_do_prd:
            ach.add(f"{SUBDOCS}/{sub.name}", 0, "subdoc fora do índice do PRD.md")

    # 3 e 4. grafo entre domínios: saída, reciprocidade, órfão de entrada
    nomes = {p.name for p in subdocs}
    arestas: set[tuple[str, str]] = set()
    for sub in subdocs:
        for _, destino, _ in links_de(sub):
            nome = Path(destino).name
            if nome in nomes and nome != sub.name:
                arestas.add((sub.name, nome))

    entram = {b for _, b in arestas}
    saem = {a for a, _ in arestas}

    for sub in subdocs:
        rel = f"{SUBDOCS}/{sub.name}"
        if sub.name not in saem:
            ach.add(rel, 0, "sem link de saída pra outro domínio; nenhum doc é autocontido")
        if sub.name not in entram:
            ach.add(rel, 0, "órfão de entrada; quem depende dele não o cita, e a revisão não vê")

    for a, b in sorted(arestas):
        if (b, a) not in arestas:
            ach.add(f"{SUBDOCS}/{a}", 0, f"linka {b} e {b} não volta; aresta de mão única")


# ---------------------------------------------------------------------- ciclo

DECISAO = re.compile(r"^(adr|ddr)-(\d{4})", re.I)
CITA = re.compile(r"\b(ADR|DDR)-(\d{4})\b")
STATUS_BULLET = re.compile(r"^\s*[-*]\s*\*\*Status:?\*\*:?\s*(.+)$", re.I | re.M)
STATUS_YAML = re.compile(r"^status:\s*(.+)$", re.I | re.M)

# Vivo continua na árvore; morto vai pro archive. O vocabulário morto reusa o
# DEAD_STATUSES do lint do llm-wiki, mais as formas de "substituída por".
STATUS_VIVO = {"proposta", "proposto", "aceita", "aceito", "vigente"}
STATUS_MORTO = {
    "substituída", "substituído", "substituida", "substituido",
    "superada", "superado", "morta", "morto", "revogada", "revogado",
}

# Fixture é entrada de teste e memória é estado do agente: nenhuma das duas é
# documentação do produto.
IGNORA_DIR = {"node_modules", "_tmp", "dist", "build", "vendor", ".git", "fixtures", "memory"}
# Onde citar decisão superada é leitura legítima: o CHANGELOG é o histórico por
# doutrina, e pesquisa é artefato datado, que não se reescreve.
CITA_LIVRE = ("CHANGELOG.md", "docs/research/")


def mds_do_projeto(raiz: Path) -> list[Path]:
    return sorted(
        p
        for p in raiz.rglob("*.md")
        if not any(parte in IGNORA_DIR or parte.startswith(".") for parte in p.relative_to(raiz).parts[:-1])
    )


def status_de(texto: str) -> str | None:
    m = STATUS_BULLET.search(texto) or STATUS_YAML.search(texto)
    return m.group(1).strip() if m else None


def check_ciclo(raiz: Path, ach: Achados) -> None:
    arquivos = mds_do_projeto(raiz)
    decisoes: dict[str, Path] = {}
    for p in arquivos:
        if p.name.startswith("_TEMPLATE"):
            continue
        if m := DECISAO.match(p.name):
            decisoes[f"{m.group(1).upper()}-{m.group(2)}"] = p

    arquivada = {k for k, p in decisoes.items() if "archive" in p.parts}

    for chave in sorted(decisoes):
        p = decisoes[chave]
        rel = str(p.relative_to(raiz))
        bruto = status_de(p.read_text(encoding="utf-8", errors="replace"))
        if not bruto:
            ach.add(rel, 0, "sem campo Status; decisão sem status não diz se ainda vale")
            continue

        # Status carrega texto depois do estado ("aceito em tal data", "substituída
        # por tal decisão"): o veredito é a primeira palavra.
        primeira = re.split(r"[\s,.;:]", bruto.strip(), maxsplit=1)[0].lower()
        morta = chave in arquivada

        if primeira in STATUS_MORTO:
            if not morta:
                ach.add(rel, 0, f"status morto ({primeira}) fora do archive; superado sai da árvore e fica no git")
        elif primeira in STATUS_VIVO:
            if morta:
                ach.add(rel, 0, f"decisão viva dentro do archive ({primeira}); quem procura a regra não olha ali")
        else:
            ach.add(rel, 0, f"status {bruto[:30]!r} fora do vocabulário: {', '.join(sorted(STATUS_VIVO))}")

    # Sem árvore de decisão, ADR-NNNN no texto é só texto, e varrer citação só
    # geraria ruído em projeto que não adota o padrão.
    if not decisoes:
        return

    # Dano da remoção: ponteiro que sobrou, e citação de regra que já caiu.
    for p in arquivos:
        rel = str(p.relative_to(raiz))
        if "archive" in p.parts:
            continue
        for n, ln in enumerate(p.read_text(encoding="utf-8", errors="replace").splitlines(), 1):
            for m in CITA.finditer(ln):
                chave = f"{m.group(1).upper()}-{m.group(2)}"
                if chave not in decisoes:
                    ach.add(rel, n, f"cita {chave} e não existe arquivo; ponteiro morto")
                elif chave in arquivada and not rel.startswith(CITA_LIVRE) and "substitu" not in ln.lower():
                    ach.add(rel, n, f"cita {chave}, que está arquivada; a regra em vigor é outra", aviso=True)


# --------------------------------------------------------------------- estado

DATA_HEADING = re.compile(
    r"\b(?:\d{1,2}[/-]\d{1,2}[/-]\d{2,4}"
    r"|\d{4}-\d{2}-\d{2}"
    r"|\d{1,2}\s*[/-]?\s*(?:jan|fev|mar|abr|mai|jun|jul|ago|set|out|nov|dez)\w*\s*[/-]?\s*\d{2,4})\b",
    re.I,
)

HEADING_LOG = re.compile(
    r"^(?:hist[óo]ric\w*|changelog|log\b|decis\w+\s+(?:estrat[ée]gic\w+\s+)?registrad\w+"
    r"|decis\w+\s+tomad\w+|mudan[çc]as\b|vers[õo]es\b)",
    re.I,
)

RISCADO = re.compile(r"~~[^~\n]+~~")

# Heading numerado ("## 14. Decisões registradas") é o caso comum no PRD:
# a numeração ia à frente e desancorava o casamento.
NUMERACAO = re.compile(r"^\s*\d+[.)]\s*")


def check_estado(path: Path, ach: Achados) -> None:
    nome = str(path)
    texto = path.read_text(encoding="utf-8", errors="replace")

    for linha, titulo in headings(texto):
        if DATA_HEADING.search(titulo):
            ach.add(nome, linha, f"data em heading ({titulo[:44]!r}); doc de estado não data seção")
        if HEADING_LOG.match(NUMERACAO.sub("", titulo).strip()):
            ach.add(nome, linha, f"seção de log ({titulo[:44]!r}); histórico mora no git e no CHANGELOG")

    for n, ln in enumerate(texto.splitlines(), 1):
        if m := RISCADO.search(ln):
            ach.add(nome, n, f"texto riscado ({m.group(0)[:30]}); estado presente se reescreve, não se risca")


# ----------------------------------------------------------------------- main


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    g = ap.add_mutually_exclusive_group(required=True)
    g.add_argument("--grafo", type=Path, help="raiz do projeto (a que tem PRD.md)")
    g.add_argument("--estado", type=Path, nargs="+", help="doc de estado a checar")
    g.add_argument("--ciclo", type=Path, help="raiz do projeto (checa a árvore de ADR e DDR)")
    args = ap.parse_args()

    alvos = args.estado or [args.grafo or args.ciclo]
    for alvo in alvos:
        if not alvo.exists():
            print(f"não existe: {alvo}", file=sys.stderr)
            return 2

    ach = Achados()
    if args.grafo:
        check_grafo(args.grafo, ach)
    elif args.ciclo:
        check_ciclo(args.ciclo, ach)
    else:
        for alvo in args.estado:
            check_estado(alvo, ach)
    return ach.report()


if __name__ == "__main__":
    sys.exit(main())
