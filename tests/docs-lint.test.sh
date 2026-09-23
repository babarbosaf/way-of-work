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
esperado_limpo "raiz que nao adota PRD nao e cobrada" --grafo sem-prd

echo "grafo quebrado, um check por linha"
esperado_pega "link que nao resolve"   "não resolve"          --grafo ruim-grafo
esperado_pega "ancora morta"           "âncora"               --grafo ruim-grafo
esperado_pega "subdoc fora do indice"  "fora do índice"       --grafo ruim-grafo
esperado_pega "subdoc sem saida"       "sem link de saída"    --grafo ruim-grafo
esperado_pega "aresta de mao unica"    "não volta"            --grafo ruim-grafo
esperado_pega "orfao de entrada"       "órfão de entrada"     --grafo ruim-grafo
esperado_pega "subdoc sem indice"      "sem PRD.md"           --grafo prd-orfao

echo "molde"
esperado_limpo "README tem mapa e arvore" --molde molde-bom/README.md molde-bom/PRD.md molde-bom/CONVENTIONS.md
esperado_limpo "diagrama de fluxo nao e arvore" --molde falso-positivo-diagrama/PRD.md
esperado_limpo "roteamento do AGENTS nao e mapa" --molde molde-bom/AGENTS.md
esperado_pega "mapa de docs fora do README" "mapa de docs"   --molde molde-ruim/PRD.md
esperado_pega "arvore de pastas fora do README" "árvore"     --molde molde-ruim/CONVENTIONS.md
esperado_pega "CONVENTIONS acima do teto" "teto"             --molde molde-ruim/CONVENTIONS.md
esperado_limpo "desvio declarado cala o molde" --molde molde-desvio/CONVENTIONS.md

echo "estado limpo"
esperado_limpo "PRD bom passa" --estado bom/PRD.md
# O CHANGELOG é o log: cobrar dele que não tenha seção de histórico é cobrar
# que ele não seja o que é. Pego rodando --estado contra o BIP em 2026-09-15.
esperado_limpo "CHANGELOG não é cobrado de não ser log" --estado bom/CHANGELOG.md
# A tag marca a funcionalidade, não a seção: primeira linha quando a seção inteira
# está num estado, item quando mistura. Restrição e visão geral não são funcionalidade.
esperado_limpo "tag no titulo ou no item" --estado tags-bom/PRD.md tags-bom/README.md

echo "estado sujo, um check por linha"
esperado_pega "data em heading"       "data em heading"     --estado ruim-estado/PRD.md
esperado_pega "heading de historico"  "Histórico"           --estado ruim-estado/PRD.md
esperado_pega "heading de decisoes"   "Decisões"            --estado ruim-estado/PRD.md
esperado_pega "texto riscado"         "riscado"             --estado ruim-estado/PRD.md
# Bloco de pontos a definir some da vista e apodrece: o item em aberto vive no
# backlog, onde decai, ou vira "a definir" na célula exata da tabela.
esperado_pega "secao de pontos em aberto" "em aberto"       --estado ruim-estado/PRD.md
# Os exemplos do kickoff passaram limpos com zero tag: o lint não cobrava a regra.
esperado_pega "funcionalidade sem tag" "Jornal"              --estado tags-ruim/PRD.md
# Tag no título muda o slug: toda troca de estado quebraria link pra seção.
esperado_pega "tag no titulo"          "tag no título"       --estado tags-ruim/PRD.md
esperado_pega "README sem tag"         "sem tag"             --estado tags-ruim/README.md
esperado_pega "subdoc de PRD sem tag"  "Resumo"              --estado tags-ruim/docs/prd/jornal.md

echo "exemplos do kickoff"
# O padrão-ouro que o kickoff mostra precisa passar no molde que ele ensina: os
# quatro exemplos passavam limpos com zero tag enquanto a regra não era cobrada.
EX="$HERE/../skills/kickoff-project/references/exemplos"
esperado_limpo "exemplos no estado final com tag" --estado "$EX"/*.md
esperado_limpo "exemplos no molde" --molde "$EX"/*.md
if out=$(python3 "$HERE/../skills/writing/scripts/check-writing.py" "$EX"/*.md 2>&1) && [ -z "$out" ]; then
  ok "exemplos sem slop"
else
  fail "exemplos sem slop — veio: $out"
fi

echo "ciclo de vida limpo"
esperado_limpo "arvore de decisoes boa passa" --ciclo bom

echo "ciclo de vida quebrado, um check por linha"
esperado_pega "decisao sem status"        "sem campo Status"      --ciclo ruim-ciclo
esperado_pega "status morto na arvore"    "fora do archive"       --ciclo ruim-ciclo
esperado_pega "status desconhecido"       "fora do vocabulário"   --ciclo ruim-ciclo
esperado_pega "decisao viva arquivada"    "viva dentro do archive" --ciclo ruim-ciclo
esperado_pega "ponteiro morto de decisao" "não existe arquivo"   --ciclo ruim-ciclo
esperado_pega "cita decisao arquivada"    "arquivada"             --ciclo ruim-ciclo

echo "decaimento limpo"
export DECAY_HOJE=2026-09-15
esperado_limpo "raiz sem lixo vencido passa" --decay decay-bom

echo "decaimento estourado, um check por linha"
esperado_pega "handoff acumulado"      "mais de um handoff"      --decay decay-ruim
esperado_pega "handoff vencido"        "vencido"                 --decay decay-ruim
esperado_pega "teto do FEEDBACK"       "FEEDBACK.md: 11"         --decay decay-ruim
esperado_pega "item de inbox sem data" "sem data"                --decay decay-ruim
esperado_pega "item de inbox podre"    "parado há"               --decay decay-ruim
esperado_pega "teto dos proximos"      "Próximos"                --decay decay-ruim
esperado_pega "secao fora do padrao"   "Onda 3"                  --decay decay-ruim
unset DECAY_HOJE

echo "estagio unico limpo"
esperado_limpo "escada sem degrau duplicado passa" --estagio estagio-bom

echo "estagio unico quebrado, um check por linha"
esperado_pega "degrau fora da escada"   "fora da escada"      --estagio estagio-ruim
esperado_pega "ticket em doc cru"       "cita o ticket"       --estagio estagio-ruim
esperado_pega "item em dois estagios"   "em dois estágios"    --estagio estagio-ruim
esperado_pega "ponteiro pra spec"       "ponteiro pra spec"   --estagio estagio-ruim

echo "uso"
if $LINT --grafo nao-existe >/dev/null 2>&1; then
  fail "raiz inexistente devia dar exit 2"
else
  [ $? -eq 2 ] && ok "raiz inexistente sai 2" || fail "raiz inexistente saiu com código errado"
fi

echo
echo "== $passou passed, $falhas failed =="
[ "$falhas" -eq 0 ]
