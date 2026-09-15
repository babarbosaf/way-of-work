#!/usr/bin/env bash
# Suíte do check-docs.py. Prova que o lint pega o que promete.
# Uso: bash tests/docs-lint.test.sh
#
# Fixture boa tem que sair limpa; fixture ruim tem que disparar CADA check.
# Gate que passa verde sem testar nada é pior que gate nenhum.

set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$HERE/fixtures/docs" || exit 2

LINT="python3 $HERE/../scripts/check-docs.py"
falhas=0

passou=0
ok()   { printf '  ok    %s\n' "$1"; passou=$((passou + 1)); }
fail() { printf '  FALHA %s\n' "$1"; falhas=$((falhas + 1)); }

esperado_limpo() {
  local desc="$1"; shift
  if out=$($LINT "$@" 2>&1) && [ "$out" = "limpo." ]; then
    ok "$desc"
  else
    fail "$desc — esperava limpo, veio: $out"
  fi
}

esperado_pega() {
  local desc="$1" padrao="$2"; shift 2
  out=$($LINT "$@" 2>&1); rc=$?
  if [ "$rc" -ne 1 ]; then
    fail "$desc — esperava exit 1, veio $rc"
  elif ! grep -qi -- "$padrao" <<<"$out"; then
    fail "$desc — não achou /$padrao/ na saída"
  else
    ok "$desc"
  fi
}

echo "grafo limpo"
esperado_limpo "raiz boa passa" --grafo bom

echo "grafo quebrado, um check por linha"
esperado_pega "link que nao resolve"   "não resolve"          --grafo ruim-grafo
esperado_pega "ancora morta"           "âncora"               --grafo ruim-grafo
esperado_pega "subdoc fora do indice"  "fora do índice"       --grafo ruim-grafo
esperado_pega "subdoc sem saida"       "sem link de saída"    --grafo ruim-grafo
esperado_pega "aresta de mao unica"    "não volta"            --grafo ruim-grafo
esperado_pega "orfao de entrada"       "órfão de entrada"     --grafo ruim-grafo

echo "estado limpo"
esperado_limpo "PRD bom passa" --estado bom/PRD.md

echo "estado sujo, um check por linha"
esperado_pega "data em heading"       "data em heading"     --estado ruim-estado/PRD.md
esperado_pega "heading de historico"  "Histórico"           --estado ruim-estado/PRD.md
esperado_pega "heading de decisoes"   "Decisões"            --estado ruim-estado/PRD.md
esperado_pega "texto riscado"         "riscado"             --estado ruim-estado/PRD.md

echo "uso"
if $LINT --grafo nao-existe >/dev/null 2>&1; then
  fail "raiz inexistente devia dar exit 2"
else
  [ $? -eq 2 ] && ok "raiz inexistente sai 2" || fail "raiz inexistente saiu com código errado"
fi

echo
echo "== $passou passed, $falhas failed =="
[ "$falhas" -eq 0 ]
