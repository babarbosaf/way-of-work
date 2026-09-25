#!/usr/bin/env bash
# Suíte da skill test-and-debug. Cobre duas coisas: a forma da skill, e a fiação
# dela no fluxo de execução.
#
# A fiação é o que mais importa aqui. A versão anterior desta skill foi cortada
# por 4 usos em meses, e a causa medida foi que nenhum passo de execução a
# chamava pelo nome: ela existia só numa linha de tabela de roteamento. Teste que
# cobre só a forma deixaria esse bug voltar em silêncio.
#
# Uso: bash tests/test-and-debug.test.sh
set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$HERE/.."
SKILL="$ROOT/skills/test-and-debug"

PASS=0; FAIL=0
ok()   { PASS=$((PASS+1)); echo "  ✓ $1"; }
fail() { FAIL=$((FAIL+1)); echo "  ✗ $1"; }

# cita <arquivo> <agulha> <nome do caso>
cita() {
  if grep -qF -- "$2" "$1" 2>/dev/null; then ok "$3"; else fail "$3 (não achou: $2)"; fi
}

echo "== forma da skill =="

if python3 "$ROOT/scripts/check-skill.py" "$SKILL" >/dev/null 2>&1; then
  ok "check-skill.py limpo"
else
  fail "check-skill.py limpo"
  python3 "$ROOT/scripts/check-skill.py" "$SKILL" 2>&1 | sed 's/^/      /'
fi

for f in "$SKILL"/SKILL.md "$SKILL"/references/*.md; do
  if python3 "$ROOT/skills/writing/scripts/check-writing.py" "$f" >/dev/null 2>&1; then
    ok "escrita limpa: ${f#$ROOT/}"
  else
    fail "escrita limpa: ${f#$ROOT/}"
  fi
done

CORPO=$(sed -n '/^---$/,/^---$/!p' "$SKILL/SKILL.md" | wc -l)
if [[ "$CORPO" -le 400 ]]; then ok "corpo em $CORPO linhas, abaixo do aviso de 400"
else fail "corpo em $CORPO linhas, o linter avisa acima de 400"; fi

echo "== a skill é autoinvocável =="

# A anterior já era autoinvocável e mesmo assim rendeu 4 usos. Manter o campo
# fora é necessário, não suficiente: o que resolve é a fiação, testada abaixo.
if grep -q '^disable-model-invocation:' "$SKILL/SKILL.md"; then
  fail "sem disable-model-invocation (a skill precisa disparar sozinha)"
else
  ok "sem disable-model-invocation"
fi

echo "== a description carrega os gatilhos de fala do usuário =="

for gatilho in "parou de funcionar" "retorna X quando devia Y" "debugar" "investigar" "em lote"; do
  cita "$SKILL/SKILL.md" "$gatilho" "gatilho na description: $gatilho"
done

echo "== navegação: toda referência é citada pelo SKILL.md =="

for ref in "$SKILL"/references/*.md; do
  nome=$(basename "$ref")
  cita "$SKILL/SKILL.md" "references/$nome" "SKILL.md cita $nome"
done

echo "== o gate de nascimento está no corpo, não só na referência =="

cita "$SKILL/SKILL.md" "Quebre a linha que ele testa" "pergunta 1 (quebra e fica vermelho)"
cita "$SKILL/SKILL.md" "calculado com o código do" "pergunta 2 (esperado vem de fora)"
cita "$SKILL/SKILL.md" "stub que devolve o que o teste queria" "pergunta 3 (dirige o produto de verdade)"
cita "$SKILL/SKILL.md" "um de cada vez" "deleção de teste nunca em lote"

echo "== regra de parada do debug =="

cita "$SKILL/references/causa-raiz.md" "removê-la deixa o teste verde" "regra de parada da causa raiz"
cita "$SKILL/SKILL.md" "30 segundos" "loop de sinal antes da primeira hipótese"

echo "== fiação: quem chama a skill pelo nome =="

cita "$ROOT/AGENTS.md"                                          "test-and-debug" "AGENTS.md roteia pra skill"
cita "$ROOT/skills/execute/SKILL.md"                            "test-and-debug" "execute chama no build do ticket"
cita "$ROOT/skills/delegate/SKILL.md"                           "test-and-debug" "delegate leva no prompt do worker"
cita "$ROOT/skills/git-workflow-and-versioning/SKILL.md"        "test-and-debug" "git-workflow aponta no gate de ship"
cita "$ROOT/skills/kickoff-project/references/anatomia-agents.md" "test-and-debug" "projeto novo nasce sabendo da skill"

echo "== fiação: o gate de ship cobra evidência, não repete a regra =="

# O checklist de ship duplicava as regras de teste palavra por palavra. Regra
# repetida em três lugares é regra que ninguém abre.
if grep -q "RED antes do código" "$ROOT/skills/git-workflow-and-versioning/SKILL.md"; then
  fail "git-workflow não repete o ciclo RED/GREEN"
else
  ok "git-workflow não repete o ciclo RED/GREEN"
fi

echo "== fiação: delegate separa RED de GREEN =="

cita "$ROOT/skills/delegate/SKILL.md" "RED e GREEN em commits separados" "worker commita RED e GREEN separados"

echo
echo "== $PASS passed, $FAIL failed =="
[[ $FAIL -eq 0 ]]
