#!/usr/bin/env python3
"""Lint de doc de estado e do grafo de domínios do PRD.

    check-docs.py --grafo <raiz-do-projeto>
    check-docs.py --estado <arquivo.md> [<arquivo.md> ...]
    check-docs.py --ciclo <raiz-do-projeto>
    check-docs.py --decay <raiz-do-projeto>
    check-docs.py --estagio <raiz-do-projeto>

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

`--decay` prova que o que é transiente morre. Handoff vencido, inbox que virou
depósito e backlog sem teto não são desorganização: são o gerador de paralisia
de escolha, porque o custo de achar o que importa cresce com o lixo. A idade é o
veredito, e ela se lê de data escrita, não de julgamento.

`--estagio` prova o invariante de estágio único do backlog: todo item aparece em
exatamente um degrau da escada (`INBOX.md`, `TODOS.md`, `docs/specs/<slug>/spec.md`,
`tickets/`, some). Promover é mover, nunca copiar, e o item que sobe sai do degrau de
baixo sem deixar ponteiro nem linha riscada. Doc de raiz que a escada não nomeia é
degrau clandestino: ele não duplica por descuido, duplica por desenho.

Exit 0 limpo, 1 com achado, 2 erro de uso.
"""

from __future__ import annotations

import argparse
import os
import re
import sys
from datetime import date, timedelta
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from lint_common import Achados, fenced_ranges, headings, slugify  # noqa: E402

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
    # O CHANGELOG é o destino do histórico, não um doc de estado: cobrar dele
    # que não tenha seção datada é cobrar que ele não seja o que é. Mesmo motivo
    # do CITA_LIVRE no --ciclo, e pego rodando contra o BIP em 2026-09-15.
    if path.name == "CHANGELOG.md" or "docs/changelog/" in path.as_posix():
        return
    texto = path.read_text(encoding="utf-8", errors="replace")

    for linha, titulo in headings(texto):
        if DATA_HEADING.search(titulo):
            ach.add(nome, linha, f"data em heading ({titulo[:44]!r}); doc de estado não data seção")
        if HEADING_LOG.match(NUMERACAO.sub("", titulo).strip()):
            ach.add(nome, linha, f"seção de log ({titulo[:44]!r}); histórico mora no git e no CHANGELOG")

    for n, ln in enumerate(texto.splitlines(), 1):
        if m := RISCADO.search(ln):
            ach.add(nome, n, f"texto riscado ({m.group(0)[:30]}); estado presente se reescreve, não se risca")


# ---------------------------------------------------------------------- decay

HANDOFF_DIR = "_tmp"
HANDOFF_VIDA = 14          # dias, contados da data no nome quando não há Morre em
TETO_FEEDBACK = 10         # o mesmo teto que o AGENTS.md já manda
TETO_INBOX = 30
TETO_PROXIMOS = 20
IDADE_INBOX = 30           # dias parado antes de a captura virar lixo
IDADE_POOL = 90

SECOES_TODOS = ("Próximos", "Pool")
ISO = re.compile(r"(\d{4}-\d{2}-\d{2})")
ITEM = re.compile(r"^[-*]\s+(.*\S)\s*$")
MORRE_EM = re.compile(r"^\s*(?:[-*]\s*)?\*{0,2}Morre em:?\*{0,2}:?\s*(\S+)", re.I | re.M)


def hoje() -> date:
    """`DECAY_HOJE` congela o relógio: teste de idade sem data fixa é teste que apodrece."""
    if bruto := os.environ.get("DECAY_HOJE"):
        return date.fromisoformat(bruto)
    return date.today()


def data_iso(texto: str) -> date | None:
    if m := ISO.search(texto):
        try:
            return date.fromisoformat(m.group(1))
        except ValueError:
            return None
    return None


def itens_por_secao(path: Path) -> dict[str, tuple[int, list[tuple[int, str]]]]:
    """(linha do heading, itens de primeiro nível) por seção `##` do arquivo.

    A linha do heading vai junto porque seção vazia também é achado, e achado sem
    linha manda o dono procurar à mão.
    """
    linhas = path.read_text(encoding="utf-8", errors="replace").splitlines()
    cercado = fenced_ranges(linhas)
    out: dict[str, tuple[int, list[tuple[int, str]]]] = {"": (0, [])}
    atual = ""
    for i, ln in enumerate(linhas):
        if i in cercado:
            continue
        if m := re.match(r"^##\s+(.*\S)\s*$", ln):
            atual = NUMERACAO.sub("", m.group(1)).strip()
            out.setdefault(atual, (i + 1, []))
            continue
        if m := ITEM.match(ln):
            out.setdefault(atual, (0, []))[1].append((i + 1, m.group(1)))
    return out


