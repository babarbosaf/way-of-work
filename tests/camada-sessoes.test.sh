#!/usr/bin/env bash
# Suíte da camada de sessões. Testa a lib e o adaptador, nunca o herdr em si:
# o que precisa de herdr vivo declara o pulo, e o cenário de ponta a ponta do
# ticket 09 é o único que abre aba de verdade.
# Uso: bash tests/camada-sessoes.test.sh
set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$HERE/.."
LIB="$ROOT/skills/delegate/scripts/lib-visivel.sh"
POLICY="$ROOT/config/model-policy.json"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

PASS=0; FAIL=0
ok()   { PASS=$((PASS+1)); echo "  ✓ $1"; }
fail() { FAIL=$((FAIL+1)); echo "  ✗ $1"; }

# policy de teste: dois backends, um elegível e um não, pra não amarrar o
# comportamento da lib ao veredito que a medição real gravou na policy do repo.
fixture_policy() {
  cat > "$TMP/policy.json" <<'JSON'
{
  "backends": {
    "bom":  { "enabled": true },
    "ruim": { "enabled": true }
  },
  "visivel": {
    "backends": {
      "bom":  { "elegivel": true,  "medido_em": "2026-09-22",
                "invoke": "bom --interativo", "porque": "responde e devolve" },
      "ruim": { "elegivel": false, "medido_em": "2026-09-22",
                "porque": "não devolve resposta pelo canal da camada" }
    }
  }
}
JSON
}

echo "== a lib existe e carrega =="
if [[ -f "$LIB" ]]; then ok "lib-visivel.sh existe"; else fail "lib-visivel.sh não existe"; fi
# shellcheck disable=SC1090
source "$LIB" 2>/dev/null || true
if declare -f visivel_configurar >/dev/null; then ok "visivel_configurar exportada"
else fail "visivel_configurar não existe"; fi

fixture_policy
visivel_configurar "$TMP/policy.json" 2>/dev/null

echo "== veredito por worker =="
if visivel_elegivel bom 2>/dev/null; then ok "worker elegível passa"; else fail "worker elegível passa"; fi
if ! visivel_elegivel ruim 2>/dev/null; then ok "worker não elegível reprova"; else fail "worker não elegível reprova"; fi
if ! visivel_elegivel inexistente 2>/dev/null; then ok "worker sem veredito reprova"
else fail "worker sem veredito reprova"; fi

echo "== a recusa nomeia o worker =="
saida=$(visivel_exigir ruim 2>&1); rc=$?
if (( rc != 0 )); then ok "exigir worker não elegível sai diferente de zero"
else fail "exigir worker não elegível sai diferente de zero (rc=$rc)"; fi
if [[ "$saida" == *ruim* ]]; then ok "a mensagem nomeia o worker"
else fail "a mensagem nomeia o worker (veio: $saida)"; fi
if [[ "$saida" == *"não devolve resposta"* ]]; then ok "a mensagem carrega o porquê medido"
else fail "a mensagem carrega o porquê medido (veio: $saida)"; fi
if visivel_exigir bom >/dev/null 2>&1; then ok "exigir worker elegível sai zero"
else fail "exigir worker elegível sai zero"; fi

echo "== a lista é a da policy =="
lista=$(visivel_lista 2>/dev/null)
if [[ "$lista" == "bom" ]]; then ok "a lista traz só o elegível"
else fail "a lista traz só o elegível (veio: '$lista')"; fi
inv=$(visivel_invoke bom 2>/dev/null)
if [[ "$inv" == "bom --interativo" ]]; then ok "o comando interativo vem da policy"
else fail "o comando interativo vem da policy (veio: '$inv')"; fi

