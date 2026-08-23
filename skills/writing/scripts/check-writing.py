#!/usr/bin/env python3
"""Linter de escrita: pega o que é mecânico, ignora trecho de código.

Uso: python3 skills/writing/scripts/check-writing.py ARQUIVO [ARQUIVO...]
     python3 skills/writing/scripts/check-writing.py --list-rules

Saída: uma linha por achado, `arquivo:linha: regra: trecho`. rc=1 se achou algo.
O julgamento fica em references/padroes.md; aqui só entra regra sem falso positivo.
"""
import re
import sys

HTML_COMMENT = re.compile(r"<!--.*?-->", re.S)
FENCE = re.compile(r"^\s*(```|~~~)")
INLINE_CODE = re.compile(r"`[^`\n]*`")
LINK_TARGET = re.compile(r"\]\([^)\s]+\)")
BARE_URL = re.compile(r"https?://\S+")
HEADING = re.compile(r"^\s{0,3}#{1,6}\s")
EMOJI = re.compile(
    "[" "\U0001f300-\U0001faff" "\U00002700-\U000027bf" "\U00002600-\U000026ff" "]"
)

RULES = [
    ("travessao", re.compile(r"—"), "travessão: vira vírgula, ponto ou corte"),
    ("meia-risca", re.compile(r"(?<=\s)–(?=\s)"), "meia-risca fazendo papel de travessão"),
    ("aspa-curva", re.compile(r"[“”‘’]"), "aspa curva: usa reta"),
    (
        "filler",
        re.compile(
            r"\b(a fim de|devido ao fato de que|é importante notar que|"
            r"vale ressaltar|cabe destacar|em suma|no cenário atual|"
            r"por fim,? mas não menos importante)\b",
            re.I,
        ),
        "frase de enchimento: corta ou troca pela palavra comum",
    ),
    (
        "vocabulario",
        re.compile(
            r"\b(crucial|primordial|robust[oa]s?|aprofundar|tapeçaria|sinergia|"
            r"utiliza(r|ndo|mos|m)?|alavanca(r|ndo)|viabiliza(r|ndo)|"
            r"ressalta(r|ndo)|sublinha(r|ndo))\b",
            re.I,
        ),
        "vocabulário de IA: usa a palavra comum",
    ),
    (
        "nao-apenas",
        re.compile(r"\bnão (apenas|só)\b[^.\n]{0,80}\bmas\b", re.I),
        '"não apenas X, mas Y": afirma direto',
    ),
    (
        "chatbot",
        re.compile(
            r"(espero que ajude|fico à disposição|ótima pergunta|"
            r"absolutamente cert[oa]|^\s*(claro|com certeza)!)",
            re.I | re.M,
        ),
        "frase de chatbot: remove",
    ),
    (
        "hedging",
        re.compile(r"\b(poderia|pode)\s+(potencialmente|talvez|eventualmente)\b", re.I),
        "hedging empilhado: escolhe um",
    ),
]


def strip_code(lines):
    """Zera trecho de código preservando numeração: fence, inline e URL."""
    out, in_fence = [], False
    for line in lines:
        if FENCE.match(line):
            in_fence = not in_fence
            out.append("")
            continue
        if in_fence:
            out.append("")
            continue
        clean = INLINE_CODE.sub(lambda m: " " * len(m.group()), line)
        clean = LINK_TARGET.sub(lambda m: " " * len(m.group()), clean)
        clean = BARE_URL.sub(lambda m: " " * len(m.group()), clean)
        out.append(clean)
    return out


def check(path):
    try:
        text = open(path, encoding="utf-8").read()
        text = HTML_COMMENT.sub(lambda m: re.sub(r"[^\n]", " ", m.group()), text)
        raw = text.splitlines()
    except OSError as e:
        print(f"{path}: não deu pra ler: {e}", file=sys.stderr)
        return [("0", "io", str(e))]

    lines = strip_code(raw)
    hits = []
    for n, line in enumerate(lines, 1):
        for name, pattern, msg in RULES:
            for m in pattern.finditer(line):
                hits.append((n, name, f"{msg} [{m.group().strip()}]"))
        if HEADING.match(line) and EMOJI.search(line):
            hits.append((n, "emoji-titulo", "emoji decorativo em título"))

    words = sum(len(line.split()) for line in lines)
    bangs = sum(line.count("!") for line in lines)
    teto = max(1, words // 1000)
    if bangs > teto:
        hits.append((0, "exclamacao", f"{bangs} exclamações em {words} palavras, teto {teto}"))
    return hits


def main(argv):
    if "--list-rules" in argv:
        for name, _, msg in RULES:
            print(f"{name}: {msg}")
        print("emoji-titulo: emoji decorativo em título")
        print("exclamacao: máx 1 a cada 1000 palavras")
        return 0
    paths = [a for a in argv if not a.startswith("-")]
    if not paths:
        print(__doc__.strip(), file=sys.stderr)
        return 2
    total = 0
    for path in paths:
        for n, name, msg in check(path):
            print(f"{path}:{n}: {name}: {msg}")
            total += 1
    if total:
        print(f"\n{total} achado(s). Doutrina: skills/writing/SKILL.md", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
