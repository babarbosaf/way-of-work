#!/usr/bin/env bash
# Suíte do delegate.sh. Mocks de CLI antepostos ao PATH;
# nenhum worker real é invocado. Uso: bash tests/delegate.test.sh
set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DELEGATE="$HERE/../scripts/delegate.sh"
SMOKE="$HERE/../skills/delegate/scripts/smoke_backends.sh"
LIMITES="$HERE/../skills/delegate/scripts/lib-limites.sh"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

PASS=0; FAIL=0
ok()   { PASS=$((PASS+1)); echo "  ✓ $1"; }
fail() { FAIL=$((FAIL+1)); echo "  ✗ $1"; }
assert_eq() { [[ "$2" == "$3" ]] && ok "$1" || fail "$1 (esperado='$3' obtido='$2')"; }
# -e porque padrão que começa com hífen (--model, por exemplo) senão vira opção do grep.
assert_contains() { grep -qe "$3" <<<"$2" && ok "$1" || fail "$1 (não contém '$3')"; }

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
  tierreset) echo "quota exceeded; reset at 2100-01-01T00:00:00Z"; exit 1 ;;
  tierunreadable) echo "quota exceeded; reset em breve"; exit 1 ;;
  timeout) exit 124 ;;
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
  timeout) exit 124 ;;
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
# A policy do teste é a do repo com a régua de balde levantada: a suíte dispara
# dezenas de chamadas em segundos, e a régua real (pico de 30 dias) esgotaria no
# meio da rodada, fazendo todo teste seguinte medir o gate em vez do que ele quer
# medir. Quem exercita o gate baixa a régua no próprio bloco.
# `_probe` existe porque as provas de MECÂNICA de cascata (desce por falha, arma
# castigo, pula por saldo) precisam de uma fila com três backends distinguíveis, e
# não podem quebrar toda vez que o dono reordena uma fila real por medição. Ela é
# montada com as entradas de verdade da implementação, só reagrupadas, então
# continua satisfazendo todo invariante que a policy cobra. A ordem que a
# implementação declara é cobrada em assert próprio, com outro nome.
policy_fresh() {
  jq '.budgets.pools |= with_entries(.value.max_calls = 9999)
      | .tasks._probe = ([.tasks.implement[] | select(.backend == "codex")]
                       + [.tasks.implement[] | select(.backend == "agy")]
                       + [.tasks.implement[] | select(.backend == "claude")])' \
    "$HERE/../config/model-policy.json" > "$DELEGATE_POLICY"
}
policy_fresh

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
policy_fresh

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