echo "== policy do repo: veredito medido, nunca presumido =="
faltando=$(jq -r '
  [ .backends | keys[] ] as $b
  | [ .visivel.backends // {} | keys[] ] as $v
  | ($b - $v) | join(" ")' "$POLICY" 2>/dev/null)
if [[ -z "$faltando" ]]; then ok "todo backend configurado tem veredito"
else fail "backend sem veredito de elegibilidade: $faltando"; fi
semdata=$(jq -r '[ .visivel.backends // {} | to_entries[]
  | select((.value.medido_em // "") == "") | .key ] | join(" ")' "$POLICY" 2>/dev/null)
if [[ -z "$semdata" ]]; then ok "todo veredito carrega a data da medição"
else fail "veredito sem data de medição: $semdata"; fi
semporque=$(jq -r '[ .visivel.backends // {} | to_entries[]
  | select((.value.porque // "") == "") | .key ] | join(" ")' "$POLICY" 2>/dev/null)
if [[ -z "$semporque" ]]; then ok "todo veredito carrega o porquê"
else fail "veredito sem porquê: $semporque"; fi

echo "== a lista mora num lugar só =="
# Qualquer outro script que leia `.visivel.backends` seria uma segunda cópia da
# régua, e cópia de régua diverge.
leitores=$(grep -rl 'visivel\.backends' "$ROOT/skills" "$ROOT/scripts" 2>/dev/null \
  | grep -v 'lib-visivel.sh' | tr '\n' ' ')
if [[ -z "$leitores" ]]; then ok "só a lib lê a lista"
else fail "outro ponto de chamada repete a lista: $leitores"; fi

echo "== modo desligado não mexe na fila padrão =="
# Carregar a lib não pode mexer na cascata, e o mecanismo pelo qual isso
# aconteceria é colisão de nome: a lib redefinindo algo que o delegate já tem.
# Comparar os nomes que cada um define é medição, e não confiança.
nomes_lib=$(bash -c "source '$LIB' 2>/dev/null; declare -F | awk '{print \$3}'" | sort)
nomes_del=$(grep -oE '^[a-z_][a-z0-9_]*\(\)' "$ROOT/skills/delegate/scripts/delegate.sh" \
  | tr -d '()' | sort -u)
colisao=$(comm -12 <(echo "$nomes_lib") <(echo "$nomes_del") | tr '\n' ' ')
if [[ -z "${colisao// /}" ]]; then ok "a lib não redefine função do delegate"
else fail "a lib colide com o delegate em: $colisao"; fi

# E a cascata padrão não pode consultar a lista de elegíveis: filtrar a fila do
# modo padrão pela elegibilidade do modo visível seria mudar quem atende hoje.
if ! grep -n 'visivel_elegivel\|visivel_lista' "$ROOT/skills/delegate/scripts/delegate.sh" \
     | grep -qv 'DELEGATE_VISIVEL'; then ok "a cascata padrão não consulta a lista"
else fail "a cascata padrão consulta a lista de elegíveis"; fi

if [[ -z "${DELEGATE_VISIVEL:-}" ]]; then ok "o modo visível nasce desligado"
else fail "o modo visível nasce ligado (DELEGATE_VISIVEL=${DELEGATE_VISIVEL})"; fi

echo "== a receita de sidebar =="
EXEMPLO="$ROOT/config/herdr.example.toml"
if [[ -f "$EXEMPLO" ]]; then ok "herdr.example.toml está versionado"
else fail "herdr.example.toml não existe"; fi

# O marcador de quem dirige não pode ser literal na config: o parser recusa, e
# medir isso é o que impede alguém reescrever a receita de um jeito que não sobe.
if grep -q 'starts_with' "$EXEMPLO" 2>/dev/null; then ok "a distinção é por regra condicional"
else fail "a receita não traz regra condicional"; fi

# `~` em comando de daemon morre calado, e foi um dia inteiro de barra morta.
if ! grep -qE 'command\s*=\s*"~' "$EXEMPLO" 2>/dev/null; then ok "nenhum comando começa com til"
else fail "comando com til na receita: o daemon não expande"; fi
# O repo é público: o exemplo pede o caminho, e não carrega o da máquina de quem
# escreveu. `tests/agnostico.test.sh` cobra isso no repo inteiro.
if grep -q '<HOME>' "$EXEMPLO" 2>/dev/null; then ok "o caminho é placeholder, não o da máquina"
else fail "a receita não usa placeholder de caminho"; fi

if command -v herdr >/dev/null 2>&1; then
  if HERDR_CONFIG_PATH="$EXEMPLO" herdr config check 2>&1 | grep -q '^config: ok'; then
    ok "o verificador do herdr aceita a receita"
  else
    fail "o verificador do herdr recusa a receita"
  fi
else
  # Pulo declarado, nunca calado: verde sem herdr não pode passar por prova.
  echo "  ~ pulado: herdr não está nesta máquina, a receita não foi verificada"
fi

echo
echo "== $PASS passed, $FAIL failed =="
(( FAIL == 0 ))
