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
# Vários testes sobrescrevem um mock pra exercitar um comportamento e precisam do
# default de volta depois; a função é a única cópia de cada corpo.
mock_codex() {
cat > "$MOCKBIN/codex" <<'EOF'
#!/usr/bin/env bash
case "${MOCK_CODEX:-ok}" in
  ok) cat >/dev/null; echo "codex-resposta:$*"; exit 0 ;;
  multilinha) cat >/dev/null; printf "codex-resposta:%s\nb\nc\nd\ne\n" "$*"; exit 0 ;;
  ratelimit) echo "429 too many requests: rate limit"; exit 1 ;;
  notfound) cat >/dev/null; echo "ERROR: unexpected status 404 Not Found: The model \`gpt-5.5\` does not exist or you do not have access to it."; exit 1 ;;
  fail) echo "erro interno"; exit 1 ;;
  absent) exit 127 ;;
esac
EOF
chmod +x "$MOCKBIN/codex"
}
mock_agy() {
cat > "$MOCKBIN/agy" <<'EOF'
#!/usr/bin/env bash
case "${MOCK_AGY:-ok}" in
  ok) echo "agy-resposta:$*"; exit 0 ;;
  ratelimit) echo "quota exceeded"; exit 1 ;;
  fail) echo "erro interno agy"; exit 1 ;;
  empty) exit 0 ;;
  desculpa) echo "warning: run ended with no output and no recorded error"; exit 0 ;;
  curto) echo "linha unica"; exit 0 ;;
  drainstdin) cat >/dev/null; echo "erro interno agy"; exit 1 ;;
esac
EOF
chmod +x "$MOCKBIN/agy"
}
mock_codex; mock_agy
# O degrau claude é o último de toda cascata, e o default aqui é FALHAR: teste que
# quer exercitá-lo liga com MOCK_CLAUDE=ok. Sem esse default, todo teste de
# "cascata esgotada" sairia 0 chamando o claude REAL e queimando cota do plano.
# O `ok` ecoa a ANTHROPIC_API_KEY que chegou ao processo: é assim que se prova que
# o delegate remove a variável antes de invocar worker (senão o plano vira API).
cat > "$MOCKBIN/claude" <<'EOF'
#!/usr/bin/env bash
case "${MOCK_CLAUDE:-fail}" in
  ok) cat >/dev/null; echo "claude-resposta:$* key=${ANTHROPIC_API_KEY:-unset}"; exit 0 ;;
  multilinha) cat >/dev/null; printf "claude-resposta:%s\nb\nc\nd\ne\n" "$*"; exit 0 ;;
  ratelimit) cat >/dev/null; echo "429 too many requests: rate limit"; exit 1 ;;
  fail) cat >/dev/null; echo "erro interno claude"; exit 1 ;;
  absent) exit 127 ;;
esac
EOF
chmod +x "$MOCKBIN/claude"
export PATH="$MOCKBIN:$PATH"

# ambiente isolado: gate dir e policy próprios do teste
export DELEGATE_GATE_DIR="$TMP/gate"
export DELEGATE_POLICY="$TMP/policy.json"
export DELEGATE_INBOX="$TMP/inbox.md"
cp "$HERE/../config/model-policy.json" "$DELEGATE_POLICY"

run() { echo "prompt de teste" | bash "$DELEGATE" "$@" 2>"$TMP/err"; }

# A task sai da policy, não do hardcode: a ordem da cascata muda por medição, e
# um `--task` cravado faria estes testes testarem roteamento em vez do que querem.
# Precisa de agy na cascata: a review lidera com codex e não tem backend de agy
# de propósito (review_shelf é fechada), então serviria de vácuo pros testes que
# exercitam a descida da cascata.
CODEX_FIRST_TASK=$(jq -r '.tasks | to_entries[] | select((.value | type) == "array" and .value[0].backend == "codex" and ([.value[].backend] | index("agy"))) | .key' "$DELEGATE_POLICY" | head -1)
[[ -n "$CODEX_FIRST_TASK" ]] && ok "policy tem task que lidera com codex (senão os testes de 1o degrau são vácuo)" \
  || fail "nenhuma task lidera com codex: os testes de 1o degrau não têm como exercitá-lo"

