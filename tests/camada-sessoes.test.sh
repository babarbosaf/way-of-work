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
# A suíte varre e apaga registro de sessão: sem isso ela mexeria no estado real
# de quem roda os testes, e o dono perderia o quadro das sessões dele.
export DELEGATE_GATE_DIR="$TMP/gate"

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
  "tab list")
    cat "$HERDR_TABS" 2>/dev/null ;;
  "workspace list")
    cat "$HERDR_ESPACOS" 2>/dev/null ;;
  "workspace create")
    echo '{"result":{"workspace":{"workspace_id":"wN"}}}' ;;
  "pane get")
    printf '{"result":{"pane":{"pane_id":"%s","agent_status":"%s"}}}\n' \
      "$3" "$(cat "$HERDR_ESTADO" 2>/dev/null || echo idle)" ;;
  "pane process-info")
    printf '{"result":{"process_info":{"shell_pid":%s}}}\n' \
      "$(cat "$HERDR_PID" 2>/dev/null || echo 4242)" ;;
  *) echo '{"result":{"type":"ok"}}' ;;
esac
SH
  chmod +x "$TMP/bin/herdr"
}
fixture_herdr
fixture_policy
mkdir -p "$TMP/vazio"
export HERDR_CHAMADAS="$TMP/chamadas.txt"
export HERDR_TELA="$TMP/tela.txt"
export HERDR_ESTADO="$TMP/estado.txt"
export HERDR_ESPACOS="$TMP/espacos.json"
echo '{"result":{"workspaces":[{"workspace_id":"w1","label":"~"}]}}' > "$HERDR_ESPACOS"
export HERDR_PID="$TMP/pid.txt"
: > "$HERDR_CHAMADAS"; : > "$HERDR_TELA"
echo idle > "$HERDR_ESTADO"; echo 4242 > "$HERDR_PID"

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
if grep -qF -- '--label » revisa-spec-sessoes' "$HERDR_CHAMADAS"; then
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

echo "== o adaptador da ferramenta de terminal =="
ADAPT="$ROOT/scripts/herdr-adapter.sh"
if [[ -x "$ADAPT" ]]; then ok "herdr-adapter.sh existe e é executável"
else fail "herdr-adapter.sh não existe ou não é executável"; fi