echo "T: a árvore de trabalho nasce fora do repositório, e o lugar é dado"
# Medido em 21/set/2026: o worker do plano principal recusa escrita dentro deste
# repo, porque o repo é o diretório de configuração dele e ele trata isso como
# caminho sensível, sem pedir confirmação. Árvore dentro do repo deixa aquele
# degrau sem como rodar, e é ele que vai liderar a fila de implementação.
export DELEGATE_WT_ROOT="$TMP/arvores"
out=$(echo "task de teste" | bash "$DELEGATE" --task implement --worktree "$REPO" - 2>"$TMP/err"); rc=$?
assert_eq "exit 0 com árvore fora do repo" "$rc" "0"
wt_path=$(sed -n 's/^worktree: //p' <<<"$out" | head -1)
[[ -n "$wt_path" ]] && ok "o report nomeia o caminho da árvore" || fail "o report não nomeia o caminho da árvore"
[[ "$wt_path" == "$TMP/arvores"/* ]] && ok "a árvore nasceu no lugar declarado" \
  || fail "a árvore ignorou o lugar declarado (nasceu em $wt_path)"
REPO_REAL=$(cd "$REPO" && pwd)
case "$wt_path" in "$REPO_REAL"/*) fail "a árvore nasceu dentro do repositório" ;; *) ok "nenhuma árvore dentro do repositório" ;; esac
[[ ! -d "$REPO/.delegate-wt" ]] && ok "o repo não ganhou diretório de árvore" || fail "o repo ganhou .delegate-wt"

echo "T: a limpeza acha árvore no lugar novo e no antigo"
gc_out=$(bash "$DELEGATE" --gc "$REPO" 2>&1)
assert_contains "a limpeza lista a branch de delegação" "$gc_out" "delegate/"
unset DELEGATE_WT_ROOT

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
policy_fresh
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
# sem o modelo no log, dur_s não se atribui a ninguém: o pool do codex é "codex"
# pros quatro modelos dele, e recalibrar .timeouts era palpite de novo.
MOD=$(jq -r '.tasks.scan[0].model' "$DELEGATE_POLICY")
assert_contains "o log nomeia o modelo que respondeu" "$last" "model=$MOD"
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
# Cooldown transiente expira em minutos, conforme a policy.
armed=$(cat "$DELEGATE_GATE_DIR/cooldown.codex")
rem=$(( ${armed#expiry:} - $(date +%s) ))
transient_secs=$(( $(jq -r '.cooldowns.transient_mins' "$DELEGATE_POLICY") * 60 ))
[[ $rem -gt 0 && $rem -le $transient_secs ]] && ok "cooldown de transiente expira no prazo da policy" \
  || fail "cooldown de transiente não é curto (rem=${rem}s)"
rm -f "$DELEGATE_GATE_DIR"/cooldown.*
MOCK_CODEX=ratelimit run --task "$CODEX_FIRST_TASK" - >/dev/null
armed=$(cat "$DELEGATE_GATE_DIR/cooldown.codex" 2>/dev/null || echo 0)
rem=$(( ${armed#expiry:} - $(date +%s) ))
rate_secs=$(( $(jq -r '.cooldowns.rate_limit_mins' "$DELEGATE_POLICY") * 60 ))
[[ $rem -gt 0 && $rem -le $rate_secs ]] && ok "rate limit por minuto usa o prazo da policy" || fail "rate limit não usa o prazo da policy (rem=${rem}s)"
rm -f "$DELEGATE_GATE_DIR"/cooldown.*
# o backend segue habilitado: 404 não é decisão de policy
[[ "$(jq -r '.backends.codex.enabled' "$DELEGATE_POLICY")" == "true" ]] \
  && ok "404 não desabilita o backend na policy" || fail "backend foi desabilitado"

echo "T: limite de tier respeita o reset declarado; reset ilegível cai no prazo longo"
rm -f "$DELEGATE_GATE_DIR"/cooldown.*
MOCK_CODEX=tierreset run --task "$CODEX_FIRST_TASK" - >/dev/null
armed=$(cat "$DELEGATE_GATE_DIR/cooldown.codex")
[[ "$armed" == "expiry:4102444800" ]] && ok "reset declarado arma até a hora informada" \
  || fail "reset declarado não virou a expiração informada ($armed)"
rm -f "$DELEGATE_GATE_DIR"/cooldown.*
MOCK_CODEX=tierunreadable run --task "$CODEX_FIRST_TASK" - >/dev/null
armed=$(cat "$DELEGATE_GATE_DIR/cooldown.codex")
rem=$(( ${armed#expiry:} - $(date +%s) ))
fallback_secs=$(( $(jq -r '.cooldowns.tier_fallback_mins' "$DELEGATE_POLICY") * 60 ))
[[ $rem -gt 0 && $rem -le $fallback_secs ]] && ok "reset ilegível cai no prazo longo da policy" \
  || fail "reset ilegível não caiu no prazo longo da policy (rem=${rem}s)"
rm -f "$DELEGATE_GATE_DIR"/cooldown.*

echo "T: timeout da sonda é tropeço de provider e usa o prazo transiente"
MOCK_AGY=timeout bash "$SMOKE" --task scan >/dev/null 2>&1 || true
armed=$(cat "$DELEGATE_GATE_DIR/cooldown.agy:gemini")
rem=$(( ${armed#expiry:} - $(date +%s) ))
[[ $rem -gt 0 && $rem -le $transient_secs ]] && ok "sonda classifica rc=124 como transiente" \
  || fail "sonda não aplicou prazo transiente ao rc=124 (rem=${rem}s)"
rm -f "$DELEGATE_GATE_DIR"/cooldown.*

echo "T: a fila de implementação lidera pelo plano principal, e só ela mudou"
# A ordem só pôde virar depois de o caminho do plano principal rodar pelo próprio
# despachante em árvore isolada, medido em 21/set/2026: status ok, pool claude,
# dur_s 18. Antes disso o primeiro lugar seria um degrau que nunca rodou.
[[ "$(jq -r '.tasks.implement[0].backend' "$HERE/../config/model-policy.json")" == "claude" ]] \
  && ok "implementação lidera pelo balde do plano principal" \
  || fail "implementação lidera por $(jq -r '.tasks.implement[0].backend' "$DELEGATE_POLICY")"
for fila in review scan boilerplate; do
  primeiro=$(jq -r --arg f "$fila" '.tasks[$f][0].backend' "$DELEGATE_POLICY")
  [[ "$primeiro" != "claude" ]] && ok "a fila $fila não teve a ordem alterada (lidera $primeiro)" \
    || fail "a fila $fila virou de ordem, e este ticket é só da implementação"
done
# Esgotar o balde do topo não pode custar a task: o gate desce sem gastar chamada.
rm -f "$DELEGATE_GATE_DIR"/cooldown.*
jq '.budgets.pools.claude = {"max_calls": 0}' "$DELEGATE_POLICY" > "$TMP/pol-lider.json" \
  && mv "$TMP/pol-lider.json" "$DELEGATE_POLICY"
out=$(run --task implement -)
assert_eq "exit 0 com o balde do líder esgotado" "$?" "0"
grep -q "claude-resposta" <<<"$out" && fail "o líder foi invocado com o balde esgotado" \
  || ok "líder esgotado não gasta chamada"
[[ -n "$out" ]] && ok "o mesmo trabalho fechou no degrau seguinte" || fail "nenhum degrau assumiu"
policy_fresh
rm -f "$DELEGATE_GATE_DIR"/cooldown.* "$DELEGATE_GATE_DIR/delegate.log"

echo "T: balde sem saldo na janela desce a cascata sem gastar chamada"
# A cascata só descia por falha, então descobrir que um balde acabou custava uma
# chamada perdida. O gate consulta o saldo antes de invocar, e pular por saldo é
# o mesmo movimento de pular por castigo.
semeia_log() { # pool quantidade
  local i n="$2"; [[ "$n" =~ ^[0-9]+$ ]] || n=0
  rm -f "$DELEGATE_GATE_DIR/delegate.log"
  for ((i=0; i<n; i++)); do
    jq -cn --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" --arg pool "$1" \
      '{ts:$ts,task:"implement",backend:"x",status:"ok",detail:"",pool:$pool,bytes_in:0,bytes_out:0,dur_s:1}' \
      >> "$DELEGATE_GATE_DIR/delegate.log"
  done
}
jq '.budgets.pools.codex.max_calls = 2' "$DELEGATE_POLICY" > "$TMP/pol-orc.json" \
  && mv "$TMP/pol-orc.json" "$DELEGATE_POLICY"
TETO_CODEX=$(jq -r '.budgets.pools.codex.max_calls' "$DELEGATE_POLICY")
[[ "$TETO_CODEX" =~ ^[0-9]+$ ]] && ok "a régua do balde é dado na policy" \
  || fail "policy não declara régua de balde (max_calls=$TETO_CODEX)"
rm -f "$DELEGATE_GATE_DIR"/cooldown.*
semeia_log codex "$TETO_CODEX"
out=$(run --task "$CODEX_FIRST_TASK" -)
assert_eq "exit 0: a task fechou no degrau de baixo" "$?" "0"
assert_contains "quem respondeu foi o agy, não o codex" "$out" "agy-resposta"
grep -q "codex-resposta" <<<"$out" && fail "o codex foi invocado apesar de estar sem saldo" \
  || ok "nenhuma chamada gasta no balde sem saldo"
assert_contains "o motivo do pulo aparece" "$(cat "$TMP/err")" "sem saldo"

echo "T: o log diz qual balde levou a chamada e quanto restava dele"
saldo_gravado=$(grep -o 'saldo=[^"]*' "$DELEGATE_GATE_DIR/delegate.log" | tail -1)
[[ -n "$saldo_gravado" ]] && ok "log grava o saldo da hora da escolha ($saldo_gravado)" \
  || fail "log não grava saldo nenhum"

echo "T: log ilegível vale como balde livre, e a fila volta a descer por falha"
printf 'isto nao e json\n{quebrado\n' > "$DELEGATE_GATE_DIR/delegate.log"
out=$(run --task "$CODEX_FIRST_TASK" -)
assert_eq "exit 0 com log ilegível" "$?" "0"
assert_contains "o topo da fila foi invocado normalmente" "$out" "codex-resposta"

echo "T: todos os baldes sem saldo entrega pra sessão com o exit de fila esgotada"
rm -f "$DELEGATE_GATE_DIR"/cooldown.* "$DELEGATE_GATE_DIR/delegate.log"
jq '.budgets.pools |= with_entries(.value.max_calls = 1)' "$DELEGATE_POLICY" > "$TMP/pol-orc.json" \
  && mv "$TMP/pol-orc.json" "$DELEGATE_POLICY"
for pool in $(jq -r '.budgets.pools | keys[]' "$DELEGATE_POLICY"); do
  teto=$(jq -r --arg p "$pool" '.budgets.pools[$p].max_calls // 0' "$DELEGATE_POLICY")
  [[ "$teto" =~ ^[0-9]+$ ]] || continue
  for ((i=0; i<teto; i++)); do
    jq -cn --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" --arg pool "$pool" \
      '{ts:$ts,task:"implement",backend:"x",status:"ok",detail:"",pool:$pool,bytes_in:0,bytes_out:0,dur_s:1}' \
      >> "$DELEGATE_GATE_DIR/delegate.log"
  done
done
run --task "$CODEX_FIRST_TASK" - >/dev/null; rc=$?
assert_eq "exit 2, o mesmo de fila esgotada, e não erro" "$rc" "2"
assert_contains "a sessão é avisada que assume" "$(cat "$TMP/err")" "A sessão assume"

echo "T: o gate nunca rebaixa a revisão pra classe abaixo da sessão que pediu"
# Com pareamento, a cascata de review só tem entrada da classe da sessão. Balde
# sem saldo tem que esgotar a fila, nunca escorregar pra um modelo de fora dela.
rm -f "$DELEGATE_GATE_DIR"/cooldown.*
CLS=$(jq -r '.review_pairing | keys[] | select(startswith("$") | not)' "$DELEGATE_POLICY" | head -1)
PAR=$(jq -r --arg c "$CLS" '.review_pairing[$c] | join(" ")' "$DELEGATE_POLICY")
out=$(DELEGATE_SESSION_CLASS="$CLS" run --task review - 2>/dev/null)
fora=""
for m in $(jq -r '.tasks.review[].model' "$DELEGATE_POLICY"); do
  grep -q "\[$m\]" <<<"$out" && [[ " $PAR " != *" $m "* ]] && fora="$m"
done
[[ -z "$fora" ]] && ok "nenhum modelo fora do pareamento da classe $CLS respondeu" \
  || fail "o gate rebaixou a revisão pro modelo $fora, fora da classe $CLS"
rm -f "$DELEGATE_GATE_DIR"/cooldown.* "$DELEGATE_GATE_DIR/delegate.log"
policy_fresh

echo "T: o classificador ancora no vocabulário de limite, e não em palavra solta"
# Worker que falha imprimindo comando de git levava 60min de castigo num balde
# são: o regex de cota casava a palavra "reset" em qualquer contexto. Achado na
# integração do ticket 01, 21/set/2026.
source "$LIMITES"; limites_configurar "$DELEGATE_POLICY" "$DELEGATE_GATE_DIR"
classe_de() { local f="$TMP/classe.txt"; printf '%s\n' "$1" > "$f"; classificar_limite "$f"; }
[[ "$(classe_de 'resolve com: git reset --hard origin/main')" == desconhecido ]] \
  && ok "output que só menciona reset não é cota de tier" \
  || fail "palavra reset solta virou $(classe_de 'resolve com: git reset --hard origin/main')"
[[ "$(classe_de 'usage limit reached, request timed out')" == tier_quota ]] \
  && ok "cota esgotada continua cota mesmo dizendo timeout" \
  || fail "cota com timeout na mensagem virou $(classe_de 'usage limit reached, request timed out')"
[[ "$(classe_de '429 too many requests: rate limit')" == rate_limit ]] \
  && ok "rate limit por minuto segue rate limit" || fail "rate limit foi reclassificado"
[[ "$(classe_de 'status 404: model does not exist or you do not have access')" == transiente ]] \
  && ok "404 de janela ruim segue transiente" || fail "404 foi reclassificado"
[[ "$(classe_de '5-hour limit reached; resets at 2026-09-21T23:00:00Z')" == tier_quota ]] \
  && ok "limite com hora de reset é cota de tier" || fail "limite com reset não é cota"

echo "T: policy sem cooldowns falha alto, nunca cai calada em outra policy"
# Rede de segurança que lê OUTRO arquivo faz todo teste com policy própria medir
# o número do repo sem avisar: o assert fica verde provando nada.
echo '{"tasks":{}}' > "$TMP/pol-sem-cooldown.json"
( LIMITES_DEFAULT_POLICY="$HERE/../config/model-policy.json" \
  limites_configurar "$TMP/pol-sem-cooldown.json" "$DELEGATE_GATE_DIR" ) \
  && fail "policy sem cooldowns passou, e o prazo veio de outro arquivo" \
  || ok "policy sem cooldowns não passa"
limites_configurar "$DELEGATE_POLICY" "$DELEGATE_GATE_DIR"

echo "T: rc=124 é tropeço de provider nos DOIS invocadores, não só na sonda"
rm -f "$DELEGATE_GATE_DIR"/cooldown.*
MOCK_CODEX=timeout run --task "$CODEX_FIRST_TASK" - >/dev/null 2>&1
armed=$(cat "$DELEGATE_GATE_DIR/cooldown.codex" 2>/dev/null || echo "expiry:0")
rem=$(( ${armed#expiry:} - $(date +%s) ))
[[ $rem -gt 0 && $rem -le $transient_secs ]] \
  && ok "despachante classifica rc=124 como transiente, igual à sonda" \
  || fail "despachante não armou prazo transiente no rc=124 (rem=${rem}s)"
rm -f "$DELEGATE_GATE_DIR"/cooldown.*

echo "T: os dois invocadores usam o mesmo classificador de limites"
for invoker in "$DELEGATE" "$SMOKE"; do
  grep -q 'lib-limites.sh' "$invoker" && ok "$(basename "$invoker") sourceia a biblioteca" \
    || fail "$(basename "$invoker") não sourceia a biblioteca"
  grep -Eq '^(is_ratelimit|is_transient|classificar_limite)\(\)' "$invoker" \
    && fail "$(basename "$invoker") ainda classifica limite sozinho" \
    || ok "$(basename "$invoker") não classifica limite sozinho"
done
[[ -f "$LIMITES" ]] && ok "biblioteca de limites existe" || fail "biblioteca de limites ausente"

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
# classe nova entra só pela policy: o script não pode ter a lista de classes.
jq '.review_pairing.sonnet = [.review_shelf.models[0]]' "$DELEGATE_POLICY" > "$TMP/pol-classe.json"
out=$(DELEGATE_POLICY="$TMP/pol-classe.json" DELEGATE_SESSION_CLASS=claude-sonnet-5 run --task review -)
assert_contains "classe declarada só na policy já pareia, sem editar o script" "$(cat "$TMP/err")" "classe da sessão (sonnet)"
rm -f "$DELEGATE_GATE_DIR"/cooldown.*
fora=$(jq -r '[.review_pairing | to_entries[] | select(.key|startswith("$")|not) | .value[]] | unique
  - [.review_shelf.models[]] | .[]' "$DELEGATE_POLICY")
[[ -z "$fora" ]] && ok "todo modelo do review_pairing está na review_shelf" \
  || fail "review_pairing tem modelo fora da prateleira: $fora"
for cls in fable opus; do
  cruza=$(jq -r --arg c "$cls" '[.tasks.review[].model] - ([.tasks.review[].model] - .review_pairing[$c]) | length' "$DELEGATE_POLICY")
  [[ "$cruza" -gt 0 ]] && ok "review_pairing.$cls cruza com tasks.review (senão a cascata ficaria vazia)" \
    || fail "review_pairing.$cls não cruza com tasks.review"
done

echo "T: o plano Claude está em toda cascata (o master é o fallback real, não o único)"
# A régua era "último degrau é claude", e ela codificava que o plano do dono
# sempre fecha o trabalho. Com o gate de saldo isso mudou de lugar: cascata
# esgotada já entrega pra sessão com exit 2, e a fila de implementação passou a
# LIDERAR pelo plano, o que é mais forte que fechar com ele. O que segue valendo,
# e é o que este assert cobra, é o plano aparecer em toda cascata.
semclaude=$(jq -r '.tasks | to_entries[] | select((.value|type)=="array") | select([.value[].backend] | index("claude") | not) | .key' "$DELEGATE_POLICY")
[[ -z "$semclaude" ]] && ok "toda task tem o backend claude em algum degrau" \
  || fail "task sem degrau Claude: $semclaude"
ult=$(jq -r '.tiers | to_entries[] | select(.key|startswith("$")|not) | .value | to_entries[] | select(.value[-1].backend != "claude") | .key' "$DELEGATE_POLICY")
[[ -z "$ult" ]] && ok "último degrau de todo tier é o backend claude" || fail "tier sem degrau Claude no fim: $ult"

echo 'T: o worker nunca herda ANTHROPIC_API_KEY (senão o claude headless cobra da API em vez do plano)'
rm -f "$DELEGATE_GATE_DIR"/cooldown.*
out=$(ANTHROPIC_API_KEY=segredo-de-teste MOCK_CODEX=fail MOCK_CLAUDE=ok DELEGATE_SESSION_CLASS=nenhuma run --task review -)
assert_eq "exit 0 (degrau claude assumiu)" "$?" "0"
assert_contains "chave não chega ao worker" "$out" "key=unset"
grep -q "segredo-de-teste" <<<"$out" && fail "a chave da API vazou pro processo do worker" || ok "nenhum rastro da chave no worker"
rm -f "$DELEGATE_GATE_DIR"/cooldown.*
# A guarda é da regra, não do delegate.sh: quem invoca backend da policy invoca
# `claude -p`, e o smoke_backends sonda TODO backend habilitado. Uma cópia sem
# guarda cobra da API calada, então o teste cobra todo invocador, não um.
for inv in "$HERE/../skills/delegate/scripts/delegate.sh" "$HERE/../skills/delegate/scripts/smoke_backends.sh"; do
  nome=$(basename "$inv")
  nuas=$(grep -nE '(^|[^-])\btimeout [0-9$]|\$TIMEOUT_CMD' "$inv" | grep -v 'env -u ANTHROPIC_API_KEY' | grep -vE '^\s*[0-9]+:\s*#|TIMEOUT_CMD=')
  [[ -z "$nuas" ]] && ok "$nome invoca worker sempre com env -u ANTHROPIC_API_KEY" \
    || fail "$nome tem invocação sem a guarda da chave: $nuas"
done

echo "T: --tier troca o ponto de entrada da cascata, e não o task-type (21/set/2026)"
AMPLO_1=$(jq -r '.tiers.implement.amplo[0].model' "$DELEGATE_POLICY")
PADRAO_1=$(jq -r '.tasks.implement[0].model' "$DELEGATE_POLICY")
# A flag do modelo é por backend (-m no codex, --model nos outros), e desde que a
# implementação lidera pelo plano principal os dois pontos de entrada da fila não
# usam mais a mesma flag. Cravar "-m" media o backend, não o ponto de entrada.
flag_de() { jq -r --arg m "$1" '[.tasks.implement[], .tiers.implement.amplo[]]
  | map(select(.model == $m)) | .[0].backend as $b | $b' "$DELEGATE_POLICY" \
  | xargs -I{} jq -r --arg b {} '.backends[$b].model_flag // "-m"' "$DELEGATE_POLICY"; }
AMPLO_FLAG=$(flag_de "$AMPLO_1"); PADRAO_FLAG=$(flag_de "$PADRAO_1")
[[ "$AMPLO_1" != "$PADRAO_1" ]] && ok "tier amplo entra por modelo diferente do padrão" \
  || fail "amplo e padrão entram pelo mesmo modelo: o tier não muda nada"
out=$(MOCK_CLAUDE=ok run --task implement --tier amplo -)
assert_contains "amplo entra no $AMPLO_1" "$out" "$AMPLO_FLAG $AMPLO_1"
rm -f "$DELEGATE_GATE_DIR"/cooldown.*
out=$(MOCK_CLAUDE=ok run --task implement --tier padrao -)
assert_contains "padrão entra no $PADRAO_1" "$out" "$PADRAO_FLAG $PADRAO_1"
rm -f "$DELEGATE_GATE_DIR"/cooldown.*
out=$(MOCK_CLAUDE=ok run --task implement -)
assert_contains "sem --tier resolve a mesma fila do padrão" "$out" "$PADRAO_FLAG $PADRAO_1"
rm -f "$DELEGATE_GATE_DIR"/cooldown.*
run_nostdin --task implement --tier gigante --paths "$A" --question "q" >/dev/null 2>&1; rc=$?
assert_eq "tier inválido é erro de uso (exit 1), não fila silenciosa" "$rc" "1"
assert_contains "a mensagem lista os tiers que a policy declara, não um literal do script" "$(cat "$TMP/err")" "padrao|amplo"
run_nostdin --task scan --tier amplo --paths "$A" --question "q" >/dev/null 2>&1; rc=$?
assert_eq "tier que a task não declara é erro, e não fila padrão calada" "$rc" "1"
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

echo "T: apurador lê histórico sem invocar worker"
APURADOR="$HERE/../skills/delegate/scripts/apura_log.py"
APURA_LOG="$TMP/apura.log"
APURA_POLICY="$TMP/apura-policy.json"
cat > "$APURA_LOG" <<'EOF'
{"ts":"2026-09-20T00:00:00Z","task":"scan","backend":"codex","status":"ok","detail":"model=m1","pool":"codex","bytes_in":1,"bytes_out":1,"dur_s":10}
{"ts":"2026-09-20T01:00:00Z","task":"scan","backend":"codex","status":"ok","detail":"model=m1","pool":"codex","bytes_in":1,"bytes_out":1,"dur_s":12}
{"ts":"2026-09-20T06:01:00Z","task":"scan","backend":"codex","status":"ok","detail":"model=m1","pool":"codex","bytes_in":1,"bytes_out":1,"dur_s":9}
{"ts":"2026-09-20T02:00:00Z","task":"scan","backend":"agy","status":"ok","detail":"model=gm","pool":"agy:gemini","bytes_in":1,"bytes_out":1,"dur_s":8}
{"ts":"2026-09-20T02:01:00Z","task":"review","backend":"codex","status":"ok","detail":"model=m1","pool":"codex","bytes_in":1,"bytes_out":1,"dur_s":20}
{"ts":"2026-09-20T02:02:00Z","task":"review","backend":"codex","status":"ok","detail":"model=m1","pool":"codex","bytes_in":1,"bytes_out":1,"dur_s":20}
{"ts":"2026-09-20T02:03:00Z","task":"review","backend":"codex","status":"ok","detail":"model=m1","pool":"codex","bytes_in":1,"bytes_out":1,"dur_s":20}
{"ts":"2026-09-20T02:04:00Z","task":"review","backend":"codex","status":"ok","detail":"model=m1","pool":"codex","bytes_in":1,"bytes_out":1,"dur_s":20}
{"ts":"2026-09-20T02:05:00Z","task":"review","backend":"codex","status":"ok","detail":"model=m1","pool":"codex","bytes_in":1,"bytes_out":1,"dur_s":20}
{"ts":"2026-09-20T02:06:00Z","task":"review","backend":"codex","status":"ok","detail":"model=m1","pool":"codex","bytes_in":1,"bytes_out":1,"dur_s":20}
{"ts":"2026-09-20T02:07:00Z","task":"review","backend":"codex","status":"ok","detail":"model=m1","pool":"codex","bytes_in":1,"bytes_out":1,"dur_s":20}
{"ts":"2026-09-20T02:08:00Z","task":"review","backend":"codex","status":"ok","detail":"model=m1","pool":"codex","bytes_in":1,"bytes_out":1,"dur_s":20}
{"ts":"2026-09-20T02:09:00Z","task":"review","backend":"codex","status":"ok","detail":"model=m1","pool":"codex","bytes_in":1,"bytes_out":1,"dur_s":20}
{"ts":"2026-09-19T00:00:00Z","task":"scan","backend":"codex","status":"ok","detail":"model=m1","pool":"codex","bytes_in":1,"bytes_out":1,"dur_s":4}
{"ts":"2026-09-19T01:00:00Z","task":"scan","backend":"codex","status":"ok","detail":"model=m1","pool":"codex","bytes_in":1,"bytes_out":1,"dur_s":4}
{"ts":"2026-09-19T02:00:00Z","task":"scan","backend":"codex","status":"ok","detail":"model=m1","pool":"codex","bytes_in":1,"bytes_out":1,"dur_s":4}
{"ts":"2026-09-19T03:00:00Z","task":"scan","backend":"codex","status":"ok","detail":"model=m1","pool":"codex","bytes_in":1,"bytes_out":1,"dur_s":4}
{"ts":"2026-09-19T04:00:00Z","task":"scan","backend":"codex","status":"ok","detail":"model=m1","pool":"codex","bytes_in":1,"bytes_out":1,"dur_s":4}
{"ts":"2026-09-19T05:00:00Z","task":"scan","backend":"codex","status":"ok","detail":"model=m1","pool":"codex","bytes_in":1,"bytes_out":1,"dur_s":4}
{"ts":"2026-09-20T02:10:00Z","task":"scan","backend":"agy","status":"unavailable","detail":"model=fantasma","pool":"agy:gemini","bytes_in":1,"bytes_out":0,"dur_s":1}
EOF
cat > "$APURA_POLICY" <<'EOF'
{"budgets":{"window_mins":300,"pools":{"codex":{"max_calls":11},"agy:gemini":{"max_calls":1},"agy:claude_gpt":{"status":"sem_amostra"},"claude":{"status":"sem_amostra"}}},"timeouts":{"scan":24,"review":600},"tasks":{"scan":[{"backend":"codex","model":"m1"},{"backend":"agy","model":"fantasma"}],"review":[{"backend":"codex","model":"m1"}]},"tiers":{"implement":{"amplo":[{"backend":"claude","model":"ausente"}]}}}
EOF
apurado=$(python3 "$APURADOR" --log "$APURA_LOG" --policy "$APURA_POLICY")
assert_eq "apurador sai 0" "$?" "0"
jq -e '.budgets.pools.codex.max_calls == 11 and .timeouts.scan.seconds == 24 and .timeouts.scan.status == "medido" and .timeouts.review.status == "estimativa"' <<<"$apurado" >/dev/null \
  && ok "pico e teto medido, revisão estimada" || fail "pico, teto ou estimativa incorretos: $apurado"
assert_contains "lista modelo nunca invocado" "$apurado" "fantasma"
assert_contains "lista degrau de tier nunca invocado" "$apurado" "ausente"
python3 "$APURADOR" --check --log "$APURA_LOG" --policy "$APURA_POLICY" >/dev/null
assert_eq "--check aceita policy apurada" "$?" "0"

# O detail de verdade não é só "model=X": em modo worktree ele carrega branch, e
# desde o gate de saldo carrega saldo também. Fixture com a forma curta deixa o
# extrator de modelo passar verde provando nada, e aí degrau JÁ provado aparece
# como buraco, que é o pior erro possível pra quem vai virar a ordem da fila.
APURA_LOG2="$TMP/apura-real.log"
cat > "$APURA_LOG2" <<'EOF'
{"ts":"2026-09-20T03:00:00Z","task":"implement","backend":"codex","status":"ok","detail":"model=m1 branch=delegate/implement-123 saldo=8","pool":"codex","bytes_in":1,"bytes_out":1,"dur_s":30}
{"ts":"2026-09-20T03:10:00Z","task":"implement","backend":"codex","status":"empty_diff","detail":"model=m1 branch=delegate/implement-124 base=main saldo=7","pool":"codex","bytes_in":1,"bytes_out":0,"dur_s":99999}
EOF
cat > "$TMP/apura-policy2.json" <<'EOF'
{"budgets":{"window_mins":300,"pools":{"codex":{"max_calls":2}}},"timeouts":{"implement":60},"tasks":{"implement":[{"backend":"codex","model":"m1"}]}}
EOF
apurado2=$(python3 "$APURADOR" --log "$APURA_LOG2" --policy "$TMP/apura-policy2.json")
grep -q '"model": "m1"' <<<"$apurado2" \
  && fail "degrau já invocado apareceu como não provado: o extrator de modelo engoliu o resto do detail" \
  || ok "detail com branch e saldo ainda prova o degrau"
jq -e '[.unproven_entries[]] | length == 0' <<<"$apurado2" >/dev/null \
  && ok "nenhum degrau provado entra na lista de não provados" \
  || fail "lista de não provados tem entrada provada: $apurado2"
jq -e '.timeouts.implement.calls == 1' <<<"$apurado2" >/dev/null \
  && ok "chamada de diff vazio não entra na amostra de duração" \
  || fail "empty_diff contado como chamada que terminou bem: $(jq -c .timeouts <<<"$apurado2")"

jq '.budgets.pools.codex.max_calls = 9' "$APURA_POLICY" > "$TMP/apura-policy-divergente.json"
python3 "$APURADOR" --check --log "$APURA_LOG" --policy "$TMP/apura-policy-divergente.json" >/dev/null 2>&1; rc=$?
assert_eq "--check falha com policy divergente" "$rc" "1"

echo ""
echo "== $PASS passed, $FAIL failed =="
[[ $FAIL -eq 0 ]]
