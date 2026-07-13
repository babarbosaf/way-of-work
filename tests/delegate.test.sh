#!/usr/bin/env bash
# Suíte do delegate.sh (SPEC-2026-002). Mocks de CLI antepostos ao PATH;
# nenhum worker real é invocado. Uso: bash tests/delegate.test.sh
set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DELEGATE="$HERE/../scripts/delegate.sh"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

PASS=0; FAIL=0
ok()   { PASS=$((PASS+1)); echo "  ✓ $1"; }
fail() { FAIL=$((FAIL+1)); echo "  ✗ $1"; }
assert_eq() { [[ "$2" == "$3" ]] && ok "$1" || fail "$1 (esperado='$3' obtido='$2')"; }
assert_contains() { grep -q "$3" <<<"$2" && ok "$1" || fail "$1 (não contém '$3')"; }

# --- mocks ---
MOCKBIN="$TMP/bin"; mkdir -p "$MOCKBIN"
cat > "$MOCKBIN/codex" <<'EOF'
#!/usr/bin/env bash
case "${MOCK_CODEX:-ok}" in
  ok) cat >/dev/null; echo "codex-resposta:$*"; exit 0 ;;
  ratelimit) echo "429 too many requests: rate limit"; exit 1 ;;
  fail) echo "erro interno"; exit 1 ;;
  absent) exit 127 ;;
esac
EOF
cat > "$MOCKBIN/agy" <<'EOF'
#!/usr/bin/env bash
case "${MOCK_AGY:-ok}" in
  ok) echo "agy-resposta:$*"; exit 0 ;;
  ratelimit) echo "quota exceeded"; exit 1 ;;
  fail) echo "erro interno agy"; exit 1 ;;
  empty) exit 0 ;;
  drainstdin) cat >/dev/null; echo "erro interno agy"; exit 1 ;;
esac
EOF
cat > "$MOCKBIN/claude" <<'EOF2'
#!/usr/bin/env bash
cat >/dev/null
[[ -n "${ANTHROPIC_API_KEY:-}" ]] || { echo "sem api key"; exit 1; }
echo "claude-api-resposta:key=${ANTHROPIC_API_KEY:0:7}"
EOF2
chmod +x "$MOCKBIN"/codex "$MOCKBIN"/agy "$MOCKBIN"/claude
export PATH="$MOCKBIN:$PATH"

# ambiente isolado: gate dir e policy próprios do teste
export DELEGATE_GATE_DIR="$TMP/gate"
export DELEGATE_POLICY="$TMP/policy.json"
export DELEGATE_INBOX="$TMP/inbox.md"
cp "$HERE/../config/model-policy.json" "$DELEGATE_POLICY"

run() { echo "prompt de teste" | bash "$DELEGATE" "$@" 2>"$TMP/err"; }

echo "T: journey one-shot (boilerplate → agy GPT-OSS primeiro na policy)"
out=$(run --task boilerplate -)
assert_eq "exit 0" "$?" "0"
assert_contains "resposta do agy no stdout" "$out" "agy-resposta"
assert_contains "modelo da policy passado ao agy" "$out" "GPT-OSS 120B (Medium)"
grep -q '"pool":"agy:claude_gpt"' "$DELEGATE_GATE_DIR/delegate.log" && ok "pool registrado no log" || fail "pool registrado no log"
[[ -f "$DELEGATE_GATE_DIR/delegate.log" ]] && ok "log JSONL criado" || fail "log JSONL criado"

echo "T: cascata (scan com codex em falha → agy)"
out=$(MOCK_CODEX=fail run --task scan -)
assert_eq "exit 0" "$?" "0"
assert_contains "caiu pro agy" "$out" "agy-resposta"

echo "T: rc=0 com stdout vazio (falha silenciosa) não é sucesso — cascata desce, cooldown por pool"
rm -f "$DELEGATE_GATE_DIR"/cooldown.*
out=$(MOCK_AGY=empty run --task scan -)   # cascata scan: agy[gemini] → agy[claude_gpt] → codex(ok)
assert_eq "exit 0 (codex assumiu depois dos 2 pools vazios)" "$?" "0"
assert_contains "codex respondeu" "$out" "codex-resposta"
[[ -f "$DELEGATE_GATE_DIR/cooldown.agy:gemini" ]] && ok "pool gemini vazio → cooldown armado" || fail "pool gemini vazio → cooldown armado"
[[ -f "$DELEGATE_GATE_DIR/cooldown.agy:claude_gpt" ]] && ok "pool claude_gpt vazio → cooldown armado" || fail "pool claude_gpt vazio → cooldown armado"
rm -f "$DELEGATE_GATE_DIR"/cooldown.*