# Aceite do ticket: o adaptador é o único que sabe o nome da ferramenta. O dia em
# que a camada trocar de ferramenta, é um arquivo que muda, e o grep é o que
# prova isso hoje em vez de prometer.
# O que se proíbe é CHAMAR a ferramenta: apontar para o adaptador pelo nome dele
# é o contrário de vazamento, é o que faz a troca de ferramenta caber num arquivo.
vazados=$(grep -o 'herdr[A-Za-z0-9_.-]*' \
  "$ROOT"/scripts/*.sh "$ROOT"/skills/delegate/scripts/*.sh 2>/dev/null \
  | grep -v '/herdr-adapter\.sh:' | grep -vE ':herdr-adapter(\.sh)?$' | tr '\n' ' ')
if [[ -z "$vazados" ]]; then ok "nenhum script fora do adaptador nomeia a ferramenta"
else fail "a ferramenta é nomeada fora do adaptador: $vazados"; fi

: > "$HERDR_CHAMADAS"
saida=$(PATH="$TMP/bin:$PATH" bash "$ADAPT" abrir /tmp/x trabalho-y 2>"$TMP/adapt.err")
if [[ "$saida" == $'w1:pZ\tw1:tZ' ]]; then ok "abrir devolve painel e aba"
else fail "abrir não devolveu painel e aba (veio: '$saida')"; fi
# Ruído no caminho que deu certo é o que faz erro de verdade passar batido: o
# `local` em escopo global reclamava e o script seguia, e o teste não via nada.
if [[ ! -s "$TMP/adapt.err" ]]; then ok "e não reclama nada no caminho feliz"
else fail "o adaptador reclamou: $(cat "$TMP/adapt.err")"; fi

# A ferramenta ausente é o caso comum de outra máquina, e não pode virar erro
# ilegível vindo do shell: o adaptador responde por ela.
saida=$(PATH="$TMP/vazio" bash "$ADAPT" disponivel 2>&1); rc=$?
if (( rc != 0 )); then ok "sem a ferramenta no PATH, disponivel reprova"
else fail "disponivel aprovou sem a ferramenta instalada"; fi

cat > "$TMP/tabs.json" <<'JSON'
{"result":{"tabs":[
 {"tab_id":"w1:t1","label":"1","agent_status":"working","workspace_id":"w1"},
 {"tab_id":"w1:tZ","label":"» revisa-spec","agent_status":"idle","workspace_id":"w1"}
]}}
JSON
export HERDR_TABS="$TMP/tabs.json"
linhas=$(PATH="$TMP/bin:$PATH" bash "$ADAPT" listar 2>/dev/null)
if [[ "$(grep -c . <<<"$linhas")" == 2 ]]; then ok "listar devolve uma linha por aba"
else fail "listar não devolveu duas linhas (veio: '$linhas')"; fi
if grep -qF $'w1:tZ\t» revisa-spec\tidle' <<<"$linhas"; then
  ok "a linha carrega aba, nome e estado da ferramenta"
else fail "a linha não tem aba/nome/estado (veio: '$linhas')"; fi

: > "$HERDR_CHAMADAS"
PATH="$TMP/bin:$PATH" bash "$ADAPT" rotular w1:tZ 'novo nome' >/dev/null 2>&1
if grep -qF 'tab rename w1:tZ novo nome' "$HERDR_CHAMADAS"; then
  ok "rotular renomeia a aba pela ferramenta"
else fail "rotular não renomeou (veio: '$(cat "$HERDR_CHAMADAS")')"; fi

echo "== estado da sessão na lista =="
export DELEGATE_ADAPTADOR="$ADAPT"
SESSOES="$TMP/gate/sessoes"

# O abridor é quem sabe quem é o dono, e é aqui que a linha ganha vida própria: o
# registro amarra a sessão ao processo que a despachou, que é o que separa órfã
# de viva depois.
: > "$HERDR_CHAMADAS"
printf 'Ask anything\n' > "$HERDR_TELA"
PATH="$TMP/bin:$PATH" DELEGATE_POLICY="$TMP/policy.json" ABRE_PRAZO_TELA_S=1 \
  bash "$ABRE" --nome revisa-spec --backend bom >/dev/null 2>&1
reg=$(ls "$SESSOES"/*.json 2>/dev/null | head -1)
if [[ -n "$reg" ]]; then ok "o abridor registra a sessão que abriu"
else fail "o abridor não deixou registro em $SESSOES"; fi
if [[ "$(jq -r '.nome' "$reg" 2>/dev/null)" == "revisa-spec" ]]; then
  ok "o registro carrega o trabalho, não só o worker"
else fail "o registro não carrega o nome do trabalho"; fi
if [[ "$(jq -r '.dono' "$reg" 2>/dev/null)" =~ ^[0-9]+$ ]]; then
  ok "o registro carrega o dono do despacho"
else fail "o registro não carrega o dono"; fi
# Prefixo do marcador da fatia 01: é ele que a receita de sidebar apaga pra
# sobrar em destaque a linha de quem dirige. Aba dirigida sem prefixo deixa a
# receita sem nada pra distinguir.
if grep -qF -- '--label » revisa-spec' "$HERDR_CHAMADAS"; then
  ok "a aba dirigida nasce com o marcador de quem é dirigido"
else fail "a aba nasceu sem o marcador (veio: '$(cat "$HERDR_CHAMADAS")')"; fi

# shellcheck disable=SC1090
source "$LIB" 2>/dev/null
if declare -f visivel_sincronizar >/dev/null; then ok "visivel_sincronizar exportada"
else fail "visivel_sincronizar não existe"; fi

sincroniza() { PATH="$TMP/bin:$PATH" visivel_sincronizar >/dev/null 2>&1; }

# Dono vivo: a linha fica como está. Renomear a cada varredura faria a lista
# piscar e encheria o log de mudança que não mudou nada.
: > "$HERDR_CHAMADAS"
jq --arg p "$$" '.dono = ($p|tonumber)' "$reg" > "$reg.tmp" && mv "$reg.tmp" "$reg"
sincroniza
if ! grep -q 'tab rename' "$HERDR_CHAMADAS"; then ok "dono vivo não mexe na linha"
else fail "sincronizar renomeou a aba de dono vivo"; fi
if [[ -f "$reg" ]]; then ok "e o registro continua de pé"
else fail "sincronizar apagou o registro de sessão viva"; fi

# Dono morto com sessão viva é o caso que a D-09 protege: some da lista e ninguém
# descobre que sobrou worker gastando cota.
: > "$HERDR_CHAMADAS"
jq '.dono = 999999' "$reg" > "$reg.tmp" && mv "$reg.tmp" "$reg"
sincroniza
if grep -q 'tab rename w1:tZ' "$HERDR_CHAMADAS"; then ok "despachante morto marca a linha"
else fail "despachante morto não marcou a linha"; fi
if grep -qF 'tab rename w1:tZ » revisa-spec ?' "$HERDR_CHAMADAS"; then
  ok "a marca diz que o estado é desconhecido"
else fail "a marca não diz desconhecido (veio: '$(cat "$HERDR_CHAMADAS")')"; fi
if ! grep -q 'tab close' "$HERDR_CHAMADAS"; then ok "e a aba órfã continua aberta"
else fail "sincronizar fechou a aba órfã"; fi
if [[ -f "$reg" ]]; then ok "e o registro da órfã continua de pé"
else fail "sincronizar apagou o registro da órfã"; fi

# Marca que se empilha vira "» x ? ? ?" na terceira varredura, e a lista fica
# ilegível justo no caso que ela existe pra mostrar.
: > "$HERDR_CHAMADAS"
jq -r '.result.tabs[1].label = "» revisa-spec ?"' "$TMP/tabs.json" > "$TMP/tabs2.json"
HERDR_TABS="$TMP/tabs2.json" sincroniza
if ! grep -q 'tab rename' "$HERDR_CHAMADAS"; then ok "a marca de órfã não se empilha"
else fail "sincronizar remarcou uma linha já marcada"; fi

# Sessão morta apaga a linha, e o registro vai junto: registro sobrevivente
# ressuscitaria a aba na próxima varredura.
: > "$HERDR_CHAMADAS"
echo '{"result":{"tabs":[{"tab_id":"w1:t1","label":"1","agent_status":"idle","workspace_id":"w1"}]}}' \
  > "$TMP/tabs-sem.json"
HERDR_TABS="$TMP/tabs-sem.json" sincroniza
if [[ ! -f "$reg" ]]; then ok "sessão morta apaga o registro"
else fail "o registro sobreviveu à morte da sessão"; fi
unset DELEGATE_ADAPTADOR

echo "== dirigir, ler e assumir =="
DIRIGE="$ROOT/scripts/dirige-sessao.sh"
if [[ -x "$DIRIGE" ]]; then ok "dirige-sessao.sh existe e é executável"
else fail "dirige-sessao.sh não existe ou não é executável"; fi

export DELEGATE_ADAPTADOR="$ADAPT"
MARCA="ECO-$$-$RANDOM"

# A instrução vai como texto literal, e é medição que mandou: o canal de prompt
# da ferramenta entrega instrução longa como conteúdo colado, e o worker a recusa
# como tentativa de injeção. Digitado, o mesmo texto foi obedecido na hora.
: > "$HERDR_CHAMADAS"; echo idle > "$HERDR_ESTADO"
printf 'nada aqui\n' > "$HERDR_TELA"
PATH="$TMP/bin:$PATH" DIRIGE_PRAZO_PARTIDA_S=1 DIRIGE_PRAZO_S=2 \
  bash "$DIRIGE" instruir w1:pZ "transforme $MARCA" >/dev/null 2>&1
if grep -qF "pane send-text w1:pZ transforme $MARCA" "$HERDR_CHAMADAS"; then
  ok "a instrução vai como texto literal, com o valor inteiro"
else fail "a instrução não foi digitada (veio: '$(cat "$HERDR_CHAMADAS")')"; fi
# Texto sem enter fica na linha de entrada e o worker nunca vê: a sessão
# principal esperaria uma resposta que ninguém pediu.
if grep -qF 'send-keys w1:pZ enter' "$HERDR_CHAMADAS"; then
  ok "e é submetida, não deixada na linha"
else fail "a instrução ficou na linha sem enter"; fi
# Recusar como injeção é o que o canal de prompt provocou, e o assert existe pra
# essa escolha não voltar por descuido.
if ! grep -q 'agent prompt' "$HERDR_CHAMADAS"; then
  ok "e não passa pelo canal que vira colagem"
else fail "a instrução voltou a ir pelo canal de colagem"; fi

# Espera embutida da ferramenta já pendurou além de dois minutos com o worker já
# tendo respondido. A sincronização é por consulta, com prazo deste lado.
if ! grep -qE 'agent (wait|prompt .*--wait)' "$HERDR_CHAMADAS"; then
  ok "a sincronização não usa a espera embutida da ferramenta"
else fail "o script pendurou na espera embutida"; fi
if grep -q 'pane get' "$HERDR_CHAMADAS"; then ok "o estado é consultado, não esperado"
else fail "o script não consultou o estado"; fi

# Prazo próprio: worker que não volta não pendura a sessão principal pra sempre.
: > "$HERDR_CHAMADAS"; echo working > "$HERDR_ESTADO"
PATH="$TMP/bin:$PATH" DIRIGE_PRAZO_PARTIDA_S=1 DIRIGE_PRAZO_S=2 \
  bash "$DIRIGE" instruir w1:pZ "trava" >/dev/null 2>&1; rc=$?
if (( rc != 0 )); then ok "worker que não volta estoura o prazo em vez de pendurar"
else fail "instruir aprovou com o worker ainda trabalhando"; fi
echo idle > "$HERDR_ESTADO"

# A leitura é da TELA, e é isso que o aceite cobra: o valor que veio por arquivo
# não conta, porque o caminho antigo de captura é exatamente o que a camada
# substitui.
: > "$HERDR_CHAMADAS"
printf 'saida: %s-INVERTIDO\n' "$MARCA" > "$HERDR_TELA"
echo "$MARCA-DE-ARQUIVO" > "$TMP/resposta-falsa.txt"
tela=$(PATH="$TMP/bin:$PATH" bash "$DIRIGE" ler w1:pZ 2>/dev/null)
if grep -qF "$MARCA-INVERTIDO" <<<"$tela"; then
  ok "a leitura devolve a transformação exata que está na tela"
else fail "a leitura não trouxe a tela (veio: '$tela')"; fi
if ! grep -qF "DE-ARQUIVO" <<<"$tela"; then ok "e não traz o que veio por arquivo"
else fail "a leitura misturou arquivo com tela"; fi
if grep -q 'pane read' "$HERDR_CHAMADAS"; then ok "a leitura passa pelo canal da camada"
else fail "a leitura não usou o canal da camada"; fi
# Caminho antigo de captura e área de transferência não podem nem estar escritos
# no script: o assert acima só mede a chamada que este teste provocou.
proibidos=$(grep -oE 'pbpaste|pbcopy|out\.txt|resposta\.txt' "$DIRIGE" | sort -u | tr '\n' ' ')
if [[ -z "$proibidos" ]]; then ok "o script não conhece arquivo nem área de transferência"
else fail "o script lê pelo caminho antigo: $proibidos"; fi

# Assumir é entregar o volante, não recomeçar: painel novo perderia a conversa
# inteira, que é o custo que a camada existe pra eliminar.
: > "$HERDR_CHAMADAS"
antes=$(PATH="$TMP/bin:$PATH" bash "$DIRIGE" processo w1:pZ 2>/dev/null)
PATH="$TMP/bin:$PATH" bash "$DIRIGE" assumir w1:pZ >/dev/null 2>&1; rc=$?
depois=$(PATH="$TMP/bin:$PATH" bash "$DIRIGE" processo w1:pZ 2>/dev/null)
if (( rc == 0 )); then ok "assumir sai zero"; else fail "assumir falhou (rc=$rc)"; fi
if grep -q 'agent focus w1:pZ' "$HERDR_CHAMADAS"; then
  ok "assumir foca o painel que já existe"
else fail "assumir não focou o painel (veio: '$(cat "$HERDR_CHAMADAS")')"; fi
if [[ -n "$antes" && "$antes" == "$depois" ]]; then
  ok "a sessão assumida segue no mesmo processo"
else fail "o processo mudou ao assumir ('$antes' → '$depois')"; fi
if ! grep -qE 'tab create|pane split|agent start' "$HERDR_CHAMADAS"; then
  ok "e no mesmo painel, sem abrir nada novo"
else fail "assumir criou painel ou sessão nova"; fi
unset DELEGATE_ADAPTADOR

echo "== agrupamento por projeto =="
export DELEGATE_ADAPTADOR="$ADAPT"
cat > "$TMP/espacos-dois.json" <<'JSON'
{"result":{"workspaces":[
 {"workspace_id":"w1","label":"~"},
 {"workspace_id":"w7","label":"projeto-um"}
]}}
JSON

linhas=$(PATH="$TMP/bin:$PATH" HERDR_ESPACOS="$TMP/espacos-dois.json" \
  bash "$ADAPT" espacos 2>/dev/null)
if grep -qF $'w7\tprojeto-um' <<<"$linhas"; then ok "espacos devolve grupo e nome"
else fail "espacos não devolveu os grupos (veio: '$linhas')"; fi

# shellcheck disable=SC1090
source "$LIB" 2>/dev/null
if declare -f visivel_espaco >/dev/null; then ok "visivel_espaco exportada"
else fail "visivel_espaco não existe"; fi

# Grupo que já existe se reusa: criar um segundo com o mesmo nome espalharia as
# abas do mesmo projeto por dois lugares, que é o contrário do que a fatia quer.
: > "$HERDR_CHAMADAS"
espaco=$(PATH="$TMP/bin:$PATH" HERDR_ESPACOS="$TMP/espacos-dois.json" \
  visivel_espaco /qualquer/caminho/projeto-um 2>/dev/null)
if [[ "$espaco" == "w7" ]]; then ok "o projeto que já tem grupo reusa o dele"
else fail "não reusou o grupo existente (veio: '$espaco')"; fi
if ! grep -q 'workspace create' "$HERDR_CHAMADAS"; then ok "e nenhum grupo novo nasce"
else fail "criou grupo que já existia"; fi

: > "$HERDR_CHAMADAS"
espaco=$(PATH="$TMP/bin:$PATH" HERDR_ESPACOS="$TMP/espacos-dois.json" \
  visivel_espaco /qualquer/caminho/projeto-dois 2>/dev/null)
if [[ "$espaco" == "wN" ]]; then ok "projeto sem grupo ganha o dele"
else fail "projeto sem grupo não ganhou grupo (veio: '$espaco')"; fi
if grep -qF -- '--label projeto-dois' "$HERDR_CHAMADAS"; then
  ok "e o grupo leva o nome do projeto"
else fail "o grupo nasceu sem o nome do projeto (veio: '$(cat "$HERDR_CHAMADAS")')"; fi

# O aceite de verdade: a aba nasce DENTRO do grupo, e é o cwd do trabalho que
# diz qual é. Sem isso a lista volta a ser achatada.
: > "$HERDR_CHAMADAS"
printf 'Ask anything\n' > "$HERDR_TELA"
PATH="$TMP/bin:$PATH" HERDR_ESPACOS="$TMP/espacos-dois.json" \
  DELEGATE_POLICY="$TMP/policy.json" ABRE_PRAZO_TELA_S=1 \
  bash "$ABRE" --nome t99-algo --backend bom --cwd /qualquer/caminho/projeto-um >/dev/null 2>&1
if grep -qF -- '--workspace w7' "$HERDR_CHAMADAS"; then
  ok "a aba nasce no grupo do projeto dela"
else fail "a aba nasceu fora do grupo (veio: '$(cat "$HERDR_CHAMADAS")')"; fi

: > "$HERDR_CHAMADAS"
PATH="$TMP/bin:$PATH" HERDR_ESPACOS="$TMP/espacos-dois.json" \
  DELEGATE_POLICY="$TMP/policy.json" ABRE_PRAZO_TELA_S=1 \
  bash "$ABRE" --nome t98-outro --backend bom --cwd /qualquer/caminho/projeto-dois >/dev/null 2>&1
if grep -qF -- '--workspace wN' "$HERDR_CHAMADAS"; then
  ok "trabalho de outro projeto nasce em outro grupo"
else fail "os dois projetos caíram no mesmo grupo"; fi
unset DELEGATE_ADAPTADOR

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

echo "== sem o modo, e sem a ferramenta, nada muda =="
# Worker de mentira no PATH: o despacho roda do começo ao fim sem gastar cota, e
# o que ele grava é o que prova que a escolha não mudou.
mkdir -p "$TMP/bin3"
cat > "$TMP/bin3/falso" <<'SH'
#!/usr/bin/env bash
echo "$*" >> "$FALSO_CHAMADAS"
echo "resposta do falso"
SH
chmod +x "$TMP/bin3/falso"
cat > "$TMP/policy-lote.json" <<'JSON'
{
  "tasks": { "implement": [ { "backend": "falso", "model": "m1", "effort": "alto" } ] },
  "backends": { "falso": { "enabled": true, "bin": "falso", "invoke": "falso -",
                           "prompt_via": "stdin", "model_flag": "-m" } },
  "timeouts": { "implement": 30 },
  "cooldowns": { "rate_limit_mins": 1, "tier_fallback_mins": 60,
                 "transient_mins": 10, "silent_fail_mins": 60 },
  "budgets": { "window_mins": 300, "pools": {} },
  "limits": { "prompt_bytes": 100000 },
  "visivel": { "backends": { "falso": { "elegivel": true, "medido_em": "2026-09-22",
                "invoke": "falso --interativo", "porque": "medido" } } }
}
JSON
# Adaptador espião: existe, é executável, e grava toda chamada. No modo desligado
# o arquivo tem que ficar vazio, e é esse vazio que a D-01 promete.
cat > "$TMP/bin3/espiao.sh" <<'SH'
#!/usr/bin/env bash
echo "$*" >> "$ESPIAO_CHAMADAS"
SH
chmod +x "$TMP/bin3/espiao.sh"
export FALSO_CHAMADAS="$TMP/falso.txt"
export ESPIAO_CHAMADAS="$TMP/espiao.txt"
: > "$FALSO_CHAMADAS"; : > "$ESPIAO_CHAMADAS"
LOTE="$TMP/gate-lote"

lote() { # roda um despacho de lote no ambiente controlado
  echo "trabalho de teste" | env PATH="$TMP/bin3:$PATH" \
    DELEGATE_POLICY="$TMP/policy-lote.json" DELEGATE_GATE_DIR="$LOTE" \
    DELEGATE_ADAPTADOR="$TMP/bin3/espiao.sh" \
    bash "$DELEG" --task implement - 2>&1
}

saida=$(lote); rc=$?
if (( rc == 0 )); then ok "modo desligado: o despacho completa"
else fail "modo desligado falhou (rc=$rc): $saida"; fi
if grep -qF -- '-m m1' "$FALSO_CHAMADAS"; then
  ok "modo desligado escolhe o mesmo modelo da cascata"
else fail "o modelo mudou (veio: '$(cat "$FALSO_CHAMADAS")')"; fi
meta=$(cat "$LOTE"/tasks/*/meta 2>/dev/null)
if grep -q '^balde=falso$' <<<"$meta"; then ok "e o mesmo balde"
else fail "o balde mudou (meta: '$meta')"; fi
faltando=""
for campo in estado task balde branch rc comecou terminou; do
  grep -q "^$campo=" <<<"$meta" || faltando="$faltando $campo"
