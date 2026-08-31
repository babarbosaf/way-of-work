#!/usr/bin/env python3
"""Lint de skill: régua de autoria do Agent Skills aplicada no diretório.

Checa o que a doutrina oficial trata como discovery e progressive disclosure:
frontmatter que permite escolher a skill, corpo que caiba na leitura, e
referência que o agente consiga ler inteira quando precisar.

    check-skill.py skills/writing
    check-skill.py --todas skills/

Exit 0 limpo, 1 com achado bloqueante, 2 erro de uso.
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

# Teto oficial do corpo do SKILL.md. Acima disso a orientação é quebrar em
# arquivo de referência, porque o corpo entra inteiro no contexto quando a skill
# dispara.
CORPO_MAX = 500
CORPO_AVISO = 400

# Referência acima disso ganha índice no topo: o agente que faz leitura parcial
# (`head -100`) precisa ver o escopo do arquivo antes de decidir ler o resto.
REF_INDICE = 100

NAME_OK = re.compile(r"^[a-z0-9-]{1,64}$")
RESERVADO = ("anthropic", "claude")
PESSOA = re.compile(r"\b(eu |meu |minha |meus |minhas |I can|I will|you can|you should)", re.I)
# Gatilho citado ("vou compactar", "pausar por aqui") é fala do usuário dentro da
# description, não a skill falando em primeira pessoa. Sai antes do teste.
CITACAO = re.compile(r"[\"\u201c\u201d\'][^\"\u201c\u201d\']{0,80}[\"\u201c\u201d\']")
GATILHO = re.compile(r"\b(use|usar|invoc|quando|antes de|dispara)", re.I)
LINK_MD = re.compile(r"\[[^\]]*\]\((?!https?://)([^)#]+?)(?:#[^)]*)?\)")
BACKSLASH = re.compile(r"\]\([^)]*\\[^)]*\)|`[a-z0-9_./-]+\\[a-z0-9_./-]+`", re.I)
# Índice é título mais lista que nomeia as seções do próprio arquivo. Um catálogo
# cuja primeira categoria se chama "Conteúdo" tem o título e uma lista de itens
# que não são seções, e por isso não navega nada.
TITULO_INDICE = re.compile(
    r"^#{1,3}[ \t]*(conte[úu]do|sum[áa]rio|[íi]ndice|contents)[ \t]*$", re.I | re.M
)
ITEM_LISTA = re.compile(r"^[ \t]*(?:[-*+]|\d+\.)[ \t]+(.+?)\s*$")
HEADING = re.compile(r"^#{2,4}[ \t]+(.+?)\s*$", re.M)


def tem_indice(conteudo: str) -> bool:
    """Índice de verdade: título de índice seguido de itens que são seções daqui."""
    m = TITULO_INDICE.search(conteudo[:1200])
    if not m:
        return False
    secoes = {h.strip().strip("*`").lower() for h in HEADING.findall(conteudo)}
    itens: list[str] = []
    for linha in conteudo[m.end() :].split("\n"):
        item = ITEM_LISTA.match(linha)
        if item:
            itens.append(item.group(1).strip().strip("*`").lower())
        elif itens and linha.strip():
            break
    if not itens:
        return False
    casam = sum(1 for i in itens if any(i in s or s in i for s in secoes))
    return casam >= 1 and casam * 2 >= len(itens)


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


def frontmatter(texto: str) -> tuple[dict[str, str], str, int]:
    """Devolve (campos, corpo, linha_inicial_do_corpo)."""
    if not texto.startswith("---\n"):
        return {}, texto, 1
    fim = texto.find("\n---\n", 4)
    if fim == -1:
        return {}, texto, 1
    bruto = texto[4:fim]
    campos: dict[str, str] = {}
    chave = None
    for linha in bruto.split("\n"):
        m = re.match(r"^([a-z-]+):\s*(.*)$", linha)
        if m:
            chave = m.group(1)
            campos[chave] = m.group(2).strip()
        elif chave and linha.startswith((" ", "\t")):
            campos[chave] += " " + linha.strip()
    offset = texto[: fim + 5].count("\n") + 1
    return campos, texto[fim + 5 :], offset


def citada(corpo: str, rel: str, nome: str) -> bool:
    """Citação vale por link, por caminho em backtick ou por menção crua.

    O SKILL.md navega das duas formas: `[x](references/x.md)` e uma tabela com
    `references/x.md` em backtick. As duas contam como navegação."""
    return rel in corpo or nome in corpo


def check_skill(raiz: Path, ach: Achados) -> None:
    rel = raiz.name
    sk = raiz / "SKILL.md"
    if not sk.exists():
        ach.add(f"{rel}/", 0, "sem SKILL.md: o diretório não carrega como skill")
        return

    texto = sk.read_text(encoding="utf-8")
    campos, corpo, offset = frontmatter(texto)
    arq = f"{rel}/SKILL.md"

    if not campos:
        ach.add(arq, 1, "sem frontmatter YAML: name e description são obrigatórios")
    name = campos.get("name", "")
    desc = campos.get("description", "")

    if not name:
        ach.add(arq, 1, "frontmatter sem name")
    else:
        if not NAME_OK.match(name):
            ach.add(arq, 1, f"name inválido ({name}): só minúscula, número e hífen, até 64 chars")
        if any(r in name.lower() for r in RESERVADO):
            ach.add(arq, 1, f"name usa palavra reservada ({name})")
        if name != rel:
            ach.add(arq, 1, f"name ({name}) diferente do diretório ({rel}): quebra o dispatch por comando")

    if not desc:
        ach.add(arq, 1, "frontmatter sem description: sem ela a skill não é escolhida")
    else:
        if len(desc) > 1024:
            ach.add(arq, 1, f"description com {len(desc)} chars, teto de 1024")
        if PESSOA.search(CITACAO.sub("", desc)):
            ach.add(arq, 1, "description em primeira ou segunda pessoa: escreve em terceira")
        if not GATILHO.search(desc):
            ach.add(arq, 1, "description sem gatilho de uso: diz o que faz e quando usar", aviso=True)

    nlinhas = corpo.count("\n")
    if nlinhas > CORPO_MAX:
        ach.add(arq, offset, f"corpo com {nlinhas} linhas, teto de {CORPO_MAX}: quebra em arquivo de referência")
    elif nlinhas > CORPO_AVISO:
        ach.add(arq, offset, f"corpo com {nlinhas} linhas, perto do teto de {CORPO_MAX}", aviso=True)

    if BACKSLASH.search(texto):
        ach.add(arq, 1, "caminho com barra invertida: usa barra normal em qualquer plataforma")

    # Link relativo morto, no SKILL.md e em cada referência.
    md = [sk] + sorted(p for p in raiz.rglob("*.md") if p != sk)
    for p in md:
        prel = f"{rel}/{p.relative_to(raiz)}"
        conteudo = p.read_text(encoding="utf-8")
        corpo_p = frontmatter(conteudo)[1] if p == sk else conteudo
        for m in LINK_MD.finditer(corpo_p):
            alvo = (p.parent / m.group(1).strip()).resolve()
            if not alvo.exists():
                linha = corpo_p[: m.start()].count("\n") + 1
                ach.add(prel, linha, f"link morto: {m.group(1).strip()}")

    for p in md:
        if p == sk:
            continue
        prel = f"{rel}/{p.relative_to(raiz)}"
        conteudo = p.read_text(encoding="utf-8")
        nl = conteudo.count("\n")
        chave = str(p.relative_to(raiz))

        # Referência que aponta pra outra referência: o agente pode ler as duas
        # por partes e ficar com informação pela metade.
        for m in LINK_MD.finditer(conteudo):
            if m.group(1).strip().endswith(".md"):
                linha = conteudo[: m.start()].count("\n") + 1
                ach.add(prel, linha, f"referência aninhada: {m.group(1).strip()} sai daqui e não do SKILL.md")

        # Amostra de artefato (`exemplos/`, `fixtures/`) é molde, e índice
        # enfiado no meio de um PRD de exemplo estraga o molde.
        amostra = chave.startswith(("exemplos/", "fixtures/")) or "/exemplos/" in chave
        if nl > REF_INDICE and not amostra and not tem_indice(conteudo):
            ach.add(prel, 1, f"{nl} linhas sem índice no topo: leitura parcial não vê o escopo", aviso=True)

        meta = p.name == "README.md" or chave.startswith("fixtures/")
        if not meta and not citada(corpo, chave, p.name):
            ach.add(prel, 0, "não é citada pelo SKILL.md: ou entra na navegação, ou sai", aviso=True)


def main() -> int:
    ap = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    ap.add_argument("alvo", type=Path, nargs="+", help="diretório da skill")
    ap.add_argument("--todas", action="store_true", help="trata cada alvo como diretório de skills")
    args = ap.parse_args()

    skills: list[Path] = []
    for alvo in args.alvo:
        if not alvo.exists():
            print(f"não existe: {alvo}", file=sys.stderr)
            return 2
        if args.todas:
            skills += sorted(p for p in alvo.iterdir() if p.is_dir() and not p.name.startswith("_"))
        else:
            skills.append(alvo)

    if not skills:
        print("nenhuma skill no alvo", file=sys.stderr)
        return 2

    ach = Achados()
    for s in skills:
        check_skill(s, ach)
    return ach.report()


if __name__ == "__main__":
    sys.exit(main())