echo "T: journey one-shot (boilerplate → 1o modelo da cascata na policy)"
BOIL_MODEL=$(jq -r '.tasks.boilerplate[0].model' "$DELEGATE_POLICY")
BOIL_POOL=$(jq -r --arg m "$BOIL_MODEL" '.backends.agy.pools | to_entries[] | select(.value | index($m)) | .key' "$DELEGATE_POLICY")
out=$(run --task boilerplate -)
assert_eq "exit 0" "$?" "0"
assert_contains "resposta do agy no stdout" "$out" "agy-resposta"
assert_contains "modelo da policy passado ao agy" "$out" "$BOIL_MODEL"
grep -q "\"pool\":\"agy:$BOIL_POOL\"" "$DELEGATE_GATE_DIR/delegate.log" && ok "pool registrado no log" || fail "pool registrado no log"
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

echo "T: rc=0 com desculpa curta do worker é falha, não resposta (medido 2026-09-15: 321KB entraram, 56B voltaram como ok)"
rm -f "$DELEGATE_GATE_DIR"/cooldown.*
out=$(MOCK_AGY=desculpa run --task scan -)
assert_eq "exit 0 (codex assumiu depois das 2 desculpas)" "$?" "0"
assert_contains "codex respondeu, a desculpa do agy não passou por resposta" "$out" "codex-resposta"
grep -q "run ended with no output" <<<"$out" && fail "desculpa do worker vazou pro stdout" || ok "desculpa do worker não vaza pro stdout"
rm -f "$DELEGATE_GATE_DIR"/cooldown.*

echo "T: cascata esgotada nomeia cada degrau que falhou (39% do log era 'cascata esgotada' e nada mais)"
rm -f "$DELEGATE_GATE_DIR"/cooldown.*
rc=0; MOCK_AGY=fail MOCK_CODEX=fail run --task scan - >/dev/null || rc=$?
assert_eq "exit 2" "$rc" "2"
det=$(jq -r 'select(.status=="unavailable")|.detail' "$DELEGATE_GATE_DIR/delegate.log" | tail -1)
assert_contains "detail nomeia o pool do agy" "$det" "agy:"
assert_contains "detail nomeia o codex" "$det" "codex"
assert_contains "detail carrega o rc do degrau" "$det" "rc1"
grep -q '"detail":"cascata esgotada"' <<<"$(tail -1 "$DELEGATE_GATE_DIR/delegate.log")" && fail "detail continua o literal sem diagnóstico" || ok "detail deixou de ser literal fixo"
rm -f "$DELEGATE_GATE_DIR"/cooldown.*

echo "T: prompt acima do teto é recusado antes de gastar o timeout"
big="$TMP/grande.txt"
head -c 300000 /dev/zero | tr '\0' 'x' > "$big"
rc=0; out=$(bash "$DELEGATE" --task scan --paths "$big" --question "resuma" - <<< "x" 2>"$TMP/err") || rc=$?
assert_eq "exit 1 (erro de uso, não 600s de timeout)" "$rc" "1"
assert_contains "mensagem manda fatiar" "$(cat "$TMP/err")" "fatie"
grep -q '"status":"oversize"' "$DELEGATE_GATE_DIR/delegate.log" && ok "recusa por tamanho fica no log" || fail "recusa por tamanho fica no log"

echo "T: --expect-lines faz a cascata descer quando a forma não bate"
rm -f "$DELEGATE_GATE_DIR"/cooldown.*
out=$(MOCK_AGY=curto MOCK_CODEX=multilinha run --task scan --expect-lines 5 -)
assert_eq "exit 0 (codex assumiu; o agy devolveu 1 linha onde 5 eram pedidas)" "$?" "0"
assert_contains "quem respondeu foi quem bateu a forma" "$out" "codex-resposta"
assert_contains "aviso nomeia a forma esperada" "$(cat "$TMP/err")" "esperava >= 5 linha"
rm -f "$DELEGATE_GATE_DIR"/cooldown.*

echo "T: forma que nenhum worker atende esgota a cascata (exit 2), em vez de passar retorno curto por resposta"
rc=0; out=$(MOCK_AGY=curto run --task scan --expect-lines 5 - ) || rc=$?
assert_eq "exit 2 — a sessão assume" "$rc" "2"
grep -q "linha unica" <<<"$out" && fail "retorno fora de forma vazou pro stdout" || ok "retorno fora de forma não vaza pro stdout"
rm -f "$DELEGATE_GATE_DIR"/cooldown.*

