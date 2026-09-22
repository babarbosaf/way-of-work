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
# Elegível sem comando é veredito que não abre nada: a lib devolve vazio e quem
# chamou descobre na hora de rodar, não na hora de escolher.
seminvoke=$(jq -r '[ .visivel.backends // {} | to_entries[]
  | select(.value.elegivel == true and (.value.invoke // "") == "") | .key ] | join(" ")' "$POLICY" 2>/dev/null)
if [[ -z "$seminvoke" ]]; then ok "todo elegível carrega o comando que o abre"
else fail "elegível sem comando interativo: $seminvoke"; fi

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
# A medição é onde a consulta mora: toda chamada à lib tem que estar dentro do
# bloco que o modo abre, e nenhuma fora dele.
fora=$(awk '
  /^if \[\[ -n "\$VISIVEL" \]\]; then$/ { dentro=1; next }
  dentro && /^fi$/ { dentro=0; next }
  !dentro && /visivel_/ { print NR": "$0 }
' "$ROOT/skills/delegate/scripts/delegate.sh")
if [[ -z "$fora" ]]; then ok "a cascata padrão não consulta a lista"
else fail "o delegate consulta a lista fora do modo visível: $fora"; fi

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

echo "== o abridor de sessão =="
ABRE="$ROOT/scripts/abre-sessao.sh"
if [[ -x "$ABRE" ]]; then ok "abre-sessao.sh existe e é executável"
else fail "abre-sessao.sh não existe ou não é executável"; fi

# herdr fingido: grava toda chamada numa linha e devolve o JSON que o de verdade
# devolveria. Testar contra o herdr real aqui faria a suíte abrir aba na máquina
# de quem roda os testes, e o ponta-a-ponta é do ticket 09.
fixture_herdr() {
  mkdir -p "$TMP/bin"
  cat > "$TMP/bin/herdr" <<'SH'
#!/usr/bin/env bash
echo "$*" >> "$HERDR_CHAMADAS"
case "$1 $2" in
  "tab create")
    echo '{"result":{"root_pane":{"pane_id":"w1:pZ"},"tab":{"tab_id":"w1:tZ"}}}' ;;
  "pane read")
    cat "$HERDR_TELA" 2>/dev/null ;;
  *) echo '{"result":{"type":"ok"}}' ;;
esac
SH
  chmod +x "$TMP/bin/herdr"
}
fixture_herdr
fixture_policy
export HERDR_CHAMADAS="$TMP/chamadas.txt"
export HERDR_TELA="$TMP/tela.txt"
: > "$HERDR_CHAMADAS"; : > "$HERDR_TELA"

# Worker não elegível não pode nem chegar a criar aba: recusar depois de abrir
# deixa aba órfã na cara do dono, que é o defeito que a camada existe pra evitar.
saida=$(PATH="$TMP/bin:$PATH" DELEGATE_POLICY="$TMP/policy.json" ABRE_PRAZO_TELA_S=1 \
  bash "$ABRE" --nome trabalho-x --backend ruim 2>&1); rc=$?
if (( rc != 0 )); then ok "worker não elegível não abre: rc=$rc"
else fail "worker não elegível abriu assim mesmo"; fi
if grep -q 'ruim' <<<"$saida"; then ok "a recusa nomeia o worker"
else fail "a recusa não nomeia o worker (veio: '$saida')"; fi
if grep -q 'não devolve resposta' <<<"$saida"; then ok "a recusa carrega o motivo medido"
else fail "a recusa não carrega o motivo da policy"; fi
if ! grep -q 'tab create' "$HERDR_CHAMADAS"; then ok "nenhuma aba nasceu na recusa"
else fail "a recusa criou aba antes de recusar"; fi

: > "$HERDR_CHAMADAS"
printf 'Ask anything\n> \n' > "$HERDR_TELA"
pane=$(PATH="$TMP/bin:$PATH" DELEGATE_POLICY="$TMP/policy.json" ABRE_PRAZO_TELA_S=1 \
  bash "$ABRE" --nome revisa-spec-sessoes --backend bom 2>/dev/null); rc=$?
if (( rc == 0 )); then ok "worker elegível abre: rc=0"
else fail "worker elegível não abriu (rc=$rc)"; fi
if [[ "$pane" == "w1:pZ" ]]; then ok "o abridor devolve o endereço do painel"
else fail "o abridor não devolveu o painel (veio: '$pane')"; fi
if grep -q -- '--label revisa-spec-sessoes' "$HERDR_CHAMADAS"; then
  ok "a aba nasce com o nome do trabalho"
else fail "a aba não levou o nome do trabalho"; fi
# Contador de aba é o que a D-07 recusa: nome tem que vir do trabalho.
if ! grep -qE -- '--label [0-9]+$' "$HERDR_CHAMADAS"; then ok "o nome não é um contador"
else fail "a aba nasceu com nome de contador"; fi
if grep -q 'bom --interativo' "$HERDR_CHAMADAS"; then
  ok "o worker sobe pelo comando que a policy declara"
else fail "o comando interativo não veio da policy"; fi
# A API não entra em worker nenhum, e o modo visível não abre exceção.
if grep -q 'env -u ANTHROPIC_API_KEY bom --interativo' "$HERDR_CHAMADAS"; then
  ok "o worker visível sobe sem a chave de API"
else fail "o modo visível não removeu a chave de API"; fi

# O comando da policy é template, e todo marcador dele precisa sair preenchido:
# `codex -c model_reasoning_effort={effort}` subiria com a chave literal, e o
# worker não erraria alto, ia rodar com outro esforço.
: > "$HERDR_CHAMADAS"
cat > "$TMP/policy-tmpl.json" <<'JSON'
{
  "backends": { "bom": { "enabled": true } },
  "visivel": { "backends": { "bom": {
    "elegivel": true, "medido_em": "2026-09-22", "porque": "responde e devolve",
    "invoke": "bom -m {model} -c esforco={effort}" } } }
}
JSON
PATH="$TMP/bin:$PATH" DELEGATE_POLICY="$TMP/policy-tmpl.json" ABRE_PRAZO_TELA_S=1 \
  bash "$ABRE" --nome com-tmpl --backend bom --model m1 --effort alto >/dev/null 2>&1
if grep -q 'pane run' "$HERDR_CHAMADAS" \
   && ! grep -qE '\{model\}|\{effort\}' "$HERDR_CHAMADAS"; then
  ok "nenhum marcador do comando sobra por preencher"
else fail "marcador sobrou ou o worker nem subiu: $(cat "$HERDR_CHAMADAS")"; fi

# Nome de modelo com espaço e parêntese é o caso real do agy, e o comando chega
# ao shell como texto: sem aspas, `(High)` vira sintaxe e a sessão nem sobe.
: > "$HERDR_CHAMADAS"
PATH="$TMP/bin:$PATH" DELEGATE_POLICY="$TMP/policy-tmpl.json" ABRE_PRAZO_TELA_S=1 \
  bash "$ABRE" --nome com-parenteses --backend bom --model 'Gemini 3.1 Pro (High)' \
  --effort alto >/dev/null 2>&1
if grep -qF "'Gemini 3.1 Pro (High)'" "$HERDR_CHAMADAS"; then
  ok "modelo com espaço e parêntese vai citado pro shell"
else fail "modelo com parêntese foi solto pro shell: $(cat "$HERDR_CHAMADAS")"; fi

# Tecla no escuro é o que quebra: no claude o item pré-selecionado sai do
# programa, no codex roda npm install. Sem o padrão na tela, nenhuma tecla sai.
if ! grep -q 'send-keys' "$HERDR_CHAMADAS"; then
  ok "sem tela de abertura na tela, nenhuma tecla é mandada"
else fail "o abridor mandou tecla sem o padrão casar"; fi

: > "$HERDR_CHAMADAS"
cat > "$TMP/policy-tela.json" <<'JSON'
{
  "backends": { "bom": { "enabled": true } },
  "visivel": { "backends": { "bom": {
    "elegivel": true, "medido_em": "2026-09-22",
    "invoke": "bom --interativo", "porque": "responde e devolve",
    "telas_de_abertura": [
      { "padrao": "confia nesta pasta", "teclas": ["down", "enter"],
        "porque": "o pré-selecionado sai do programa" }
    ] } } }
}
JSON
printf 'Voce confia nesta pasta?\n  Nao, sair\n  Sim\n' > "$HERDR_TELA"
PATH="$TMP/bin:$PATH" DELEGATE_POLICY="$TMP/policy-tela.json" ABRE_PRAZO_TELA_S=5 \
  bash "$ABRE" --nome com-tela --backend bom >/dev/null 2>&1
if grep -q 'send-keys w1:pZ down' "$HERDR_CHAMADAS" \
   && grep -q 'send-keys w1:pZ enter' "$HERDR_CHAMADAS"; then
  ok "com o padrão na tela, as teclas da policy são mandadas na ordem"
else fail "o padrão casou e as teclas não saíram"; fi

echo "== policy do repo: toda tela de abertura é dado completo =="
quebrada=$(jq -r '[ .visivel.backends // {} | to_entries[]
  | .key as $k | (.value.telas_de_abertura // [])[]
  | select((.padrao // "") == "" or ((.teclas // []) | length) == 0) | $k ]
  | unique | join(" ")' "$POLICY" 2>/dev/null)
if [[ -z "$quebrada" ]]; then ok "toda tela de abertura tem padrão e teclas"
else fail "tela de abertura sem padrão ou sem teclas: $quebrada"; fi

echo "== o modo no despachante =="
DELEG="$ROOT/skills/delegate/scripts/delegate.sh"
# abridor fingido: grava como foi chamado. O que este bloco prova é o
# ROTEAMENTO do delegate, não o abridor, que já tem os asserts dele acima.
mkdir -p "$TMP/bin2"
cat > "$TMP/bin2/abre-sessao.sh" <<'SH'
#!/usr/bin/env bash
echo "$*" > "$ABRIDOR_CHAMADAS"
echo "w1:pY"
SH
chmod +x "$TMP/bin2/abre-sessao.sh"
export ABRIDOR_CHAMADAS="$TMP/abridor.txt"

: > "$ABRIDOR_CHAMADAS"
DELEGATE_ABRIDOR="$TMP/bin2/abre-sessao.sh" \
  bash "$DELEG" --task implement --tasks >/dev/null 2>&1
if [[ ! -s "$ABRIDOR_CHAMADAS" ]]; then ok "sem o modo, o abridor não é chamado"
else fail "o abridor foi chamado sem o modo ser pedido"; fi

: > "$ABRIDOR_CHAMADAS"
saida=$(DELEGATE_ABRIDOR="$TMP/bin2/abre-sessao.sh" \
  bash "$DELEG" --task implement --visivel revisa-spec 2>&1); rc=$?
if (( rc == 0 )); then ok "o modo visível despacha: rc=0"
else fail "o modo visível falhou (rc=$rc): $saida"; fi
if grep -q -- '--nome revisa-spec' "$ABRIDOR_CHAMADAS"; then
  ok "o nome do trabalho chega ao abridor"
else fail "o nome não chegou ao abridor (veio: '$(cat "$ABRIDOR_CHAMADAS")')"; fi
if grep -qE -- '--backend (codex|claude|agy)' "$ABRIDOR_CHAMADAS"; then
  ok "o backend sai da cascata da task, não de um nome cravado"
else fail "o backend não veio da cascata (veio: '$(cat "$ABRIDOR_CHAMADAS")')"; fi
# Modelo e esforço saem da MESMA entrada da cascata que o modo de lote usaria:
# escolher o worker numa fila e o esforço noutra é como as duas divergem.
if grep -qE -- '--model [^ ]' "$ABRIDOR_CHAMADAS" \
   && grep -qE -- '--effort [^ ]' "$ABRIDOR_CHAMADAS"; then
  ok "modelo e esforço vêm da entrada escolhida da cascata"
else fail "modelo ou esforço não chegaram: '$(cat "$ABRIDOR_CHAMADAS")'"; fi
if grep -q 'w1:pY' <<<"$saida"; then ok "o despacho devolve o endereço do painel"
else fail "o despacho não devolveu o painel (veio: '$saida')"; fi

# Task cuja cascata inteira é inelegível não pode cair calada no modo de lote:
# quem pediu para ver o worker ficaria olhando uma tela que nunca abre.
: > "$ABRIDOR_CHAMADAS"
cat > "$TMP/policy-ninguem.json" <<'JSON'
{
  "tasks": { "implement": [ { "backend": "so_lote", "model": "m1" } ] },
  "backends": { "so_lote": { "enabled": true } },
  "visivel": { "backends": { "so_lote": {
    "elegivel": false, "medido_em": "2026-09-22",
    "porque": "não devolve resposta pelo canal da camada" } } }
}
JSON
saida=$(DELEGATE_ABRIDOR="$TMP/bin2/abre-sessao.sh" DELEGATE_POLICY="$TMP/policy-ninguem.json" \
  bash "$DELEG" --task implement --visivel sem-ninguem 2>&1); rc=$?
if (( rc != 0 )); then ok "cascata sem elegível recusa em vez de cair no lote"
else fail "cascata sem elegível despachou calada no modo de lote"; fi
if [[ ! -s "$ABRIDOR_CHAMADAS" ]]; then ok "e não chegou a chamar o abridor"
else fail "chamou o abridor com cascata inelegível"; fi

echo
echo "== $PASS passed, $FAIL failed =="
(( FAIL == 0 ))
