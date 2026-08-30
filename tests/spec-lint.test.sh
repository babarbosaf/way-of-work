#!/usr/bin/env bash
# Suíte do check-spec.py. Prova que o lint pega o que promete.
# Uso: bash tests/spec-lint.test.sh
#
# Fixture boa tem que sair limpa; fixture ruim tem que disparar CADA check.
# Gate que passa verde sem testar nada é pior que gate nenhum.

set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$HERE/../skills/to-spec" || exit 2

LINT="python3 $HERE/../scripts/check-spec.py"
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

esperado_aviso() {
  local desc="$1" padrao="$2"; shift 2
  out=$($LINT "$@" 2>&1); rc=$?
  if [ "$rc" -ne 0 ]; then
    fail "$desc — aviso não pode travar o gate, veio exit $rc"
  elif ! grep -qi -- "aviso: $padrao" <<<"$out"; then
    fail "$desc — não achou /aviso: $padrao/ na saída"
  else
    ok "$desc"
  fi
}

echo "spec limpa"
esperado_limpo "spec-boa passa" --spec fixtures/spec-boa.md

echo "spec suja, um check por linha"
esperado_pega "coautoria de Claude"        "não é coautor"          --spec fixtures/spec-ruim.md
esperado_pega "status de processo"         "status de processo"     --spec fixtures/spec-ruim.md
esperado_pega "bloco sql"                  "bloco de código (sql)"  --spec fixtures/spec-ruim.md
esperado_pega "bloco python"               "bloco de código (python)" --spec fixtures/spec-ruim.md
esperado_pega "DDL solto"                  "DDL na spec"            --spec fixtures/spec-ruim.md
esperado_pega "caminho de arquivo aparece"  "caminho de arquivo"     --spec fixtures/spec-ruim.md
esperado_pega "criterio vago"              "critério vago"          --spec fixtures/spec-ruim.md
esperado_pega "secao de round"             "seção de processo"      --spec fixtures/spec-ruim.md
esperado_pega "secao obrigatoria ausente"  "seção obrigatória"      --spec fixtures/spec-ruim.md
esperado_pega "arquivo irmao de round"     "arquivo de rodada"      --spec fixtures/spec-ruim.md

echo "severidade: aviso informa, não bloqueia"
esperado_aviso "spec só com caminho sai 0" "caminho de arquivo" --spec fixtures/spec-so-avisos.md

echo "tickets limpos"
esperado_limpo "tickets-bons passam" --tickets fixtures/tickets-bons

echo "tickets sujos, um check por linha"
esperado_pega "tamanho L"           "não foi fatiado"        --tickets fixtures/tickets-ruins
esperado_pega "files ausente"       "ausente: \`files:\`"    --tickets fixtures/tickets-ruins
esperado_pega "sem aceite"          "sem aceite"             --tickets fixtures/tickets-ruins
esperado_pega "verify placeholder"  "placeholder"            --tickets fixtures/tickets-ruins
esperado_pega "pseudo-ID"           "não é ID real"          --tickets fixtures/tickets-ruins
esperado_pega "delega sim"          "não resolve worker"     --tickets fixtures/tickets-ruins
esperado_pega "[P] disputa arquivo" "disputa arquivo"        --tickets fixtures/tickets-ruins

echo "coerência: o exemplo das references passa no próprio lint"
TMP=$(mktemp -d)
python3 - "$TMP" <<'PY'
import re, sys, os
d = sys.argv[1]
os.makedirs(f"{d}/spec"); os.makedirs(f"{d}/tickets")
spec = re.findall(r"```markdown\n(.*?)\n```", open("references/exemplo.md").read(), re.S)
open(f"{d}/spec/spec.md", "w").write(spec[0])
tk = re.findall(r"```markdown\n(.*?)\n```", open("../to-tickets/references/exemplo.md").read(), re.S)
for i, b in enumerate(tk, 1):
    open(f"{d}/tickets/{i:02d}.md", "w").write(b)
PY
esperado_limpo "spec do exemplo"    --spec "$TMP/spec/spec.md"
esperado_limpo "tickets do exemplo" --tickets "$TMP/tickets"
rm -rf "$TMP"

echo "uso"
if $LINT --spec fixtures/nao-existe.md >/dev/null 2>&1; then
  fail "arquivo inexistente devia dar exit 2"
else
  [ $? -eq 2 ] && ok "arquivo inexistente sai 2" || fail "arquivo inexistente saiu com código errado"
fi

echo
echo "== $passou passed, $falhas failed =="
[ "$falhas" -eq 0 ]
