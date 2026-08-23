#!/usr/bin/env bash
# Suíte do check-writing.py. Testa o linter, não o texto do repo.
# Uso: bash tests/writing.test.sh
set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$HERE/.."
LINT="$ROOT/skills/writing/scripts/check-writing.py"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

PASS=0; FAIL=0
ok()   { PASS=$((PASS+1)); echo "  ✓ $1"; }
fail() { FAIL=$((FAIL+1)); echo "  ✗ $1"; }

# roda o linter num arquivo com CONTEUDO e devolve "rc|saída"
run_on() {
  printf '%s\n' "$1" > "$TMP/caso.md"
  local out rc
  out=$(python3 "$LINT" "$TMP/caso.md" 2>/dev/null); rc=$?
  printf '%s|%s' "$rc" "$out"
}

assert_pega() {
  local nome="$1" conteudo="$2" regra="$3" res
  res=$(run_on "$conteudo")
  if [[ "${res%%|*}" == "1" && "$res" == *"$regra"* ]]; then ok "$nome"
  else fail "$nome (rc/saída: $res)"; fi
}

assert_ignora() {
  local nome="$1" conteudo="$2" res
  res=$(run_on "$conteudo")
  if [[ "${res%%|*}" == "0" ]]; then ok "$nome"
  else fail "$nome (deveria passar, veio: $res)"; fi
}

echo "== o linter pega =="
assert_pega "travessão em prosa"        'Texto com travessão — e continua.'        'travessao'
assert_pega "aspa curva"               'Ele disse “oi” pra todos.'                'aspa-curva'
assert_pega "filler"                   'Rodou o script a fim de validar o gate.'  'filler'
assert_pega "vocabulário de IA"        'O gate é crucial pro fluxo.'              'vocabulario'
assert_pega "utilizar"                 'Vamos utilizar o hook novo.'              'vocabulario'
assert_pega "não apenas X mas Y"       'Não apenas valida, mas também bloqueia.'  'nao-apenas'
assert_pega "frase de chatbot"         'Espero que ajude!'                        'chatbot'
assert_pega "hedging empilhado"        'Isso pode potencialmente quebrar.'        'hedging'
assert_pega "emoji em título"          '# Título 🚀'                              'emoji-titulo'
assert_pega "meia-risca de conector"   'Texto com meia risca – e segue.'          'meia-risca'

echo "== o linter ignora código =="
assert_ignora "travessão em bloco cercado"  '```
exemplo ruim — com travessão
```'
assert_ignora "travessão em código inline"  'O padrão proíbe `a — b` no meio da frase.'
assert_ignora "termo banido em inline"      'O catálogo bane `crucial` e `utilizar`.'
assert_ignora "URL com termo banido"        'Fonte: https://exemplo.com/utilizar-crucial'
assert_ignora "alvo de link markdown"       'Ver [doutrina](docs/utilizar-crucial.md).'
assert_ignora "intervalo entre inline code" 'Os títulos `h1`–`h4` recebem o mesmo tracking.'
assert_ignora "texto limpo"                 'O hook valida a query antes do deploy.'
assert_ignora "comentário HTML"             '<!-- apague se rigor < governança -->
Texto de verdade aqui.'
assert_ignora "comentário HTML multilinha"  '<!--
exemplo ruim — com travessão
-->
Texto de verdade aqui.'

echo "== linha e regra saem na saída =="
printf 'linha limpa\ntexto com travessão — aqui\n' > "$TMP/n.md"
if python3 "$LINT" "$TMP/n.md" 2>/dev/null | grep -q ':2: travessao:'; then
  ok "aponta a linha certa"
else
  fail "aponta a linha certa"
fi

echo "== densidade de exclamação =="
assert_ignora "uma exclamação em texto curto" 'Isso quebra em produção!'
LONGO=$(printf 'palavra %.0s' $(seq 1 60)); LONGO="$LONGO! $LONGO! $LONGO!"
assert_pega "três exclamações em texto curto" "$LONGO" 'exclamacao'

echo "== contrato de saída =="
if python3 "$LINT" --list-rules >/dev/null 2>&1; then ok "--list-rules rc=0"; else fail "--list-rules rc=0"; fi
python3 "$LINT" >/dev/null 2>&1; [[ $? -eq 2 ]] && ok "sem argumento rc=2" || fail "sem argumento rc=2"

echo "== a própria skill passa =="
for f in "$ROOT"/skills/writing/SKILL.md "$ROOT"/skills/writing/references/*.md "$ROOT"/skills/writing/fixtures/*.md; do
  if python3 "$LINT" "$f" >/dev/null 2>&1; then ok "limpo: ${f#$ROOT/}"; else fail "limpo: ${f#$ROOT/}"; fi
done

echo
echo "== $PASS passed, $FAIL failed =="
[[ $FAIL -eq 0 ]]