echo "T: worker que drena stdin (arg mode) não quebra o loop da cascata (regressão real de produção)"
out=$(MOCK_AGY=drainstdin run --task scan -)   # 2 entradas agy (arg mode) antes de codex — cada uma lê+descarta stdin
assert_eq "exit 0 (cascata percorreu as 2 entradas agy até chegar no codex)" "$?" "0"
assert_contains "chegou no codex, não parou na 1a entrada" "$out" "codex-resposta"

echo "T: cascata esgotada → exit 2 e a sessão assume (não há backend de resgate)"
MOCK_CODEX=fail MOCK_AGY=fail run --task "$CODEX_FIRST_TASK" - >/dev/null; rc=$?
assert_eq "exit 2 — todo backend da policy é de custo marginal zero, e esgotou" "$rc" "2"

echo "T: journey fallback (todos rate-limited → exit 2 + a sessão assume)"
MOCK_CODEX=ratelimit MOCK_AGY=ratelimit run --task "$CODEX_FIRST_TASK" - >/dev/null; rc=$?
assert_eq "exit 2" "$rc" "2"
assert_contains "mensagem de fallback" "$(cat "$TMP/err")" "A sessão assume"
[[ -f "$DELEGATE_GATE_DIR/cooldown.codex" ]] && ok "cooldown codex armado" || fail "cooldown codex armado"
[[ -f "$DELEGATE_GATE_DIR/cooldown.agy:gemini" ]] && ok "cooldown agy:gemini armado (por pool, não por backend inteiro)" || fail "cooldown agy:gemini armado"

echo "T: cooldown ativo pula backend sem invocar"
rm -f "$DELEGATE_GATE_DIR/cooldown.agy:gemini"   # só codex fica em cooldown
out=$(run --task "$CODEX_FIRST_TASK" -)   # codex ainda em cooldown do teste anterior
assert_contains "usou agy direto" "$out" "agy-resposta"

rm -f "$DELEGATE_GATE_DIR"/cooldown.*

echo "T: --model força backend específico"
out=$(run --task "$CODEX_FIRST_TASK" --model agy -)
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

echo "T: worktree — {worktree} substituído no comando e caminho absoluto injetado no prompt"
# Regressão real: o agy não começa no cwd, e sem o caminho escrito o worker sai
# caçando a raiz do repo e escreve na ÁRVORE PRINCIPAL. O mock grava o argv que
# recebeu, que é onde o --add-dir e o prompt (prompt_via=arg) aparecem.
export AGY_ARGV_DUMP="$TMP/agy-argv.txt"
cat > "$MOCKBIN/agy" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$@" > "$AGY_ARGV_DUMP"
echo mudanca > worker-agy.txt
echo "agy-worktree-ok"; exit 0
EOF
chmod +x "$MOCKBIN/agy"
out=$(echo "task de teste" | bash "$DELEGATE" --task implement --worktree "$REPO" --model agy - 2>"$TMP/err"); rc=$?
assert_eq "exit 0" "$rc" "0"
argv=$(cat "$AGY_ARGV_DUMP" 2>/dev/null)
grep -q '{worktree}' <<<"$argv" && fail "placeholder {worktree} não sobrou no comando" || ok "placeholder {worktree} não sobrou no comando"
assert_contains "--add-dir aponta pra worktree" "$argv" "\.delegate-wt"
assert_contains "prompt abre com o diretório de trabalho" "$argv" "^Diretório de trabalho: /"
grep -q 'Diretório de trabalho: .*/\.\./' <<<"$argv" && fail "caminho do prompt normalizado (sem /../)" || ok "caminho do prompt normalizado (sem /../)"
[[ ! -f "$REPO/worker-agy.txt" ]] && ok "árvore principal intocada" || fail "árvore principal intocada"

echo "T: one-shot não recebe o preâmbulo de worktree"
: > "$AGY_ARGV_DUMP"
run --task boilerplate - >/dev/null
grep -q 'Diretório de trabalho:' "$AGY_ARGV_DUMP" && fail "one-shot sem preâmbulo de worktree" || ok "one-shot sem preâmbulo de worktree"