def check_decay(raiz: Path, ach: Achados) -> None:
    ref = hoje()

    # 1. handoff: substitui, não acumula, e morre na data que ele mesmo declara
    dir_tmp = raiz / HANDOFF_DIR
    handoffs = sorted(dir_tmp.glob("handoff-*.md")) if dir_tmp.is_dir() else []
    if len(handoffs) > 1:
        nomes = ", ".join(p.name for p in handoffs)
        ach.add(f"{HANDOFF_DIR}/", 0, f"mais de um handoff vivo ({len(handoffs)}): {nomes}; handoff substitui, não acumula")
    for p in handoffs:
        texto = p.read_text(encoding="utf-8", errors="replace")
        if m := MORRE_EM.search(texto):
            morte = data_iso(m.group(1))
        else:
            nascimento = data_iso(p.name)
            morte = nascimento + timedelta(days=HANDOFF_VIDA) if nascimento else None
        rel = f"{HANDOFF_DIR}/{p.name}"
        if morte is None:
            ach.add(rel, 0, "sem data de morte e sem data no nome; handoff sem prazo nunca é apagado")
        elif ref > morte:
            ach.add(rel, 0, f"vencido em {morte.isoformat()}; absorver o que sobrou e apagar")

    # 2. teto do buffer de correção
    fb = raiz / "FEEDBACK.md"
    if fb.exists():
        n = sum(len(itens) for _, itens in itens_por_secao(fb).values())
        if n > TETO_FEEDBACK:
            ach.add("FEEDBACK.md", 0, f"FEEDBACK.md: {n} entradas, teto {TETO_FEEDBACK}; o que virou norma promove ao doc permanente")

    # 3. inbox: captura crua tem teto e tem idade
    inbox = raiz / "INBOX.md"
    if inbox.exists():
        itens = [x for _, lista in itens_por_secao(inbox).values() for x in lista]
        if len(itens) > TETO_INBOX:
            ach.add("INBOX.md", 0, f"{len(itens)} capturas, teto {TETO_INBOX}; inbox que não esvazia virou depósito")
        for linha, texto in itens:
            d = data_iso(texto)
            if d is None:
                ach.add("INBOX.md", linha, f"captura sem data ({texto[:36]!r}); sem data não decai")
            elif (ref - d).days > IDADE_INBOX:
                ach.add("INBOX.md", linha, f"parado há {(ref - d).days} dias ({texto[:30]!r}); promove ou apaga")

    # 4. backlog: dois blocos, teto no ordenado, idade no pool
    todos = raiz / "TODOS.md"
    if todos.exists():
        secoes = itens_por_secao(todos)
        for nome, (linha_h, _) in secoes.items():
            if not nome or nome in SECOES_TODOS:
                continue
            ach.add("TODOS.md", linha_h, f"seção {nome!r} fora do padrão; o backlog tem {' e '.join(SECOES_TODOS)}, e mais eixo é mais paralisia")

        proximos = secoes.get("Próximos", (0, []))[1]
        if len(proximos) > TETO_PROXIMOS:
            ach.add("TODOS.md", 0, f"Próximos com {len(proximos)} itens, teto {TETO_PROXIMOS}; a posição é a prioridade, e lista longa não tem posição")

        for linha, texto in secoes.get("Pool", (0, []))[1]:
            d = data_iso(texto)
            if d is None:
                ach.add("TODOS.md", linha, f"item do Pool sem data ({texto[:36]!r}); sem data não decai")
            elif (ref - d).days > IDADE_POOL:
                ach.add("TODOS.md", linha, f"parado há {(ref - d).days} dias no Pool ({texto[:30]!r}); promove ou apaga", aviso=True)


# -------------------------------------------------------------------- estágio

# Doc de raiz que o doc-standard.md nomeia. O que sobra é degrau que a escada
# não tem, e degrau a mais é o mesmo item vivendo em dois lugares.
RAIZ_CANONICA = {
    "agents.md", "claude.md", "readme.md", "prd.md", "routes.md", "design.md",
    "conventions.md", "changelog.md", "feedback.md", "strategy.md", "memory.md",
    "inbox.md", "todos.md",
    # convenção de repo público, que não é degrau de backlog
    "contributing.md", "license.md", "security.md", "code_of_conduct.md",
}

# Estágios 0 e 1, os dois degraus crus. O 2 (spec) fica de fora de propósito: a
# spec cita o ticket que a executou por desenho, e quem cobra a corrente dela é
# o `check-spec.py --chain`.
DEGRAUS_CRUS = ("INBOX.md", "TODOS.md")