done
if [[ -z "$faltando" ]]; then ok "o registro grava todos os campos obrigatórios"
else fail "campo faltando no registro:$faltando"; fi
if [[ ! -s "$ESPIAO_CHAMADAS" ]]; then ok "e o adaptador não é chamado nenhuma vez"
else fail "o modo desligado chamou o adaptador: $(cat "$ESPIAO_CHAMADAS")"; fi

# Máquina sem a ferramenta é o caso da maioria, e nela o despacho comum não pode
# nem perceber que a camada existe.
rm -rf "$LOTE"; : > "$FALSO_CHAMADAS"
saida=$(echo "trabalho de teste" | env PATH="$TMP/bin3:/usr/bin:/bin" \
  DELEGATE_POLICY="$TMP/policy-lote.json" DELEGATE_GATE_DIR="$LOTE" \
  bash "$DELEG" --task implement - 2>&1); rc=$?
if (( rc == 0 )); then ok "ferramenta ausente com modo desligado: completa igual"
else fail "sem a ferramenta o despacho comum quebrou (rc=$rc): $saida"; fi

# Cair calado no modo antigo entregaria trabalho feito onde ninguém pediu, e quem
# pediu pra ver ficaria olhando uma aba que nunca abre.
: > "$FALSO_CHAMADAS"
saida=$(env PATH="$TMP/bin3:$PATH" DELEGATE_POLICY="$TMP/policy-lote.json" \
  DELEGATE_GATE_DIR="$TMP/gate-sem-adapt" DELEGATE_ADAPTADOR="$TMP/nao-existe.sh" \
  bash "$DELEG" --task implement --visivel pedido-sem-adaptador 2>&1); rc=$?
