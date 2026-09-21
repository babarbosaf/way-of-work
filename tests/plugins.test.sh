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

# `rtk` e `brew` também são mockados: o bootstrap delega o rtk no fim, e nenhum
# teste pode tocar o binário real nem o config.toml da máquina.
cat > "$MOCKBIN/rtk" <<'MOCK'
#!/usr/bin/env bash
echo "rtk $*" >> "$RTK_LOG"
case "${1:-}" in
  --version) echo "rtk 99.0.0" ;;
  config) echo "Config: $RTK_MOCK_CONFIG" ;;
esac
exit 0
MOCK
cat > "$MOCKBIN/brew" <<'MOCK'
#!/usr/bin/env bash
echo "brew $*" >> "$RTK_LOG"
exit 0
MOCK
chmod +x "$MOCKBIN/rtk" "$MOCKBIN/brew"
export PATH="$MOCKBIN:$PATH" MOCK_LOG="$TMP/chamadas.log"
export RTK_MOCK_CONFIG="$TMP/rtk-config.toml" RTK_LOG="$TMP/rtk.log"
printf '[hooks]\nexclude_commands = []\n' > "$RTK_MOCK_CONFIG"

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

echo "== --update =="
: > "$MOCK_LOG"
out=$(bash "$BOOT" --manifest="$TMP/base.json" --update)
assert_contains "dry-run do update atualiza a marketplace" "$out" "plugin marketplace update terceiro"
assert_contains "dry-run do update atualiza o plugin" "$out" "plugin update alfa@terceiro"
grep -q "plugin install" <<<"$out" && fail "update não instala" || ok "update não instala"
grep -q "marketplace update oficial" <<<"$out" && fail "builtin não tem marketplace pra atualizar" || ok "builtin fica de fora do marketplace update"
[[ ! -s "$MOCK_LOG" ]] && ok "dry-run do update não invoca o CLI" || fail "dry-run do update invocou o CLI"
: > "$MOCK_LOG"
bash "$BOOT" --manifest="$TMP/base.json" --update --apply >/dev/null; rc=$?
assert_rc "--update --apply: rc=0" "$rc" 0
assert_contains "CLI recebeu o marketplace update" "$(cat "$MOCK_LOG")" "plugin marketplace update terceiro"
assert_contains "CLI recebeu o plugin update" "$(cat "$MOCK_LOG")" "plugin update beta@oficial"

echo "== escopo do plugin =="
cat > "$TMP/escopo.json" <<'JSON'
{
  "marketplaces": { "oficial": { "builtin": true } },
  "plugins": [
    { "name": "alfa", "marketplace": "oficial" },
    { "name": "beta", "marketplace": "oficial", "escopo": "project" }
  ]
}
JSON
out=$(bash "$BOOT" --manifest="$TMP/escopo.json")
assert_contains "escopo declarado vira --scope" "$out" "install beta@oficial --scope project"
grep -q "install alfa@oficial --scope" <<<"$out" && fail "sem escopo não leva flag" || ok "sem escopo declarado continua no default"
out=$(bash "$BOOT" --manifest="$TMP/escopo.json" --update)
grep -q -- "--scope" <<<"$out" && fail "update não tem escopo" || ok "update ignora o escopo"

echo "== bloco mcp =="
cat > "$TMP/mcp.json" <<'JSON'
{
  "marketplaces": { "oficial": { "builtin": true } },
  "plugins": [],
  "mcp": {
    "shadcn": { "command": "npx -y shadcn@latest mcp" },
    "mobbin": { "url": "https://api.mobbin.com/mcp" }
  }
}
JSON
out=$(bash "$BOOT" --manifest="$TMP/mcp.json")
assert_contains "stdio vira mcp add com --" "$out" "mcp add shadcn -s user -- npx -y shadcn@latest mcp"
assert_contains "http vira mcp add --transport http" "$out" "mcp add --transport http mobbin https://api.mobbin.com/mcp -s user"
out=$(bash "$BOOT" --manifest="$TMP/mcp.json" --update)
grep -q "mcp add" <<<"$out" && fail "update não mexe em MCP" || ok "update não mexe em MCP"

echo "== o repo como plugin =="
PLUG="$ROOT/.claude-plugin/plugin.json"
MKT="$ROOT/.claude-plugin/marketplace.json"
if [[ -f "$PLUG" && -f "$MKT" ]]; then
  ok "manifestos de plugin e de marketplace existem"
  jq -e . "$PLUG" >/dev/null 2>&1 && ok "plugin.json é JSON válido" || fail "plugin.json inválido"
  jq -e . "$MKT" >/dev/null 2>&1 && ok "marketplace.json é JSON válido" || fail "marketplace.json inválido"
  nome_p=$(jq -r '.name' "$PLUG")
  nome_m=$(jq -r '.plugins[0].name' "$MKT")
  [[ "$nome_p" == "$nome_m" ]] && ok "o nome bate nos dois manifestos" \
    || fail "nome divergente: $nome_p vs $nome_m"
  dir_skills="$ROOT/$(jq -r '.skills' "$PLUG" | sed 's|^\./||')"
  [[ -d "$dir_skills" ]] && ok "o diretório de skills declarado existe" \
    || fail "skills apontam pra diretório inexistente: $dir_skills"
  # Skill distribuída precisa estar versionada, senão o instalador recebe menos do que o manifesto promete.
  nao_versionada=$(comm -23 \
    <(find "$ROOT/skills" -maxdepth 2 -name SKILL.md | sed "s|$ROOT/||;s|/SKILL.md||" | sort) \
    <(git -C "$ROOT" ls-files 'skills/*/SKILL.md' | sed 's|/SKILL.md||' | sort))
  [[ -z "$nao_versionada" ]] && ok "toda skill com SKILL.md está versionada" \
    || fail "skill fora do git entraria no plugin: $nao_versionada"
else
  fail "manifestos de plugin ausentes: $PLUG"
fi

echo "== delegação pro bootstrap-rtk =="
printf '[hooks]\nexclude_commands = []\n' > "$RTK_MOCK_CONFIG"
: > "$MOCK_LOG"
out=$(bash "$BOOT" --manifest="$TMP/base.json")
assert_contains "dry-run anuncia a etapa do rtk" "$out" "== rtk =="
grep -q "exclude_commands = \[\]" "$RTK_MOCK_CONFIG" && ok "dry-run não escreve no config do rtk" \
  || fail "dry-run mexeu no config do rtk"
: > "$MOCK_LOG"
bash "$BOOT" --manifest="$TMP/base.json" --apply >/dev/null
assert_contains "--apply aplica o manifesto do rtk" "$(cat "$RTK_MOCK_CONFIG")" "git add"
: > "$MOCK_LOG"
: > "$RTK_LOG"
bash "$BOOT" --manifest="$TMP/base.json" --update --apply >/dev/null
assert_contains "--update chega no brew" "$(cat "$RTK_LOG")" "brew upgrade rtk"

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