TICKET = re.compile(r"\b([A-Z]{2,6}-\d{1,6})\b")
PONTEIRO_SPEC = re.compile(r"(docs/specs/[\w./-]+|\bspec-\d{4}-\d{2,4}[\w-]*)")
SEM_PALAVRA = re.compile(r"[^0-9a-zà-ÿ]+")
IRRELEVANTE = {"a", "o", "as", "os", "de", "da", "do", "das", "dos", "e", "em",
               "no", "na", "nos", "nas", "um", "uma", "que", "pra", "para",
               "com", "por", "se", "ao", "aos"}
SEMELHANCA = 0.75      # Jaccard: reescrita curta ainda é o mesmo item
MIN_TOKENS = 4         # abaixo disso, coincidência de vocabulário vira falso positivo


def tokens_de(texto: str) -> set[str]:
    """Bag de palavras do item, sem data, sem marcação e sem palavra vazia."""
    sem_data = ISO.sub(" ", texto.lower())
    brutos = SEM_PALAVRA.sub(" ", sem_data).split()
    return {t for t in brutos if t not in IRRELEVANTE and len(t) > 1}


def check_estagio(raiz: Path, ach: Achados) -> None:
    # 1. degrau que a escada não nomeia
    # Nome se compara em caixa baixa: o macOS preserva a caixa e ignora ela na
    # busca, então `inbox.md` é o mesmo arquivo que o `INBOX.md` do padrão. Caixa
    # errada é achado de outro gate; aqui se cobra estágio, não nome.
    for p in sorted(raiz.glob("*.md")):
        nome_base = p.name.lower()
        if nome_base.endswith(".example.md"):
            continue          # molde que se copia, não doc vivo
        if nome_base not in RAIZ_CANONICA:
            ach.add(p.name, 0, f"doc de raiz fora da escada do backlog; a escada tem {' e '.join(DEGRAUS_CRUS)}, e degrau a mais é item vivendo duas vezes")

    itens: dict[str, list[tuple[int, str]]] = {}
    for nome in DEGRAUS_CRUS:
        p = raiz / nome
        if not p.exists():
            continue
        itens[nome] = [x for _, lista in itens_por_secao(p).values() for x in lista]

    for nome, lista in itens.items():
        for linha, texto in lista:
            # 2. citação de ticket em degrau cru
            if m := TICKET.search(texto):
                ach.add(nome, linha, f"cita o ticket {m.group(1)}; item com ticket já está no estágio 3, e estágio único manda ele sair daqui")
            # 3. ponteiro pra spec, que é o degrau de cima
            if m := PONTEIRO_SPEC.search(texto):
                ach.add(nome, linha, f"ponteiro pra spec ({m.group(1)}); item que virou spec sai do degrau de baixo sem deixar linha")

    # 4. o mesmo item nos dois degraus crus
    cru, aceito = (itens.get(n, []) for n in DEGRAUS_CRUS)
    perfis = [(linha, texto, tokens_de(texto)) for linha, texto in cru]
    for linha_a, texto_a, toks_a in [(l, t, tokens_de(t)) for l, t in aceito]:
        if len(toks_a) < MIN_TOKENS:
            continue
        for linha_b, _, toks_b in perfis:
            if len(toks_b) < MIN_TOKENS:
                continue
            uniao = toks_a | toks_b
            if uniao and len(toks_a & toks_b) / len(uniao) >= SEMELHANCA:
                ach.add(DEGRAUS_CRUS[1], linha_a, f"{texto_a[:36]!r} também está em {DEGRAUS_CRUS[0]}:{linha_b}; o item vive em dois estágios, e promover é mover, nunca copiar")
                break


# ----------------------------------------------------------------------- main


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    g = ap.add_mutually_exclusive_group(required=True)
    g.add_argument("--grafo", type=Path, help="raiz do projeto (a que tem PRD.md)")
    g.add_argument("--estado", type=Path, nargs="+", help="doc de estado a checar")
    g.add_argument("--ciclo", type=Path, help="raiz do projeto (checa a árvore de ADR e DDR)")
    g.add_argument("--decay", type=Path, help="raiz do projeto (checa o que devia ter morrido)")
    g.add_argument("--estagio", type=Path, help="raiz do projeto (checa o invariante de estágio único)")
    args = ap.parse_args()

    alvos = args.estado or [args.grafo or args.ciclo or args.decay or args.estagio]
    for alvo in alvos:
        if not alvo.exists():
            print(f"não existe: {alvo}", file=sys.stderr)
            return 2

    ach = Achados()
    if args.grafo:
        check_grafo(args.grafo, ach)
    elif args.ciclo:
        check_ciclo(args.ciclo, ach)
    elif args.decay:
        check_decay(args.decay, ach)
    elif args.estagio:
        check_estagio(args.estagio, ach)
    else:
        for alvo in args.estado:
            check_estado(alvo, ach)
    return ach.report()


if __name__ == "__main__":
    sys.exit(main())