if (( rc != 0 )); then ok "modo visível sem adaptador falha"
else fail "modo visível sem adaptador seguiu adiante (rc=0)"; fi
if grep -qi 'adaptador' <<<"$saida"; then ok "e a falha nomeia a causa"
else fail "a falha não nomeia a causa (veio: '$saida')"; fi
if [[ ! -s "$FALSO_CHAMADAS" ]]; then ok "e não caiu calado no modo antigo"
else fail "caiu no modo de lote: $(cat "$FALSO_CHAMADAS")"; fi

# Ferramenta ausente é causa diferente de adaptador ausente, e quem lê precisa
# saber qual das duas instalar.
: > "$FALSO_CHAMADAS"
saida=$(env PATH="$TMP/bin3:/usr/bin:/bin" DELEGATE_POLICY="$TMP/policy-lote.json" \
  DELEGATE_GATE_DIR="$TMP/gate-sem-ferramenta" \
  bash "$DELEG" --task implement --visivel pedido-sem-ferramenta 2>&1); rc=$?
if (( rc != 0 )) && grep -qi 'herdr' <<<"$saida"; then
  ok "modo visível sem a ferramenta falha nomeando a ferramenta"
else fail "sem a ferramenta o modo visível não nomeou a causa (rc=$rc): '$saida'"; fi
if [[ ! -s "$FALSO_CHAMADAS" ]]; then ok "e também não caiu no modo antigo"
else fail "caiu no modo de lote sem a ferramenta"; fi

