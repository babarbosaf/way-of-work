#!/usr/bin/env bash
# Suíte do bootstrap-plugins.sh. Nenhum `claude plugin` real é invocado: o CLI é
# mockado no PATH. Uso: bash tests/plugins.test.sh
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$HERE/.."
BOOT="$ROOT/scripts/bootstrap-plugins.sh"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

PASS=0; FAIL=0
ok()   { PASS=$((PASS+1)); echo "  ✓ $1"; }
fail() { FAIL=$((FAIL+1)); echo "  ✗ $1"; }
assert_contains() { grep -q -- "$3" <<<"$2" && ok "$1" || fail "$1 (não contém '$3')"; }
assert_rc() { [[ "$2" == "$3" ]] && ok "$1" || fail "$1 (rc=$2, esperado $3)"; }

MOCKBIN="$TMP/bin"; mkdir -p "$MOCKBIN"
cat > "$MOCKBIN/claude" <<'MOCK'
#!/usr/bin/env bash
echo "$*" >> "$MOCK_LOG"
exit "${MOCK_RC:-0}"
MOCK
chmod +x "$MOCKBIN/claude"
export PATH="$MOCKBIN:$PATH" MOCK_LOG="$TMP/chamadas.log"

cat > "$TMP/base.json" <<'JSON'
{
  "marketplaces": {
    "oficial": { "builtin": true },
    "terceiro": { "github": "dono/repo" }
  },
  "plugins": [
    { "name": "alfa", "marketplace": "terceiro" },
    { "name": "beta", "marketplace": "oficial" }
  ]
}
JSON

echo "== dry-run =="
out=$(bash "$BOOT" --manifest="$TMP/base.json"); rc=$?
assert_rc "rc=0" "$rc" 0
assert_contains "avisa que é dry-run" "$out" "dry-run"
assert_contains "marketplace de terceiro entra" "$out" "marketplace add dono/repo"
assert_contains "install do plugin de terceiro" "$out" "install alfa@terceiro"
assert_contains "install do plugin oficial" "$out" "install beta@oficial"
[[ ! -s "$MOCK_LOG" ]] && ok "dry-run não invoca o CLI" || fail "dry-run invocou o CLI"
grep -q "marketplace add oficial" <<<"$out" && fail "builtin não deveria gerar add" || ok "builtin não gera marketplace add"

echo "== overlay local =="
cat > "$TMP/base.local.json" <<'JSON'
{
  "marketplaces": { "conta": { "github": "dono/privado" } },
  "plugins": [ { "name": "gama", "marketplace": "conta" } ]
}
JSON
out=$(bash "$BOOT" --manifest="$TMP/base.json")
assert_contains "anuncia o overlay" "$out" "overlay local aplicado"
assert_contains "marketplace do overlay entra" "$out" "marketplace add dono/privado"
assert_contains "plugin do overlay entra" "$out" "install gama@conta"
# array do local substitui o da base, mesma convenção do model-policy
grep -q "install alfa@terceiro" <<<"$out" && fail "array do local deveria substituir" || ok "array do local substitui o da base"
rm "$TMP/base.local.json"

echo "== manifesto inválido =="
cat > "$TMP/orfao.json" <<'JSON'
{ "marketplaces": { "oficial": { "builtin": true } },
  "plugins": [ { "name": "alfa", "marketplace": "nao-declarada" } ] }
JSON
out=$(bash "$BOOT" --manifest="$TMP/orfao.json" 2>&1); rc=$?
assert_rc "marketplace órfã: rc=1" "$rc" 1
assert_contains "diz qual plugin está órfão" "$out" "alfa@nao-declarada"
printf '{ nao é json' > "$TMP/quebrado.json"
bash "$BOOT" --manifest="$TMP/quebrado.json" >/dev/null 2>&1; assert_rc "JSON inválido: rc=1" "$?" 1
bash "$BOOT" --manifest="$TMP/nao-existe.json" >/dev/null 2>&1; assert_rc "manifesto ausente: rc=1" "$?" 1
bash "$BOOT" --flag-invalida >/dev/null 2>&1; assert_rc "flag desconhecida: rc=1" "$?" 1

echo "== --apply =="
: > "$MOCK_LOG"
out=$(bash "$BOOT" --manifest="$TMP/base.json" --apply); rc=$?
assert_rc "rc=0 com CLI ok" "$rc" 0
assert_contains "CLI recebeu o add" "$(cat "$MOCK_LOG")" "plugin marketplace add dono/repo"
assert_contains "CLI recebeu o install" "$(cat "$MOCK_LOG")" "plugin install alfa@terceiro"
: > "$MOCK_LOG"
out=$(MOCK_RC=1 bash "$BOOT" --manifest="$TMP/base.json" --apply 2>&1)
assert_contains "reporta a contagem de falhas" "$out" "3 com falha"
assert_contains "segue depois da falha" "$out" "Segue."

echo "== manifesto do repo =="
out=$(bash "$BOOT" 2>&1); rc=$?
assert_rc "manifesto versionado é válido e sem órfão" "$rc" 0
if git -C "$ROOT" check-ignore config/plugins.local.json >/dev/null; then
  ok "config/plugins.local.json é gitignored"
else
  fail "config/plugins.local.json NÃO é gitignored"
fi

echo
echo "== $PASS passed, $FAIL failed =="
[[ $FAIL -eq 0 ]]
