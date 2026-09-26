#!/usr/bin/env python3
"""Lint de doc de estado e do grafo de domínios do PRD.

    check-docs.py --grafo <raiz-do-projeto>
    check-docs.py --estado <arquivo.md> [<arquivo.md> ...]
    check-docs.py --ciclo <raiz-do-projeto>
    check-docs.py --decay <raiz-do-projeto>
    check-docs.py --molde <arquivo.md> [<arquivo.md> ...]
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

`--molde` prova que cada doc de raiz fica no papel dele. Mapa de docs e árvore de
pastas só existem no README, e o CONVENTIONS tem teto de tamanho, porque guarda só a
regra universal. Fugir do molde é permitido quando declarado: `> **Desvio do molde:**
<motivo>` nas primeiras linhas cala o check daquele arquivo.

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
    dir_sub = raiz / SUBDOCS
    subdocs = sorted(p for p in dir_sub.glob("*.md")) if dir_sub.is_dir() else []

    if not prd.exists():
        # Cláusula de não-adoção, a mesma do --ciclo sem árvore de decisão: repo
        # de doutrina não instancia produto, e cobrar dele o índice é cobrar um
        # doc que a doutrina não manda existir. Subdoc sem índice continua
        # achado, porque aí o padrão foi adotado pela metade e o domínio não tem
        # porta de entrada.
        if subdocs:
            ach.add(str(prd), 0, "raiz sem PRD.md e docs/prd/ com subdoc; o índice de domínios mora nele")
        return

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
#
# O vocabulário é bilíngue por união, e cada termo tem gêmeo no outro idioma: a
# regra é uma, e só o idioma muda. Repo com remoto nasce em inglês, repo que fica
# na máquina é PT-BR, e o mesmo linter cobra os dois. Declarar o idioma num campo
# seria uma segunda fonte de verdade sobre o que o texto já diz, e o campo
# desatualizado calaria o check em vez de acusar.
STATUS_VIVO = {
    "proposta", "proposto", "aceita", "aceito", "vigente",
    "proposed", "accepted", "current",
}
STATUS_MORTO = {
    "substituída", "substituído", "substituida", "substituido",
    "superada", "superado", "morta", "morto", "revogada", "revogado",
    "superseded", "obsolete", "dead", "revoked",
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

MES = r"(?:jan|fev|feb|mar|abr|apr|mai|may|jun|jul|ago|aug|set|sep|out|oct|nov|dez|dec)\w*"

DATA_HEADING = re.compile(
    r"\b(?:\d{1,2}[/-]\d{1,2}[/-]\d{2,4}"
    r"|\d{4}-\d{2}-\d{2}"
    r"|\d{1,2}\s*[/-]?\s*" + MES + r"\s*[/-]?\s*\d{2,4}"
    # Ordem inglesa, mês primeiro: "Jan 5, 2026".
    r"|" + MES + r"\s+\d{1,2},?\s+\d{4})\b",
    re.I,
)

HEADING_LOG = re.compile(
    r"^(?:hist[óo]ric\w*|changelog|log\b|decis\w+\s+(?:estrat[ée]gic\w+\s+)?registrad\w+"
    r"|decis\w+\s+tomad\w+|mudan[çc]as\b|vers[õo]es\b"
    r"|histor\w*|revision\s+histor\w*|decisions?\s+(?:made|recorded|taken|log)\b"
    r"|changes\b|versions\b)",
    re.I,
)

RISCADO = re.compile(r"~~[^~\n]+~~")

# Heading numerado ("## 14. Decisões registradas") é o caso comum no PRD:
# a numeração ia à frente e desancorava o casamento.
NUMERACAO = re.compile(r"^\s*\d+[.)]\s*")
# Bloco de pergunta aberta empilhada no fim da seção, o padrão 35 do catálogo de
# escrita. Some da vista e apodrece, porque item sem dono e sem prazo não é
# cobrado por ninguém. O lugar dele é o backlog, que decai, ou a célula exata da
# tabela onde quem for implementar esbarra.
# Seção chamada "em aberto" é depósito; a tag `em aberto` marca uma
# funcionalidade que ainda não foi decidida. São coisas diferentes, e a tag mora
# entre crases, então os dois checks não se cruzam.
HEADING_ABERTO = re.compile(
    r"^(pontos?\s+(a\s+definir|em\s+aberto)|quest(õ|o)es\s+em\s+aberto"
    r"|a\s+definir|d[úu]vidas\s+em\s+aberto|tbd"
    r"|open\s+(questions|points|items)|to\s+be\s+(defined|decided))\b",
    re.I,
)


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
        if HEADING_ABERTO.match(NUMERACAO.sub("", titulo).strip()):
            ach.add(nome, linha, f"seção de pontos em aberto ({titulo[:44]!r}); item sem dono apodrece: vai pro backlog, ou vira 'a definir' na célula")

    for n, ln in enumerate(texto.splitlines(), 1):
        if m := RISCADO.search(ln):
            ach.add(nome, n, f"texto riscado ({m.group(0)[:30]}); estado presente se reescreve, não se risca")

    subdoc = "docs/prd/" in path.as_posix()
    if path.name in COBRA_TAG or subdoc:
        # PRD índice delega a tag aos subdocs de docs/prd/, que são cobrados por seção.
        indice = path.name == "PRD.md" and "docs/prd/" in texto
        check_tags(texto, nome, ach, exige_tag=not (subdoc or indice))


# A tag marca a funcionalidade, não a seção: vai na primeira linha quando a seção
# inteira está num estado, e no item quando mistura. No título não: o slug é âncora,
# e trocar `previsto` por `no ar` quebraria todo link para a seção. Funcionalidade é a seção H2 do PRD
# que tem "### Comportamento"; visão geral e restrição não levam tag. Os quatro
# exemplos do kickoff passavam limpos com zero tag, porque nada cobrava a regra.
# `previsto` é decidido e não construído; `em aberto` é o que ainda nem foi
# decidido. Sem os dois, tudo que não está no ar cai em `previsto`, e o leitor
# não distingue o que tem spec do que tem só intenção.
TAGS = (
    "parcialmente no ar", "no ar", "previsto", "em aberto",
    "partially live", "live", "planned", "open",
)
TAG = re.compile(r"`(?:" + "|".join(TAGS) + r")`", re.I)
COBRA_TAG = {"PRD.md", "README.md"}

# Tag sozinha na primeira linha marca a seção inteira. Só `em aberto` é barrado
# aí: seção cujo estado inteiro é "nem decidido" não tem o que descrever, e os
# três atos saem preenchidos com `a definir`. Isso é item de backlog vestido de
# seção, e o preço é duplo: o PRD engorda com prosa sobre um buraco, e a lacuna
# sai da fila, que é o único lugar onde ela decai e cobra dono.
SO_TAG_ABERTA = re.compile(r"^`(?:em aberto|open)`\s*$", re.I)


def check_tags(texto: str, nome: str, ach: Achados, exige_tag: bool) -> None:
    if exige_tag and not TAG.search(texto):
        ach.add(nome, 0, "doc de estado sem tag; cada funcionalidade leva `no ar`, `previsto` ou `em aberto` (`live`, `planned`, `open`)")
        return
    secoes: list[tuple[int, str, list[str]]] = []
    cerca = False
    for n, ln in enumerate(texto.splitlines(), 1):
        if ln.lstrip().startswith("```"):
            cerca = not cerca
        if not cerca and ln.startswith("## "):
            secoes.append((n, ln[3:].strip(), []))
        elif secoes:
            secoes[-1][2].append(ln)
    for n, titulo, corpo in secoes:
        funcionalidade = any(PROPOSITO.match(c) for c in corpo)
        if funcionalidade and not TAG.search(titulo) and not any(TAG.search(c) for c in corpo):
            ach.add(nome, n, f"funcionalidade sem tag ({titulo[:44]!r}); marque o estado na primeira linha ou em cada item")
        if TAG.search(titulo):
            ach.add(nome, n, f"tag no título ({titulo[:44]!r}); o slug é âncora e quebra na troca de estado: tag na primeira linha")
        primeira = next((c.strip() for c in corpo if c.strip()), "")
        if funcionalidade and SO_TAG_ABERTA.match(primeira):
            ach.add(nome, n, f"seção inteira `em aberto` ({titulo[:44]!r}); lacuna não é seção de PRD: "
                             "vira linha no TODOS ou spec, e `a definir` na célula onde ela morde")


# ---------------------------------------------------------------------- molde

# Os três atos de uma funcionalidade, sempre os mesmos e sempre nesta ordem:
# para que ela serve, como se caminha por ela, e o que ela garante. Faltar um é
# especificar só o caminho feliz; trocar a ordem é pedir que o leitor monte a
# garantia antes de conhecer o fluxo que ela governa.
#
# Regras absorve o que antes eram duas subseções soltas: o contrato, que já era
# tabela de regra, e o edge case, que já era gatilho seguido de consequência. As
# duas diziam "o produto garante isto" em lugares diferentes, e uma garantia só
# tem um lugar.
SUBSECOES = ("Propósito", "Fluxo", "Regras")
SUB_IDIOMA = {
    "propósito": 0, "proposito": 0, "purpose": 0,
    "fluxo": 1, "flow": 1,
    "regras": 2, "rules": 2,
}
SUB = re.compile(r"^###\s+(.+?)\s*$")
# A presença do primeiro ato é o que faz de uma seção uma funcionalidade. Visão
# geral, restrição e relacionados não descrevem uma, e não levam os três.
PROPOSITO = re.compile(r"###\s+(?:Propósito|Proposito|Purpose)\b", re.I)

# Doc que ainda não foi refatiado nos três atos. A lista é declarada e datada de
# propósito: exemption silenciosa é como um padrão morre sem ninguém decidir
# matá-lo. Chegou vazia em 2026-09-25, e o estado vazio é o certo.
MIGRANDO: tuple[str, ...] = ()

DOCS_RAIZ = {"README.md", "AGENTS.md", "PRD.md", "CONVENTIONS.md", "ROUTES.md", "DESIGN.md"}
LINK_DOC_RAIZ = re.compile(r"\]\((?:\./)?(" + "|".join(re.escape(d) for d in DOCS_RAIZ) + r")[#)]")
# Entrada de árvore é "├── nome", sem seta. Diagrama de fluxo usa os mesmos traços
# ("└────┘", "├── falta algo ──▶"), e dois PRDs do kirara acusavam por isso.
ARVORE = re.compile(r"[├└]── [\w.\-]+/?\s*(#.*)?$")
DESVIO = re.compile(r"^>\s*\*\*(?:Desvio do molde|Deviation from the template):\*\*", re.M)
TETO_CONVENTIONS = 150     # linhas; regra universal cabe nisso, funcionalidade não


# PRD descreve o produto. Backlog tem estágio e decai; referência é pesquisa, com fonte
# e data; métrica, risco e restrição soltos no fim ficam longe da regra que governam.
# Todos crescem sem dono, e ninguém lê até o fim.
SECAO_FORA_DO_PRD = re.compile(
    r"^##\s+(?:\d+\.\s*)?(Backlog|Refer[êe]ncias|References|M[ée]tricas|Metrics"
    r"|Riscos|Risks|Restri[çc][õo]es|Constraints)\b",
    re.I,
)
# Chave: as três primeiras letras do título, com e sem acento, nos dois idiomas.
_METRICA = ("métricas", "a tabela da funcionalidade que o número governa, ou o evals.yaml quando tem comando")
_RESTRICAO = ("restrições", "a seção que ela restringe; a do agente, no AGENTS.md")
FORA_DO_PRD = {
    "bac": ("backlog", "TODOS.md, que decai"),
    "ref": ("referências", "um estudo (docs/research/ ou a wiki)"),
    "mét": _METRICA,
    "met": _METRICA,
    "ris": ("riscos", "a regra da seção que a mitigação protege; risco sem mitigação vai para o TODOS.md"),
    "res": _RESTRICAO,
    "con": _RESTRICAO,
}
H2 = re.compile(r"^##\s")


def check_subsecoes(linhas: list[str], cercado: set[int], nome: str, ach: Achados) -> None:
    """Toda funcionalidade tem os três atos, todos, na ordem."""
    cabecas = [i for i, ln in enumerate(linhas) if H2.match(ln) and i not in cercado]
    for k, ini in enumerate(cabecas):
        fim = cabecas[k + 1] if k + 1 < len(cabecas) else len(linhas)
        vistos = [
            (pos, i + 1)
            for i in range(ini + 1, fim)
            if i not in cercado and (m := SUB.match(linhas[i]))
            and (pos := SUB_IDIOMA.get(m.group(1).lower())) is not None
        ]
        if not any(pos == 0 for pos, _ in vistos):
            continue
        titulo = NUMERACAO.sub("", linhas[ini][3:].strip())
        presentes = {pos for pos, _ in vistos}
        if faltam := [SUBSECOES[p] for p in range(len(SUBSECOES)) if p not in presentes]:
            ach.add(nome, ini + 1, f"funcionalidade sem {' nem '.join(faltam)} ({titulo[:44]!r}); ela se descreve em {', '.join(SUBSECOES)}, os três")
        maior = -1
        for pos, linha in vistos:
            if pos < maior:
                ach.add(nome, linha, f"{SUBSECOES[pos]} depois de {SUBSECOES[maior]} ({titulo[:44]!r}); a ordem é {', '.join(SUBSECOES)}, e ela é o raciocínio")
            maior = max(maior, pos)


def check_molde(path: Path, ach: Achados) -> None:
    # Subdoc de domínio carrega funcionalidade como o PRD de raiz, e a forma dela
    # é a mesma. O resto do molde (mapa, árvore, teto) é do doc de raiz.
    subdoc = SUBDOCS in path.as_posix()
    if not subdoc and (path.name not in DOCS_RAIZ or path.name == "README.md"):
        return
    if any(path.as_posix().endswith(m) for m in MIGRANDO):
        return
    texto = path.read_text(encoding="utf-8", errors="replace")
    if DESVIO.search("\n".join(texto.splitlines()[:15])):
        return
    nome = str(path)
    linhas = texto.splitlines()
    cercado = fenced_ranges(linhas)

    if subdoc:
        check_subsecoes(linhas, cercado, nome, ach)
        return

    em_tabela = entradas = 0
    for n, ln in enumerate(linhas, 1):
        # O AGENTS roteia ("quando X, leia Y") e por isso linka os docs; roteamento
        # é papel dele, e o próprio _template acusava. Só o mapa ("doc, para quem") é
        # do README.
        if path.name != "AGENTS.md" and ln.lstrip().startswith("|") and LINK_DOC_RAIZ.search(ln):
            em_tabela += 1
            if em_tabela == 3:
                ach.add(nome, n, "mapa de docs fora do README; o mapa mora num lugar só")
        elif not ln.lstrip().startswith("|"):
            em_tabela = 0
        if ARVORE.search(ln):
            entradas += 1
            if entradas == 2:
                ach.add(nome, n, "árvore de pastas fora do README; o mapa mora num lugar só")

    if path.name == "PRD.md":
        check_subsecoes(linhas, cercado, nome, ach)
        for n, ln in enumerate(linhas, 1):
            if n - 1 in cercado or not (m := SECAO_FORA_DO_PRD.match(ln)):
                continue
            tipo, destino = FORA_DO_PRD[m.group(1).lower()[:3]]
            ach.add(nome, n, f"seção de {tipo} no PRD; o lugar é {destino}")
        # A visão geral abre com o fluxo desenhado, que liga as camadas; em prosa, cada
        # leitor monta um diagrama diferente na cabeça.
        secoes = [i for i, ln in enumerate(linhas) if H2.match(ln) and i not in cercado]
        if secoes:
            ini = secoes[0]
            fim = secoes[1] if len(secoes) > 1 else len(linhas)
            if not any(i in cercado for i in range(ini, fim)):
                ach.add(nome, ini + 1, "visão geral sem diagrama; o fluxo que liga as camadas abre o PRD, em ASCII")

    if path.name == "CONVENTIONS.md" and len(linhas) > TETO_CONVENTIONS:
        ach.add(nome, len(linhas), f"CONVENTIONS com {len(linhas)} linhas, acima do teto de {TETO_CONVENTIONS}; o que é de uma funcionalidade vai para a seção dela no PRD")


# ---------------------------------------------------------------------- decay

HANDOFF_DIR = "_tmp"
HANDOFF_VIDA = 14          # dias, contados da data no nome quando não há Morre em
TETO_FEEDBACK = 10         # o mesmo teto que o AGENTS.md já manda
TETO_INBOX = 30
TETO_PROXIMOS = 20
IDADE_INBOX = 30           # dias parado antes de a captura virar lixo
IDADE_POOL = 90

# Os dois degraus do backlog, pelo rótulo de cada idioma. O nome canônico é a
# chave interna; o que o arquivo escreve é só o rótulo.
ORDENADO, POOL = "ordenado", "pool"
SECOES_TODOS = {
    "próximos": ORDENADO, "proximos": ORDENADO, "next": ORDENADO,
    "pool": POOL,
}
ROTULOS = "Próximos (ou Next) e Pool"
ISO = re.compile(r"(\d{4}-\d{2}-\d{2})")
ITEM = re.compile(r"^[-*]\s+(.*\S)\s*$")
MORRE_EM = re.compile(r"^\s*(?:[-*]\s*)?\*{0,2}(?:Morre em|Dies on|Expires):?\*{0,2}:?\s*(\S+)", re.I | re.M)


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
            if not nome or nome.lower() in SECOES_TODOS:
                continue
            ach.add("TODOS.md", linha_h, f"seção {nome!r} fora do padrão; o backlog tem {ROTULOS}, e mais eixo é mais paralisia")

        def degrau(qual: str) -> list[tuple[int, str]]:
            return [x for n, (_, lista) in secoes.items()
                    if SECOES_TODOS.get(n.lower()) == qual for x in lista]

        proximos = degrau(ORDENADO)
        if len(proximos) > TETO_PROXIMOS:
            ach.add("TODOS.md", 0, f"Próximos com {len(proximos)} itens, teto {TETO_PROXIMOS}; a posição é a prioridade, e lista longa não tem posição")

        for linha, texto in degrau(POOL):
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
               "com", "por", "se", "ao", "aos",
               "the", "an", "of", "to", "in", "on", "for", "and", "or", "with",
               "by", "at", "from", "is", "it", "that", "this"}
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
    g.add_argument("--molde", type=Path, nargs="+", help="doc de raiz a checar contra o molde")
    g.add_argument("--estagio", type=Path, help="raiz do projeto (checa o invariante de estágio único)")
    args = ap.parse_args()

    alvos = args.estado or args.molde or [args.grafo or args.ciclo or args.decay or args.estagio]
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
    elif args.molde:
        for alvo in args.molde:
            check_molde(alvo, ach)
    else:
        for alvo in args.estado:
            check_estado(alvo, ach)
    return ach.report()


if __name__ == "__main__":
    sys.exit(main())