echo "T: worker que drena stdin (arg mode) não quebra o loop da cascata (regressão real de produção)"
out=$(MOCK_AGY=drainstdin run --task scan -)   # 2 entradas agy (arg mode) antes de codex — cada uma lê+descarta stdin
assert_eq "exit 0 (cascata percorreu as 2 entradas agy até chegar no codex)" "$?" "0"
assert_contains "chegou no codex, não parou na 1a entrada" "$out" "codex-resposta"

echo "T: claude_api — fora da cascata automática; --model explícito mas fora do escopo é pulado"
# fixtura com scope próprio, desacoplada da policy pública (que é genérica)
jq '.backends.claude_api.scope_pattern = "scopetest"' "$DELEGATE_POLICY" > "$TMP/p2" && mv "$TMP/p2" "$DELEGATE_POLICY"
MOCK_CODEX=fail MOCK_AGY=fail run --task second-opinion --model claude_api - >/dev/null; rc=$?
assert_eq "exit 2 fora do escopo" "$rc" "2"
assert_contains "aviso de escopo" "$(cat "$TMP/err")" "restrito a projetos 'scopetest'"

echo "T: claude_api — --model explícito dentro do escopo, com chave, funciona"
mkdir -p "$TMP/proj-scopetest-app" && echo 'DELEGATE_ANTHROPIC_API_KEY=FAKE_TEST_KEY_123' > "$TMP/fake.env"
jq --arg f "$TMP/fake.env" '.backends.claude_api.env_file = $f' "$DELEGATE_POLICY" > "$TMP/p3" && mv "$TMP/p3" "$DELEGATE_POLICY"
out=$(cd "$TMP/proj-scopetest-app" && echo "prompt" | bash "$DELEGATE" --task second-opinion --model claude_api - 2>"$TMP/err")
assert_eq "exit 0 via claude_api" "$?" "0"
assert_contains "worker recebeu a chave" "$out" "claude-api-resposta:key=FAKE_TE"
assert_contains "linha estável de worker" "$(cat "$TMP/err")" "worker: claude_api"

echo "T: claude_api — --model explícito sem chave no env_file é pulado"
: > "$TMP/fake.env"
(cd "$TMP/proj-scopetest-app" && echo "prompt" | bash "$DELEGATE" --task second-opinion --model claude_api - >/dev/null 2>"$TMP/err"); rc=$?
assert_eq "exit 2 sem chave" "$rc" "2"
assert_contains "aviso de chave ausente" "$(cat "$TMP/err")" "sem DELEGATE_ANTHROPIC_API_KEY"
cp "$HERE/../config/model-policy.json" "$DELEGATE_POLICY"

echo "T: claude_api não entra sozinho na cascata automática (second-opinion sem --model)"
MOCK_CODEX=fail MOCK_AGY=fail run --task second-opinion - >/dev/null; rc=$?
assert_eq "exit 2 — cascata grátis esgotada, claude_api não é tentado" "$rc" "2"

echo "T: journey fallback (todos rate-limited → exit 2 + Claude assume)"
MOCK_CODEX=ratelimit MOCK_AGY=ratelimit run --task review - >"$TMP/out2"; rc=$?
assert_eq "exit 2" "$rc" "2"
assert_contains "mensagem de fallback" "$(cat "$TMP/err")" "Claude assume"
[[ -f "$DELEGATE_GATE_DIR/cooldown.codex" ]] && ok "cooldown codex armado" || fail "cooldown codex armado"
[[ -f "$DELEGATE_GATE_DIR/cooldown.agy:gemini" ]] && ok "cooldown agy:gemini armado (por pool, não por backend inteiro)" || fail "cooldown agy:gemini armado"

echo "T: cooldown ativo pula backend sem invocar"
rm -f "$DELEGATE_GATE_DIR/cooldown.agy:gemini"   # só codex fica em cooldown
out=$(run --task review -)   # codex ainda em cooldown do teste anterior
assert_contains "usou agy direto" "$out" "agy-resposta"

rm -f "$DELEGATE_GATE_DIR"/cooldown.*

echo "T: --model força backend específico"
out=$(run --task review --model agy -)
assert_contains "forçou agy" "$out" "agy-resposta"

echo "T: --model forçado fora da cascata → erro claro (não exit 2 mudo)"
run --task review --model gemini - >/dev/null; rc=$?
assert_eq "exit 1" "$rc" "1"
assert_contains "menciona a policy" "$(cat "$TMP/err")" "não está na cascata"

echo "T: --timeout não-numérico → erro de uso"
echo x | bash "$DELEGATE" --task scan --timeout abc - >/dev/null 2>&1; rc=$?
assert_eq "exit 1" "$rc" "1"

echo "T: task desconhecida → erro claro"
run --task inexistente - >/dev/null; rc=$?
assert_eq "exit != 0" "$([[ $rc -ne 0 ]] && echo x)" "x"