echo "== camada morta se anuncia =="
# Vazio significa ocioso, e só isso. O dia em que um caminho de config errado
# deixou a camada morta, a barra ficou idêntica a "nada em curso" por um dia
# inteiro, e é essa confusão que o aceite proíbe.
quebrado=$(DELEGATE_GATE_DIR="$TMP/gate-que-nao-existe" bash "$DELEG" --tasks --oneline 2>&1)
if [[ -n "$quebrado" ]]; then ok "leitor sem acesso ao estado não sai vazio"
else fail "leitura quebrada saiu vazia, igual a ocioso"; fi

mkdir -p "$TMP/gate-vazio/tasks"
ocioso=$(DELEGATE_GATE_DIR="$TMP/gate-vazio" bash "$DELEG" --tasks --oneline 2>&1)
if [[ -z "$ocioso" ]]; then ok "ocioso continua saindo vazio"
else fail "ocioso deixou de ser silêncio (veio: '$ocioso')"; fi
if [[ "$quebrado" != "$ocioso" ]]; then ok "e quebrado é diferente de ocioso na tela"
else fail "quebrado e ocioso mostram a mesma coisa"; fi

# Formato da linha do caso normal: outras telas já consomem `dlg: <balde>`, e
# mudar isso quebraria quem lê sem avisar.
mkdir -p "$TMP/gate-cheio/tasks/implement-aaaaaa"
printf 'estado=em curso\ntask=implement\nbalde=falso\n' \
  > "$TMP/gate-cheio/tasks/implement-aaaaaa/meta"
