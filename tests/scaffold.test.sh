#!/usr/bin/env bash
# Suíte do scaffold que o kickoff copia pra projeto novo.
#
# Um modo de falha por asserção, e todos eles já aconteceram aqui: arquivo que o
# `.gitignore` engole em silêncio, linter que bloqueia no molde, e dotfile que
# passa a valer dentro deste repo em vez de dentro do projeto copiado.
#
# Uso: bash tests/scaffold.test.sh
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$HERE/.."
cd "$ROOT" || exit 2
S="skills/kickoff-project/assets/scaffold"

PASS=0; FAIL=0
ok()   { PASS=$((PASS+1)); echo "  ✓ $1"; }
fail() { FAIL=$((FAIL+1)); echo "  ✗ $1"; }

echo "== nenhum arquivo do scaffold some do git =="

# O `.gitignore` deste repo ignora `_tmp/` e `specs/` sem âncora, então eles
# casam em qualquer profundidade. Sem a exceção, 6 dos arquivos existiam no
# disco, não apareciam no `git status`, e o clone nascia sem eles.
no_disco=$(find "$S" -type f | wc -l)
no_git=$(git ls-files "$S" | wc -l)
if [[ "$no_disco" -eq "$no_git" && "$no_disco" -gt 0 ]]; then
  ok "$no_git de $no_disco arquivos versionados"
else
  fail "$no_git versionados de $no_disco no disco"
  find "$S" -type f | git check-ignore --stdin 2>/dev/null | sed 's/^/      engolido: /'
fi

echo "== os dotfiles sobem sem ponto =="

# Com ponto, um `.gitignore` commitado aqui passa a valer para este subdiretório
# do way-of-work, e um `.gitattributes` muda o fim de linha dele.
for f in gitignore gitattributes; do
  if [[ -f "$S/$f" && ! -f "$S/.$f" ]]; then ok "$f sem ponto"; else fail "$f sem ponto"; fi
done

echo "== o kickoff sabe copiar e renomear =="

SK="skills/kickoff-project/SKILL.md"
for agulha in "assets/scaffold/" "gitignore\` vira \`.gitignore"; do
  if grep -qF -- "$agulha" "$SK"; then ok "SKILL.md diz: $agulha"; else fail "SKILL.md diz: $agulha"; fi
done

echo "== o que o scaffold não traz =="

# Estes nascem da entrevista. Esqueleto vazio deles seria uma terceira cópia de
# um contrato que já tem anatomia e linter, e foi assim que o template anterior
# ficou para trás do padrão sem ninguém notar.
for doc in PRD.md ROUTES.md DESIGN.md CONVENTIONS.md AGENTS.md README.md; do
  if [[ ! -f "$S/$doc" ]]; then ok "sem $doc pronto"; else fail "sem $doc pronto"; fi
done

echo "== o linter aceita molde e continua cobrando referência =="

if python3 scripts/check-skill.py skills/kickoff-project >/dev/null 2>&1; then
  ok "check-skill.py limpo no kickoff-project"
else
  fail "check-skill.py limpo no kickoff-project"
  python3 scripts/check-skill.py skills/kickoff-project 2>&1 | grep -i scaffold | sed 's/^/      /'
fi

TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/molde/assets/sub" "$TMP/molde/references"
cat > "$TMP/molde/SKILL.md" <<'EOF'
---
name: molde
description: Copia um scaffold para um projeto novo. Use quando a suíte precisa de um asset com link relativo.
---

# molde

Copiar `assets/sub/a.md` para a raiz.
EOF
printf 'Veja [o que ainda não existe](../../CONVENTIONS.md).\n' > "$TMP/molde/assets/sub/a.md"
if python3 scripts/check-skill.py "$TMP/molde" >/dev/null 2>&1; then
  ok "asset com link que só resolve depois da cópia não bloqueia"
else
  fail "asset com link que só resolve depois da cópia não bloqueia"
fi

printf 'Veja [morto](nao-existe.md).\n' > "$TMP/molde/references/r.md"
# Captura antes de filtrar: com `pipefail`, o exit 1 do linter derruba o
# pipeline inteiro mesmo quando o `grep` casa, e a asserção mente.
saida=$(python3 scripts/check-skill.py "$TMP/molde" 2>&1)
if grep -q "link morto" <<<"$saida"; then
  ok "link morto em references continua sendo achado"
else
  fail "link morto em references continua sendo achado"
fi

echo
echo "== $PASS passed, $FAIL failed =="
[[ $FAIL -eq 0 ]]