echo "T: policy inválida → fallback default RUIDOSO + funciona"
echo '{quebrado' > "$DELEGATE_POLICY"
out=$(run --task review -); rc=$?
assert_eq "exit 0 no fallback" "$rc" "0"
assert_contains "aviso no stderr" "$(cat "$TMP/err")" "policy inválida"
assert_contains "linha no inbox" "$(cat "$DELEGATE_INBOX" 2>/dev/null)" "model-policy.json inválida"
cp "$HERE/../config/model-policy.json" "$DELEGATE_POLICY"

echo "T: kill switch DELEGATE_DISABLED=1 → exit 2"
DELEGATE_DISABLED=1 run --task scan - >/dev/null; rc=$?
assert_eq "exit 2" "$rc" "2"

echo "T: journey worktree (worker edita em branch isolada, main intocada)"
REPO="$TMP/repo"; mkdir -p "$REPO"; git -C "$REPO" init -q -b main
echo base > "$REPO/f.txt"; git -C "$REPO" add -A; git -C "$REPO" commit -qm base
cat > "$MOCKBIN/codex" <<'EOF'
#!/usr/bin/env bash
cat >/dev/null; echo mudanca > worker.txt; echo "codex-worktree-ok"; exit 0
EOF
chmod +x "$MOCKBIN/codex"
out=$(echo "task de teste" | bash "$DELEGATE" --task implement --worktree "$REPO" - 2>"$TMP/err"); rc=$?
assert_eq "exit 0" "$rc" "0"
assert_contains "reporta branch" "$out" "delegate/"
branch=$(sed -n 's/.*branch: \(delegate\/[a-z0-9-]*\).*/\1/p' <<<"$out" | head -1)
[[ -n "$branch" ]] && git -C "$REPO" show "$branch:worker.txt" >/dev/null 2>&1 && ok "edição na branch delegate" || fail "edição na branch delegate"
[[ ! -f "$REPO/worker.txt" ]] && ok "main intocada" || fail "main intocada"

echo "T: worktree com repo sujo avisa mas não bloqueia (worktree é isolada)"
echo dirty > "$REPO/f.txt"
out=$(echo "task de teste" | bash "$DELEGATE" --task implement --worktree "$REPO" - 2>"$TMP/err"); rc=$?
assert_eq "exit 0 mesmo sujo" "$rc" "0"
assert_contains "aviso de sujeira no stderr" "$(cat "$TMP/err")" "alterações não commitadas"
git -C "$REPO" checkout -q -- f.txt

echo "T: journey peer-review consome delegate (contrato 0/2 preservado)"
cat > "$MOCKBIN/codex" <<'EOF'
#!/usr/bin/env bash
case "${MOCK_CODEX:-ok}" in
  ok) cat >/dev/null; echo "Sem bloqueantes."; exit 0 ;;
  ratelimit) echo "429 too many requests: rate limit"; exit 1 ;;
esac
EOF
chmod +x "$MOCKBIN/codex"
SPEC_FIX="$TMP/spec-fixture.md"
printf '## a\n## b\n## c\n## d\n## e\ncorpo\n' > "$SPEC_FIX"
out=$(bash "$HERE/../scripts/peer-review.sh" spec "$SPEC_FIX" 2>"$TMP/err"); rc=$?
assert_eq "peer-review exit 0" "$rc" "0"
assert_contains "findings do worker no stdout" "$out" "Sem bloqueantes"

rm -f "$DELEGATE_GATE_DIR"/cooldown.*
MOCK_CODEX=ratelimit MOCK_AGY=ratelimit bash "$HERE/../scripts/peer-review.sh" spec "$SPEC_FIX" >/dev/null 2>&1; rc=$?
assert_eq "cascata esgotada → peer-review exit 2" "$rc" "2"

echo "T: merge de model-policy.local.json — override project-specific sobre a base"
cp "$HERE/../config/model-policy.json" "$DELEGATE_POLICY"
# base sem override; local injeta scope real → efetiva deve refletir o local
echo '{"backends":{"codex":{"note":"from-local"}},"tasks":{"_probe":[{"backend":"codex"}]}}' > "$TMP/policy.local.json"
eff=$(bash "$HERE/../scripts/model-policy-effective.sh" "$DELEGATE_POLICY")
assert_contains "local mescla chave nova na base" "$eff" "from-local"
assert_contains "deep-merge preserva backends da base" "$eff" '"agy"'
rm -f "$TMP/policy.local.json"
eff2=$(bash "$HERE/../scripts/model-policy-effective.sh" "$DELEGATE_POLICY")
assert_eq "sem local → efetiva idêntica à base" "$eff2" "$(cat "$DELEGATE_POLICY")"

echo ""
echo "== $PASS passed, $FAIL failed =="
[[ $FAIL -eq 0 ]]