printf 'balde=falso\npid=%s\nid=implement-aaaaaa\n' "$$" \
  > "$TMP/gate-cheio/slot.falso"
normal=$(DELEGATE_GATE_DIR="$TMP/gate-cheio" bash "$DELEG" --tasks --oneline 2>&1)
if [[ "$normal" == "dlg: falso" ]]; then ok "a linha do caso normal não muda de formato"
else fail "o formato da linha mudou (veio: '$normal')"; fi

# A tabela é a outra superfície do mesmo leitor, e mente do mesmo jeito.
tab_quebrado=$(DELEGATE_GATE_DIR="$TMP/gate-que-nao-existe" bash "$DELEG" --tasks 2>&1)
tab_ocioso=$(DELEGATE_GATE_DIR="$TMP/gate-vazio" bash "$DELEG" --tasks 2>&1)
if [[ "$tab_quebrado" != "$tab_ocioso" ]]; then
  ok "na tabela, quebrado também difere de ocioso"
else fail "a tabela mostra a mesma coisa nos dois casos (veio: '$tab_ocioso')"; fi
if grep -q 'nenhuma task em curso' <<<"$tab_ocioso"; then
  ok "e ocioso na tabela continua dizendo o que dizia"
else fail "a tabela de ocioso mudou (veio: '$tab_ocioso')"; fi

