#!/usr/bin/env bash
# Suíte do peer-review.sh (Adversarial Evaluator). O dispatch real acontece via
# delegate.sh, então a costura do teste é um delegate falso no HOME falso: nenhum
# CLI de modelo é invocado e nada sai pra rede. Uso: bash tests/peer-review.test.sh
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PR="$HERE/../scripts/peer-review.sh"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

PASS=0; FAIL=0
ok()   { PASS=$((PASS+1)); echo "  ✓ $1"; }
fail() { FAIL=$((FAIL+1)); echo "  ✗ $1"; }

FAKE_HOME="$TMP/home"
GATE="$FAKE_HOME/.claude/gate"
mkdir -p "$FAKE_HOME/.claude/scripts" "$GATE"
LOG="$GATE/usage.log"
ARGS_LOG="$TMP/delegate-args.log"

# delegate falso: grava os args, emite a linha estável `worker: <backend>` no
# stderr quando MOCK_OK=1, e falha como cascata esgotada quando não.
cat > "$FAKE_HOME/.claude/scripts/delegate.sh" <<'MOCK'
#!/usr/bin/env bash
echo "$*" >> "$ARGS_LOG"
cat >/dev/null
if [[ "${MOCK_OK:-1}" == "1" ]]; then
  echo "worker: ${MOCK_WORKER:-codex}" >&2
  echo "CRITICAL: achado de mentira"
  exit 0
fi
echo "delegate: cascata esgotada" >&2
exit 2
MOCK
chmod +x "$FAKE_HOME/.claude/scripts/delegate.sh"

RC=0; OUT=""; ERR=""
run_pr() {
  local fo fe
  fo=$(mktemp); fe=$(mktemp)
  ( cd "$TMP" && env HOME="$FAKE_HOME" ARGS_LOG="$ARGS_LOG" "$@" bash "$PR" ${PR_ARGS[@]+"${PR_ARGS[@]}"} ) >"$fo" 2>"$fe"
  RC=$?
  OUT=$(cat "$fo"); ERR=$(cat "$fe")
  rm -f "$fo" "$fe"
}
assert_rc()  { [[ "$RC" == "$2" ]] && ok "$1" || fail "$1 (rc=$RC; err=$ERR)"; }
assert_tem() { [[ "$OUT$ERR" == *"$2"* ]] && ok "$1" || fail "$1 (sem '$2')"; }

SPEC_PEQUENA="$TMP/spec-pequena.md"
printf '# spec\n\n## 1. Contrato\n\nduas linhas e nada mais.\n' > "$SPEC_PEQUENA"
SPEC_GRANDE="$TMP/spec-grande.md"
{ echo "# spec grande"; for i in $(seq 1 8); do echo; echo "## Seção $i"; echo "SEGREDO_DA_SPEC_$i corpo da seção com detalhe."; done; } > "$SPEC_GRANDE"

echo "== validação de argumento =="
PR_ARGS=(); run_pr; assert_rc "sem argumento: rc=1" 1
assert_tem "mostra o uso" "uso:"
PR_ARGS=(banana "$SPEC_GRANDE"); run_pr; assert_rc "modo inválido: rc=1" 1
assert_tem "diz qual modo usar" "modo inválido"

echo "== política de porte =="
PR_ARGS=(spec "$SPEC_PEQUENA"); run_pr
assert_rc "spec pequena: rc=0" 0
assert_tem "diz que pulou" "pulado"
grep -q '"decision":"skipped"' "$LOG" 2>/dev/null \
  && ok "registra skipped no usage.log" || fail "usage.log sem skipped ($(cat "$LOG" 2>/dev/null))"

echo "== caminho feliz =="
PR_ARGS=(spec "$SPEC_GRANDE"); run_pr MOCK_OK=1 MOCK_WORKER=codex
assert_rc "spec grande com reviewer: rc=0" 0
assert_tem "findings vão pro stdout" "CRITICAL"
grep -q 'codex' "$LOG" && ok "usage.log grava qual reviewer respondeu" || fail "usage.log sem o reviewer"
grep -q 'review' "$ARGS_LOG" && ok "delegate recebe --task review" || fail "delegate sem --task review"

echo "== fallback quando a cascata esgota =="
PR_ARGS=(spec "$SPEC_GRANDE"); run_pr MOCK_OK=0
assert_rc "cascata esgotada: rc=2" 2
assert_tem "manda a sessão assumir o gate" "A sessão assume o gate"
grep -q 'unavailable' "$LOG" && ok "registra unavailable" || fail "usage.log sem unavailable"

echo "== --model explícito é repassado =="
: > "$ARGS_LOG"
PR_ARGS=(spec "$SPEC_GRANDE" --model gemini); run_pr MOCK_OK=1 MOCK_WORKER=gemini
grep -q -- '--model gemini' "$ARGS_LOG" && ok "repassa --model pro delegate" || fail "não repassou --model ($(cat "$ARGS_LOG"))"

echo "== privacidade do log =="
# O header do script promete: usage.log é metadado, sem conteúdo de spec ou diff.
if grep -q 'SEGREDO_DA_SPEC' "$LOG"; then
  fail "usage.log vazou conteúdo da spec"
else
  ok "usage.log não carrega conteúdo da spec"
fi
python3 - "$LOG" <<'PY' && ok "usage.log é JSONL válido" || fail "usage.log não é JSONL válido"
import json, sys
for line in open(sys.argv[1]):
    if line.strip():
        json.loads(line)
PY

echo
echo "== $PASS passed, $FAIL failed =="
[[ $FAIL -eq 0 ]]