echo "T: trunk do project.yaml com comentário inline resolve como base"
mkdir -p "$REPO/.claude"
printf 'repo:\n  trunk: main  # tronco de integração\n' > "$REPO/.claude/project.yaml"
git -C "$REPO" add .claude && git -C "$REPO" commit -qm project-yaml
out=$(echo "task de teste" | bash "$DELEGATE" --task implement --worktree "$REPO" --model agy - 2>"$TMP/err"); rc=$?
assert_eq "exit 0 com comentário no trunk" "$rc" "0"
assert_contains "base é o trunk limpo" "$out" "^base: main @"
rm -rf "$REPO/.claude"; git -C "$REPO" add -u .claude; git -C "$REPO" commit -qm sem-project-yaml

mock_agy   # volta ao padrão pros testes seguintes

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

echo "T: bulk-read — --paths + --question montam o prompt no lugar do heredoc"
run_nostdin() { bash "$DELEGATE" "$@" 2>"$TMP/err" </dev/null; }
A="$TMP/alfa.md"; printf 'conteudo-alfa\n' > "$A"
B="$TMP/beta.md"; printf 'conteudo-beta\n' > "$B"
out=$(run_nostdin --task scan --paths "$A" "$B" --question "o que isso faz")
assert_eq "sugar: exit 0" "$?" "0"
assert_contains "pergunta chega ao worker" "$out" "o que isso faz"
assert_contains "arquivo A em tag com o path" "$out" "path=.$A."
assert_contains "arquivo B em tag com o path" "$out" "path=.$B."
assert_contains "conteudo de A chega ao worker" "$out" "conteudo-alfa"
assert_contains "conteudo de B chega ao worker" "$out" "conteudo-beta"
assert_contains "contrato de saida em bullets" "$out" "bullets"
assert_contains "contrato proibe prosa" "$out" "prosa"
# footer de 3 seções pede verify e lista de arquivos tocados: em bulk one-shot
# isso é output token pago por relato de tarefa que não roda nem toca arquivo
[[ "$out" != *"Contrato de report"* ]] && ok "bulk one-shot não paga o footer de report" \
  || fail "bulk one-shot recebeu o footer de report"
out_hd=$(run --task scan -)
[[ "$out_hd" == *"Contrato de report"* ]] && ok "heredoc mantém o footer de report" \
  || fail "heredoc perdeu o footer de report"

run_nostdin --task scan --paths "$A" >/dev/null; rc=$?
assert_eq "--paths sem --question é erro de uso" "$rc" "1"
assert_contains "mensagem cita --question" "$(cat "$TMP/err")" "question"
run_nostdin --task scan --question "q" >/dev/null; rc=$?
assert_eq "--question sem --paths é erro de uso" "$rc" "1"
run_nostdin --task scan --paths "$TMP/nao-existe.md" --question "q" >/dev/null; rc=$?
assert_eq "path inexistente morre antes do worker" "$rc" "1"
assert_contains "mensagem cita o path que não existe" "$(cat "$TMP/err")" "nao-existe"

echo "T: heredoc puro segue idêntico (sem quebra pra chamador antigo)"
out=$(run --task scan -)
assert_eq "heredoc: exit 0" "$?" "0"
assert_contains "prompt do stdin chega ao worker" "$out" "prompt de teste"

echo "T: boilerplate sem --reference não sai (lição do code-write)"
run_nostdin --task boilerplate --paths "$A" --question "gera teste" >/dev/null; rc=$?
assert_eq "boilerplate em modo novo sem --reference: exit 1" "$rc" "1"
assert_contains "mensagem cita --reference" "$(cat "$TMP/err")" "reference"
out=$(run_nostdin --task boilerplate --paths "$A" --question "gera teste" --reference "$B")
assert_eq "boilerplate com --reference: exit 0" "$?" "0"
assert_contains "referência vai em tag própria" "$out" "reference path=.$B."
assert_contains "conteúdo da referência chega ao worker" "$out" "conteudo-beta"
run_nostdin --task boilerplate --paths "$A" --question "q" --reference "$TMP/nope.md" >/dev/null; rc=$?
assert_eq "--reference inexistente morre antes do worker" "$rc" "1"
out=$(run --task boilerplate -)
assert_eq "boilerplate por heredoc continua válido" "$?" "0"
out=$(run_nostdin --task scan --paths "$A" --question "q")
assert_eq "scan sem --reference continua válido" "$?" "0"

