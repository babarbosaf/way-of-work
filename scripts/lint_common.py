"""Peças comuns dos linters de doc, spec e ticket.

Relatório e severidade moram aqui porque `check-spec.py` e `check-docs.py`
precisam da mesma saída: `arquivo:linha: mensagem`, achado bloqueia, aviso não.
"""

from __future__ import annotations

import re
import unicodedata


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


_NAO_SLUG = re.compile(r"[^\w\- ]", re.UNICODE)


def slugify(heading: str) -> str:
    """Âncora no formato do GitHub: minúscula, pontuação fora, espaço vira hífen.

    Acento fica (o GitHub preserva), por isso a normalização é NFC e não ASCII.
    """
    texto = unicodedata.normalize("NFC", heading.strip())
    texto = _NAO_SLUG.sub("", texto).strip().lower()
    # Cada espaço vira UM hífen, sem colapsar: o GitHub remove a pontuação e
    # deixa os espaços que sobraram, então "Entidades × modos" dá
    # "entidades--modos". Colapsar aqui inventa âncora morta.
    return re.sub(r"\s", "-", texto)


def headings(texto: str) -> list[tuple[int, str]]:
    """(linha, título) de cada heading markdown fora de bloco de código."""
    linhas = texto.splitlines()
    cercado = fenced_ranges(linhas)
    out = []
    for i, ln in enumerate(linhas):
        if i in cercado:
            continue
        if m := re.match(r"^(#{1,6})\s+(.*\S)\s*$", ln):
            out.append((i + 1, m.group(2)))
    return out