echo "== cenário de ponta a ponta =="
# O único bloco que abre aba de verdade e gasta chamada de worker. Roda sozinho,
# sem ninguém olhando, que é o ponto: cenário que só roda à mão passa uma vez e
# nunca mais é verificável. `CAMADA_E2E=0` desliga, e o pulo sai escrito.
cenario_e2e() { # → rc 0 quando o commit da sessão dirigida carrega a marca
  local marca repo backend modelo esforco pane tab espaco log
  # Exclusiva da execução: duas rodadas seguidas não podem se confundir, e uma
  # marca repetida faria a segunda passar com o commit da primeira.
  marca="E2E-$$-${RANDOM}-$(date +%s)"
  repo="$TMP/e2e-$marca"
  mkdir -p "$repo" || return 1
  git -C "$repo" init -q 2>/dev/null || return 1
  git -C "$repo" config user.email cenario@teste
  git -C "$repo" config user.name cenario
  echo base > "$repo/README.md"
  git -C "$repo" add -A && git -C "$repo" commit -qm base || return 1

  # Mesma escolha que o despacho faria: primeiro da fila que a medição aprovou.
  visivel_configurar "$POLICY" || return 1
  while IFS=$'\t' read -r b m e; do
    [[ -n "$b" ]] || continue
    if visivel_elegivel "$b"; then backend="$b"; modelo="$m"; esforco="$e"; break; fi
  done < <(jq -r '.tasks.implement[]? | [.backend, (.model // ""), (.effort // "")] | @tsv' "$POLICY")
  [[ -n "${backend:-}" ]] || return 1

  pane=$(bash "$ABRE" --nome "cenario-$marca" --backend "$backend" \
    ${modelo:+--model "$modelo"} ${esforco:+--effort "$esforco"} --cwd "$repo") || return 1
  [[ -n "$pane" ]] || return 1

  DIRIGE_PRAZO_S=240 bash "$DIRIGE" instruir "$pane" \
    "Crie o arquivo marca.txt com o conteudo exato $marca, depois rode git add -A e git commit -m $marca. Nao faca mais nada." \
    >/dev/null 2>&1

  tab=$(bash "$ADAPT" listar | awk -F'\t' -v n="cenario-$marca" 'index($2,n){print $1; exit}')
  [[ -n "$tab" ]] && herdr tab close "$tab" >/dev/null 2>&1
  # O grupo do projeto nasce com a aba, e repo temporário não pode deixar grupo
  # vazio pra trás: duas rodadas por execução vira lixo acumulado na tela do dono.
  espaco=$(bash "$ADAPT" espacos | awk -F'\t' -v n="$(basename "$repo")" '$2==n{print $1; exit}')
  [[ -n "$espaco" ]] && herdr workspace close "$espaco" >/dev/null 2>&1

  log=$(git -C "$repo" log -1 --format=%s 2>/dev/null)
  [[ "$log" == *"$marca"* ]]
}

if [[ "${CAMADA_E2E:-1}" == 0 ]]; then
  echo "  ~ pulado: CAMADA_E2E=0, o cenário gasta chamada de worker de verdade"
elif ! command -v herdr >/dev/null 2>&1; then
  echo "  ~ pulado: a ferramenta não está nesta máquina"
elif [[ -z "$(visivel_configurar "$POLICY" && visivel_lista | head -1)" ]]; then
  echo "  ~ pulado: nenhum worker elegível na policy deste repo"
else
  if cenario_e2e; then ok "o cenário abre, dirige e fecha, e o commit carrega a marca"
  else fail "o cenário não produziu o commit com a marca"; fi
  # Duas rodadas seguidas: veredito que muda entre execuções idênticas não é
  # prova de nada, é sorte medida uma vez.
  if cenario_e2e; then ok "e a segunda rodada seguida dá o mesmo veredito"
  else fail "a segunda rodada divergiu da primeira"; fi
fi

echo
echo "== $PASS passed, $FAIL failed =="
(( FAIL == 0 ))