echo "T: o log grava tamanho e duração, e timeout/threshold param de ser opinião"
: > "$DELEGATE_GATE_DIR/delegate.log"
run_nostdin --task scan --paths "$A" "$B" --question "quanto pesa" >/dev/null
last=$(tail -1 "$DELEGATE_GATE_DIR/delegate.log")
jq -e '.bytes_in | numbers' <<<"$last" >/dev/null && ok "bytes_in é número" || fail "bytes_in é número ($last)"
jq -e '.bytes_out | numbers' <<<"$last" >/dev/null && ok "bytes_out é número" || fail "bytes_out é número ($last)"
[[ $(jq -r '.bytes_in' <<<"$last") -gt 0 ]] && ok "bytes_in maior que zero" || fail "bytes_in maior que zero ($last)"
[[ $(jq -r '.bytes_out' <<<"$last") -gt 0 ]] && ok "bytes_out maior que zero" || fail "bytes_out maior que zero ($last)"
jq -e '.dur_s | numbers' <<<"$last" >/dev/null && ok "dur_s é número (sem ele, .timeouts é palpite)" || fail "dur_s é número ($last)"
: > "$DELEGATE_GATE_DIR/delegate.log"
rm -f "$DELEGATE_GATE_DIR"/cooldown.*
MOCK_CODEX=fail MOCK_AGY=fail run --task scan - >/dev/null 2>&1
falha=$(tail -1 "$DELEGATE_GATE_DIR/delegate.log")
assert_contains "linha de falha ainda é JSONL válido" "$falha" "unavailable"
[[ $(jq -r '.bytes_out // 0' <<<"$falha") -eq 0 ]] && ok "falha não inventa bytes_out" || fail "falha inventou bytes_out ($falha)"
rm -f "$DELEGATE_GATE_DIR"/cooldown.*

echo "T: 404 de provider é janela ruim, não backend morto — cooldown curto"
mock_codex   # o peer-review trocou o mock; volta ao default, que traz o notfound
rm -f "$DELEGATE_GATE_DIR"/cooldown.*
out=$(MOCK_CODEX=notfound run --task "$CODEX_FIRST_TASK" -)
assert_eq "404 no 1o degrau: cascata desce e a task fecha" "$?" "0"
assert_contains "caiu pro agy" "$out" "agy-resposta"
[[ -f "$DELEGATE_GATE_DIR/cooldown.codex" ]] && ok "404 arma cooldown (janela ruim não se paga a cada chamada)" \
  || fail "404 não armou cooldown"
assert_contains "stderr nomeia a janela, não o backend morto" "$(cat "$TMP/err")" "transiente"
# cooldown de transiente é CURTO: janela ruim de provider passa sozinha
# expira pela mesma conta que o cooldown_remaining faz (COOLDOWN_MINS=60)
armed=$(cat "$DELEGATE_GATE_DIR/cooldown.codex")
rem=$(( armed + 60*60 - $(date +%s) ))
[[ $rem -gt 0 && $rem -le 600 ]] && ok "cooldown de transiente expira em <=10min, não nos 60 do rate limit" \
  || fail "cooldown de transiente não é curto (rem=${rem}s)"
rm -f "$DELEGATE_GATE_DIR"/cooldown.*
MOCK_CODEX=ratelimit run --task "$CODEX_FIRST_TASK" - >/dev/null
armed=$(cat "$DELEGATE_GATE_DIR/cooldown.codex" 2>/dev/null || echo 0)
rem=$(( armed + 60*60 - $(date +%s) ))
[[ $rem -gt 600 ]] && ok "rate limit real mantém o cooldown longo" || fail "rate limit perdeu o cooldown longo (rem=${rem}s)"
rm -f "$DELEGATE_GATE_DIR"/cooldown.*
# o backend segue habilitado: 404 não é decisão de policy
[[ "$(jq -r '.backends.codex.enabled' "$DELEGATE_POLICY")" == "true" ]] \
  && ok "404 não desabilita o backend na policy" || fail "backend foi desabilitado"

echo "T: review não rebaixa — cascata de review só tira da review_shelf (prateleira, 20/set/2026)"
SHELF=$(jq -r '.review_shelf.models[]' "$DELEGATE_POLICY" | sort)
[[ -n "$SHELF" ]] && ok "policy declara a review_shelf" || fail "review_shelf ausente: 'review não rebaixa' voltou a ser prosa"
fora=$(jq -r '.tasks.review[].model' "$DELEGATE_POLICY" | while read -r m; do
  grep -qxF "$m" <<<"$SHELF" || echo "$m"
done)
[[ -z "$fora" ]] && ok "review só usa modelo da review_shelf" \
  || fail "review usa modelo fora da review_shelf: $fora"
