#!/usr/bin/env bash
# Suíte do diagnóstico de perfis. Nunca toca perfil real: tudo acontece numa
# HOME de mentira, e o baseline é um settings.json de fixture.
# Uso: bash tests/perfis.test.sh
set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$HERE/.."
PERFIS="$ROOT/scripts/perfis.sh"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

PASS=0; FAIL=0
ok()   { PASS=$((PASS+1)); echo "  ✓ $1"; }
fail() { FAIL=$((FAIL+1)); echo "  ✗ $1"; }

# Máquina de mentira: um repo com dois hooks ligados e três perfis em estados
# diferentes, que é o que a máquina real mostra.
RAIZ="$TMP/raiz"
REPO="$RAIZ/.claude"
mkdir -p "$REPO/hooks" "$REPO/skills" "$REPO/docs" "$REPO/config" "$REPO/scripts"
touch "$REPO/hooks/guarda_um.py" "$REPO/hooks/guarda_dois.py" "$REPO/hooks/guarda_tres.py"
touch "$REPO/AGENTS.md"
cat > "$REPO/settings.json" <<'JSON'
{ "hooks": { "PreToolUse": [ { "matcher": "Read", "hooks": [
      { "type": "command", "command": "python3 $HOME/.claude/hooks/guarda_um.py" },
      { "type": "command", "command": "python3 $HOME/.claude/hooks/guarda_dois.py" } ] } ] } }
JSON

# perfil completo: links certos e os dois hooks do baseline
COMPLETO="$RAIZ/.claude-completo"
mkdir -p "$COMPLETO"
for d in hooks skills docs config scripts AGENTS.md; do ln -s "$REPO/$d" "$COMPLETO/$d"; done
cp "$REPO/settings.json" "$COMPLETO/settings.json"

# perfil que derivou: falta um hook do baseline
DERIVOU="$RAIZ/.claude-derivou"
mkdir -p "$DERIVOU"
for d in hooks skills docs config scripts AGENTS.md; do ln -s "$REPO/$d" "$DERIVOU/$d"; done
cat > "$DERIVOU/settings.json" <<'JSON'
{ "hooks": { "PreToolUse": [ { "matcher": "Read", "hooks": [
      { "type": "command", "command": "python3 $HOME/.claude/hooks/guarda_um.py" } ] } ] } }
JSON

# perfil cru: existe e não tem link nenhum
CRU="$RAIZ/.claude-cru"
mkdir -p "$CRU"

echo "== o script existe =="
if [[ -x "$PERFIS" ]]; then ok "perfis.sh existe e é executável"
else fail "perfis.sh não existe ou não é executável"; fi

roda() { PERFIS_RAIZ="$RAIZ" PERFIS_REPO="$REPO" bash "$PERFIS" "$@" 2>&1; }

echo "== diagnóstico, que é o padrão =="
saida=$(roda); rc=$?
if (( rc == 0 )); then ok "o diagnóstico sai zero mesmo achando deriva"
else fail "o diagnóstico saiu $rc: $saida"; fi
if grep -q 'claude-completo' <<<"$saida" && grep -q 'claude-derivou' <<<"$saida" \
   && grep -q 'claude-cru' <<<"$saida"; then ok "acha os três perfis da máquina"
else fail "não achou os três perfis (veio: '$saida')"; fi
# O repositório não é perfil de ninguém: ele é a origem, e listá-lo como perfil
# faria o diagnóstico acusar deriva de si mesmo pra sempre.
if ! grep -qE '^[^[:space:]]*/\.claude$' <<<"$saida"; then ok "e não lista o próprio repositório como perfil"
else fail "listou o repositório como se fosse perfil"; fi

echo "== a deriva de hook aparece com nome =="
if grep -q 'guarda_dois' <<<"$saida"; then ok "nomeia o hook que falta no perfil que derivou"
else fail "não nomeou o hook faltante (veio: '$saida')"; fi
# Hook que o baseline não liga não é deriva: perfil pode ligar o que quiser a
# mais, e acusar isso transformaria preferência pessoal em erro.
if ! grep -q 'guarda_tres' <<<"$saida"; then ok "hook fora do baseline não vira achado"
else fail "acusou hook que o baseline nem liga"; fi

echo "== link faltando aparece =="
if grep -qi 'skills' <<<"$saida"; then ok "nomeia o link que falta no perfil cru"
else fail "não nomeou link faltante (veio: '$saida')"; fi

echo "== sem --aplicar, nada muda no disco =="
antes=$(cat "$DERIVOU/settings.json")
roda >/dev/null 2>&1
if [[ "$(cat "$DERIVOU/settings.json")" == "$antes" ]]; then ok "o diagnóstico não escreve no settings de ninguém"
else fail "o diagnóstico alterou o settings.json de um perfil"; fi
if [[ ! -e "$CRU/skills" ]]; then ok "e não cria link nenhum"
else fail "o diagnóstico criou link sem --aplicar"; fi

echo "== --aplicar conserta =="
saida=$(roda --aplicar); rc=$?
if (( rc == 0 )); then ok "--aplicar sai zero"
else fail "--aplicar saiu $rc: $saida"; fi
if [[ -L "$CRU/skills" && -L "$CRU/hooks" ]]; then ok "o perfil cru ganha os links"
else fail "o perfil cru continua sem link"; fi
if jq -e '[.hooks[]?[]?.hooks[]?.command] | any(test("guarda_dois"))' \
     "$DERIVOU/settings.json" >/dev/null 2>&1; then
  ok "o hook que faltava entra no perfil que derivou"
else fail "o hook faltante não foi ligado"; fi
# Preferência pessoal não é deriva, e o conserto não pode levá-la junto.
if jq -e '.hooks' "$COMPLETO/settings.json" >/dev/null 2>&1; then
  ok "o perfil que já estava certo continua válido"
else fail "--aplicar quebrou o settings de um perfil que estava certo"; fi

echo "== rodar de novo não acha mais nada =="
saida=$(roda)
if ! grep -q 'guarda_dois' <<<"$saida"; then ok "a deriva some depois do conserto"
else fail "a deriva continua depois de --aplicar"; fi

echo "== $PASS passed, $FAIL failed =="
[[ $FAIL -eq 0 ]]