agy=$(jq -r '[.tasks.review[] | select(.backend=="agy")] | length' "$DELEGATE_POLICY")
[[ "$agy" == "0" ]] && ok "review não tem backend agy (nenhum modelo do agy revisa)" \
  || fail "review tem $agy entrada(s) de agy: review rebaixaria em cooldown"

echo "T: codex recebe modelo e esforço da entrada da cascata, não do config global do CLI"
rm -f "$DELEGATE_GATE_DIR"/cooldown.*
REV_MODEL=$(jq -r '[.tasks.review[] | select(.backend=="codex")][0].model' "$DELEGATE_POLICY")
REV_EFFORT=$(jq -r '[.tasks.review[] | select(.backend=="codex")][0].effort' "$DELEGATE_POLICY")
[[ -n "$REV_MODEL" && "$REV_MODEL" != "null" ]] && ok "policy nomeia modelo do codex em review" || fail "policy sem modelo do codex em review"
for e in $(jq -r '.suggested_effort | to_entries[] | select(.key|startswith("$")|not) | .value' "$DELEGATE_POLICY" | sort -u); do
  case "$e" in xhigh|max|ultra) fail "suggested_effort traz '$e', e xhigh/max/ultra estão fora por decisão" ;;
    *) ok "suggested_effort '$e' está dentro do teto" ;; esac
done
out=$(DELEGATE_SESSION_CLASS=nenhuma run --task review -)
assert_eq "exit 0" "$?" "0"
assert_contains "modelo vai no -m" "$out" "[-]m $REV_MODEL"
assert_contains "esforço vai no -c model_reasoning_effort" "$out" "model_reasoning_effort=$REV_EFFORT"
SCAN_EFFORT=$(jq -r '.tasks.scan[] | select(.backend=="codex") | .effort' "$DELEGATE_POLICY")
assert_eq "scan roda em low" "$SCAN_EFFORT" "low"
rm -f "$DELEGATE_GATE_DIR"/cooldown.*

echo "T: review espelha a classe da sessão master (review_pairing, 21/set/2026)"
# Fila fixa punia o dono: em sessão Fable o revisor saía de classe abaixo do master.
for cls in fable opus; do
  first=$(jq -r --arg c "$cls" '.review_pairing[$c][0]' "$DELEGATE_POLICY")
  eff=$(jq -r --arg m "$first" '.suggested_effort[$m] // empty' "$DELEGATE_POLICY")
  out=$(DELEGATE_SESSION_CLASS="$cls" run --task review -)
  assert_contains "sessão em $cls revisa no par de mesma classe ($first)" "$out" "[-]m $first"
  assert_contains "e no esforço sugerido dele ($eff)" "$out" "model_reasoning_effort=$eff"
  rm -f "$DELEGATE_GATE_DIR"/cooldown.*
done
fora=$(jq -r '[.review_pairing | to_entries[] | select(.key|startswith("$")|not) | .value[]] | unique
  - [.review_shelf.models[]] | .[]' "$DELEGATE_POLICY")
[[ -z "$fora" ]] && ok "todo modelo do review_pairing está na review_shelf" \
  || fail "review_pairing tem modelo fora da prateleira: $fora"
for cls in fable opus; do
  cruza=$(jq -r --arg c "$cls" '[.tasks.review[].model] - ([.tasks.review[].model] - .review_pairing[$c]) | length' "$DELEGATE_POLICY")
  [[ "$cruza" -gt 0 ]] && ok "review_pairing.$cls cruza com tasks.review (senão a cascata ficaria vazia)" \
    || fail "review_pairing.$cls não cruza com tasks.review"
done

echo "T: toda cascata termina no plano Claude antes de esgotar (o master é o fallback real, não o único)"
semclaude=$(jq -r '.tasks | to_entries[] | select((.value|type)=="array") | select(.value[-1].backend != "claude") | .key' "$DELEGATE_POLICY")
[[ -z "$semclaude" ]] && ok "último degrau de toda task é o backend claude" \
  || fail "task sem degrau Claude no fim: $semclaude"
ult=$(jq -r '.tiers | to_entries[] | select(.key|startswith("$")|not) | .value | to_entries[] | select(.value[-1].backend != "claude") | .key' "$DELEGATE_POLICY")
[[ -z "$ult" ]] && ok "último degrau de todo tier é o backend claude" || fail "tier sem degrau Claude no fim: $ult"

echo 'T: o worker nunca herda ANTHROPIC_API_KEY (senão o claude headless cobra da API em vez do plano)'
rm -f "$DELEGATE_GATE_DIR"/cooldown.*
out=$(ANTHROPIC_API_KEY=segredo-de-teste MOCK_CODEX=fail MOCK_CLAUDE=ok DELEGATE_SESSION_CLASS=nenhuma run --task review -)
assert_eq "exit 0 (degrau claude assumiu)" "$?" "0"
assert_contains "chave não chega ao worker" "$out" "key=unset"
grep -q "segredo-de-teste" <<<"$out" && fail "a chave da API vazou pro processo do worker" || ok "nenhum rastro da chave no worker"
rm -f "$DELEGATE_GATE_DIR"/cooldown.*

echo "T: --tier troca o ponto de entrada da cascata, e não o task-type (21/set/2026)"
AMPLO_1=$(jq -r '.tiers.implement.amplo[0].model' "$DELEGATE_POLICY")
PADRAO_1=$(jq -r '.tasks.implement[0].model' "$DELEGATE_POLICY")
[[ "$AMPLO_1" != "$PADRAO_1" ]] && ok "tier amplo entra por modelo diferente do padrão" \
  || fail "amplo e padrão entram pelo mesmo modelo: o tier não muda nada"
out=$(run --task implement --tier amplo -)
assert_contains "amplo entra no $AMPLO_1" "$out" "[-]m $AMPLO_1"
rm -f "$DELEGATE_GATE_DIR"/cooldown.*
out=$(run --task implement --tier padrao -)
assert_contains "padrão entra no $PADRAO_1" "$out" "[-]m $PADRAO_1"
rm -f "$DELEGATE_GATE_DIR"/cooldown.*
out=$(run --task implement -)
assert_contains "sem --tier resolve a mesma fila do padrão" "$out" "[-]m $PADRAO_1"
rm -f "$DELEGATE_GATE_DIR"/cooldown.*
run_nostdin --task implement --tier gigante --paths "$A" --question "q" >/dev/null 2>&1; rc=$?
assert_eq "tier inválido é erro de uso (exit 1), não fila silenciosa" "$rc" "1"
[[ "$(jq -r '.tiers.implement | keys | join(",")' "$DELEGATE_POLICY")" == "amplo" ]] \
  && ok "só o amplo é declarado em tiers (padrão é tasks.<task>, sem lista gêmea pra divergir)" \
  || fail "tiers declara mais que amplo: duas listas da mesma fila divergem"

echo "T: scan e boilerplate têm a mesma cascata de propósito, e o teste cobra a não divergência"
jq -e '.tasks.scan == .tasks.boilerplate' "$DELEGATE_POLICY" >/dev/null \
  && ok "scan e boilerplate não divergiram" \
  || fail "scan e boilerplate divergiram: ou unifica, ou o motivo vai escrito no \$comment"
grep -q 'exige --reference' "$DELEGATE"  \
  && ok "boilerplate segue portando a guarda de --reference (é o que o separa do scan)" \
  || fail "a guarda de --reference morreu: aí os dois task-types viram um só"

echo "T: toda entrada de cascata roda no esforço sugerido do modelo dela"
# Cobre tasks e tiers nos três backends. Modelo fora do suggested_effort (agy, que
# carrega o esforço no próprio nome) passa: sem sugestão não há divergência.
diverg=$(jq -r '[(.tasks|to_entries[]|select((.value|type)=="array")|.value[]),
   (.tiers|to_entries[]|select(.key|startswith("$")|not)|.value|to_entries[]|.value[])]
  | map(select(.effort != ($suge[.model] // .effort)))
  | .[] | "\(.backend)/\(.model) usa \(.effort), sugerido \($suge[.model])"' \
  --argjson suge "$(jq -c '.suggested_effort | with_entries(select(.key|startswith("$")|not))' "$DELEGATE_POLICY")" \
  "$DELEGATE_POLICY")
[[ -z "$diverg" ]] && ok "nenhuma entrada diverge do esforço sugerido" || fail "entrada divergindo: $diverg"

echo ""
echo "== $PASS passed, $FAIL failed =="
[[ $FAIL -eq 0 ]]
