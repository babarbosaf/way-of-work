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
  ok) cat >/dev/null
     [[ -n "${MOCK_SESSIONS:-}" ]] && printf '{"cwd":"%s"}\n' "$PWD" > "$MOCK_SESSIONS/rollout-$$.jsonl"
     echo "codex-resposta:$*"; exit 0 ;;
  eco) cat; echo "codex-resposta:$*"; exit 0 ;;
  desculpa) cat >/dev/null; echo "warning: run ended with no output and no recorded error"; exit 0 ;;
  multilinha) cat >/dev/null; printf "codex-resposta:%s\nb\nc\nd\ne\n" "$*"; exit 0 ;;
  ratelimit) echo "429 too many requests: rate limit"; exit 1 ;;
  tierreset) echo "quota exceeded; reset at 2100-01-01T00:00:00Z"; exit 1 ;;
  tierunreadable) echo "quota exceeded; reset em breve"; exit 1 ;;
  timeout) exit 124 ;;
  notfound) cat >/dev/null; echo "ERROR: unexpected status 404 Not Found: The model \`gpt-5.5\` does not exist or you do not have access to it."; exit 1 ;;
  fail) echo "erro interno"; exit 1 ;;
  absent) exit 127 ;;
  *) echo "mock codex: MOCK_CODEX='${MOCK_CODEX:-}' não existe neste mock" >&2; exit 99 ;;
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
  *) echo "mock agy: MOCK_AGY='${MOCK_AGY:-}' não existe neste mock" >&2; exit 99 ;;
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
mock_claude() {
cat > "$MOCKBIN/claude" <<'EOF'
#!/usr/bin/env bash
case "${MOCK_CLAUDE:-fail}" in
  ok) cat >/dev/null
      [[ -n "${MOCK_SESSIONS:-}" ]] && echo '{"type":"summary"}' > "$MOCK_SESSIONS/sessao-$$.jsonl"
      echo "claude-resposta:$* key=${ANTHROPIC_API_KEY:-unset}"; exit 0 ;;
  multilinha) cat >/dev/null; printf "claude-resposta:%s\nb\nc\nd\ne\n" "$*"; exit 0 ;;
  ratelimit) cat >/dev/null; echo "429 too many requests: rate limit"; exit 1 ;;
  fail) cat >/dev/null; echo "erro interno claude"; exit 1 ;;
  absent) exit 127 ;;
  *) echo "mock claude: MOCK_CLAUDE='${MOCK_CLAUDE:-}' não existe neste mock" >&2; exit 99 ;;
esac
EOF
chmod +x "$MOCKBIN/claude"
}
mock_claude
export PATH="$MOCKBIN:$PATH"

# ambiente isolado: gate dir e policy próprios do teste
export DELEGATE_GATE_DIR="$TMP/gate"
# A raiz das árvores de trabalho saiu de dentro do repo, e sem sobrepor aqui a
# suíte passou a semear diretório no $HOME de verdade: 160 husks vazios numa
# rodada só, que ninguém colhe porque `worktree prune` não vê diretório que nunca
# virou worktree.
export DELEGATE_WT_ROOT="$TMP/wt"
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
# O identificador vem do mktemp, cujo alfabeto inclui maiúscula.
branch=$(sed -n 's/.*branch: \(delegate\/[A-Za-z0-9-]*\).*/\1/p' <<<"$out" | head -1)
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
assert_contains "--add-dir aponta pra worktree" "$argv" "$DELEGATE_WT_ROOT/"
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
export DELEGATE_WT_ROOT="$TMP/wt"   # devolve o default da suíte, senão o resto semeia no $HOME

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

echo "T: despacho assíncrono devolve identificador e não fica pendurado"
SLOT="$HERE/../skills/delegate/scripts/lib-slot.sh"
[[ -f "$SLOT" ]] && ok "biblioteca de slot existe" || fail "biblioteca de slot ausente"
rm -f "$DELEGATE_GATE_DIR"/cooldown.* "$DELEGATE_GATE_DIR"/slot.* "$DELEGATE_GATE_DIR/delegate.log"
mock_demorado() { # backend segundos
  cat > "$MOCKBIN/$1" <<EOF
#!/usr/bin/env bash
cat >/dev/null; sleep $2; echo "$1-resposta:\$*"; exit 0
EOF
  chmod +x "$MOCKBIN/$1"
}
mock_demorado codex 4
t0=$SECONDS
out=$(run --task _probe --model codex --async -); rc=$?
gastou=$(( SECONDS - t0 ))
assert_eq "exit 0 no despacho assíncrono" "$rc" "0"
assert_contains "devolve identificador da task" "$out" "^task: "
[[ $gastou -lt 3 ]] && ok "não esperou o worker terminar (${gastou}s)" \
  || fail "ficou pendurado ${gastou}s, o worker leva 4s"

echo "T: um slot por balde, e o balde ocupado não recebe um segundo worker"
espera_slot() { local i; for i in 1 2 3 4 5 6 7 8 9 10; do [[ -f "$DELEGATE_GATE_DIR/slot.$1" ]] && return 0; sleep 0.3; done; return 1; }
espera_slot codex && ok "o balde em curso tem slot no disco" || fail "nenhum slot foi tomado"
id2=$(run --task _probe --model codex --async - | sed -n 's/^task: //p')
for _ in 1 2 3 4 5 6 7 8 9 10; do
  grep -q '^estado=' "$DELEGATE_GATE_DIR/tasks/$id2/meta" 2>/dev/null \
    && ! grep -q '^estado=em curso' "$DELEGATE_GATE_DIR/tasks/$id2/meta" && break
  sleep 0.3
done
estado2=$(sed -n 's/^estado=//p' "$DELEGATE_GATE_DIR/tasks/$id2/meta" 2>/dev/null)
[[ "$estado2" == falhou ]] && ok "o segundo despacho no balde ocupado não virou worker (estado=$estado2)" \
  || fail "o segundo despacho no balde ocupado terminou em '$estado2'"
assert_contains "o motivo do pulo fica no report da task" "$(cat "$DELEGATE_GATE_DIR/tasks/$id2/report.txt" 2>/dev/null)" "ocupado"
[[ "$(ls "$DELEGATE_GATE_DIR"/slot.codex* 2>/dev/null | wc -l | tr -d ' ')" == "1" ]] \
  && ok "um slot só no balde, nunca dois" || fail "o balde ganhou mais de um slot"

echo "T: três tasks em baldes diferentes correm ao mesmo tempo"
mock_demorado agy 4
mock_demorado claude 4
run --task _probe --model agy --async - >/dev/null
run --task _probe --model claude --async - >/dev/null
espera_slot "agy:gemini"; espera_slot claude
ocupados=$(ls "$DELEGATE_GATE_DIR"/slot.* 2>/dev/null | wc -l | tr -d ' ')
[[ "$ocupados" == "3" ]] && ok "três baldes ocupados ao mesmo tempo" \
  || fail "esperava 3 baldes em curso, achei $ocupados"
wait 2>/dev/null
rm -f "$DELEGATE_GATE_DIR"/slot.*

echo "T: slot de worker morto volta a ficar livre sem intervenção"
printf 'pid=999999\nid=fantasma\nprazo=%s\nbalde=codex\n' "$(( $(date +%s) + 9999 ))" > "$DELEGATE_GATE_DIR/slot.codex"
mock_codex
out=$(run --task _probe --model codex -)
assert_eq "exit 0: slot de processo morto foi tomado" "$?" "0"
printf 'pid=%s\nid=vencido\nprazo=1\nbalde=codex\n' "$$" > "$DELEGATE_GATE_DIR/slot.codex"
out=$(run --task _probe --model codex -)
assert_eq "exit 0: slot com prazo vencido foi tomado" "$?" "0"
rm -f "$DELEGATE_GATE_DIR"/slot.*

echo "T: slot órfão não pode ser tomado por dois ao mesmo tempo"
# O resgate de órfão era `rm -f` e recria: dois despachos que vissem o mesmo
# órfão passavam os dois, o segundo apagava o arquivo do primeiro, e os dois se
# julgavam donos do balde. O `soltar` do primeiro virava no-op porque o pid
# gravado já era do segundo. Aqui o resgate tira o órfão do caminho com `mv`, que
# só um dos dois consegue.
rm -f "$DELEGATE_GATE_DIR"/slot.*
source "$SLOT"
slot_configurar "$DELEGATE_GATE_DIR"
printf 'pid=999999\nid=fantasma\nprazo=1\nbalde=codex\n' > "$DELEGATE_GATE_DIR/slot.codex"
slot_tomar codex primeiro 60 && ok "o primeiro resgata o slot órfão" || fail "o resgate do órfão falhou"
slot_tomar codex segundo 60 && fail "o segundo tomou um balde que já tem dono" \
  || ok "o segundo não toma balde com dono vivo"
assert_contains "o dono gravado é o primeiro" "$(cat "$DELEGATE_GATE_DIR/slot.codex")" "id=primeiro"
[[ "$(ls "$DELEGATE_GATE_DIR"/slot.* 2>/dev/null | wc -l | tr -d ' ')" == "1" ]] \
  && ok "o resgate não deixa arquivo de slot sobrando" || fail "sobrou arquivo de slot: $(ls "$DELEGATE_GATE_DIR"/slot.*)"
rm -f "$DELEGATE_GATE_DIR"/slot.*

# Dez rodadas de par concorrente: com o `rm -f` do resgate antigo os dois podiam
# vencer, e o número de vencedores era a única prova possível disso.
for _ in 1 2 3 4 5 6 7 8 9 10; do
  rm -f "$DELEGATE_GATE_DIR"/slot.* "$TMP/vencedores"
  printf 'pid=999999\nid=fantasma\nprazo=1\nbalde=codex\n' > "$DELEGATE_GATE_DIR/slot.codex"
  ( slot_tomar codex A 60 && echo A >> "$TMP/vencedores" ) &
  ( slot_tomar codex B 60 && echo B >> "$TMP/vencedores" ) &
  wait 2>/dev/null
  n=$(wc -l < "$TMP/vencedores" 2>/dev/null | tr -d ' ')
  [[ "${n:-0}" == "1" ]] || { fail "o mesmo slot órfão foi tomado por $n despachos"; break; }
done
[[ "${n:-0}" == "1" ]] && ok "dez pares concorrentes, e o órfão só teve um vencedor por rodada"
rm -f "$DELEGATE_GATE_DIR"/slot.*

echo "T: o caminho assíncrono também não deixa a chave da API chegar ao worker"
mock_claude   # o mock demorado de cima trocou o corpo, e ninguém devolvia
id_async=$(ANTHROPIC_API_KEY=segredo-async MOCK_CLAUDE=ok run --task _probe --model claude --async - | sed -n 's/^task: //p')
[[ -n "$id_async" ]] && ok "o despacho assíncrono devolveu id" || fail "nenhum id no despacho assíncrono"
for _ in 1 2 3 4 5 6 7 8 9 10; do
  [[ -s "$DELEGATE_GATE_DIR/tasks/$id_async/out.txt" ]] && break
  sleep 1
done
material=$(cat "$DELEGATE_GATE_DIR/tasks/$id_async/out.txt" 2>/dev/null)
assert_contains "a chave não chegou ao worker no caminho assíncrono" "$material" "key=unset"
grep -q "segredo-async" <<<"$material" && fail "a chave vazou pro worker assíncrono" \
  || ok "nenhum rastro da chave no worker assíncrono"

echo "T: variável de ambiente devolve o despacho pro modo serial"
rm -f "$DELEGATE_GATE_DIR"/slot.*
mock_demorado codex 3
t0=$SECONDS
out=$(DELEGATE_SERIAL=1 run --task _probe --model codex --async -); rc=$?
gastou=$(( SECONDS - t0 ))
assert_eq "exit 0 no modo serial" "$rc" "0"
[[ $gastou -ge 3 ]] && ok "no modo serial o despacho espera o worker (${gastou}s)" \
  || fail "o modo serial não esperou (${gastou}s)"
assert_contains "o modo serial ainda devolve identificador" "$out" "^task: "
mock_codex; mock_agy
rm -f "$DELEGATE_GATE_DIR"/slot.* "$DELEGATE_GATE_DIR"/cooldown.*

echo "T: o log liga cada chamada ao material do worker que a atendeu"
# Os transcripts existem e não rotacionam (712 do worker de código desde
# fevereiro, mais 547 do Claude, medido em 21/set/2026), mas são mais de mil
# arquivos de nome opaco e nada ligava uma task ao material dela: diagnóstico
# começava por uma caçada.
rm -f "$DELEGATE_GATE_DIR"/slot.* "$DELEGATE_GATE_DIR"/cooldown.* "$DELEGATE_GATE_DIR/delegate.log"
mock_codex
run --task _probe --model codex - >/dev/null
linha=$(tail -1 "$DELEGATE_GATE_DIR/delegate.log")
mat=$(jq -r '.material // empty' <<<"$linha")
[[ -n "$mat" ]] && ok "chamada que fechou grava o caminho do material" || fail "nenhum material no log: $linha"
[[ -f "$mat" ]] && ok "o caminho gravado existe no disco" || fail "o caminho gravado não existe: $mat"
rm -f "$DELEGATE_GATE_DIR"/slot.*
MOCK_CODEX=fail run --task _probe --model codex - >/dev/null 2>&1
linha=$(tail -1 "$DELEGATE_GATE_DIR/delegate.log")
mat=$(jq -r '.material // empty' <<<"$linha")
[[ -n "$mat" && -f "$mat" ]] && ok "chamada que falhou também aponta pro material, e ele existe" \
  || fail "falha sem material apontável: $linha"

# O transcript do worker vence o output capturado quando existe: o output traz o
# que o worker imprimiu, o transcript traz como ele chegou lá, e é esse o material
# que a caçada procurava. Achado pelo diretório de trabalho, que o despachante
# conhece porque foi ele que criou.
sessoes="$TMP/sessoes-codex"; mkdir -p "$sessoes"
jq --arg b "$sessoes" '.backends.codex.sessions = {"path":$b,"grep":"\"cwd\":\"{cwd}\""}' \
  "$DELEGATE_POLICY" > "$TMP/pol" && mv "$TMP/pol" "$DELEGATE_POLICY"
rm -f "$DELEGATE_GATE_DIR"/slot.*
MOCK_SESSIONS="$sessoes" run --task _probe --model codex - >/dev/null
mat=$(jq -r '.material // empty' <<<"$(tail -1 "$DELEGATE_GATE_DIR/delegate.log")")
assert_contains "o transcript do worker vence o output capturado" "$mat" "$sessoes/rollout-"
[[ -f "$mat" ]] && ok "o transcript apontado existe" || fail "o transcript apontado não existe: $mat"
rm -f "$DELEGATE_GATE_DIR"/slot.*
run --task _probe --model codex - >/dev/null
mat=$(jq -r '.material // empty' <<<"$(tail -1 "$DELEGATE_GATE_DIR/delegate.log")")
assert_contains "worker que não gravou sessão cai no output capturado" "$mat" "out.txt"
# O plano não grava o cwd dentro do arquivo: ele nomeia o diretório da sessão pelo
# cwd. O teste monta o caminho por fora e o despachante deriva o dele por dentro,
# então o assert falha se as duas derivações divergirem.
sess_plano="$TMP/sessoes-plano"
dir_plano="$sess_plano/$(printf '%s' "$PWD" | tr '/.' '--')"; mkdir -p "$dir_plano"
jq --arg b "$sess_plano" '.backends.claude.sessions = {"path":($b + "/{cwd_flat}")}' \
  "$DELEGATE_POLICY" > "$TMP/pol" && mv "$TMP/pol" "$DELEGATE_POLICY"
rm -f "$DELEGATE_GATE_DIR"/slot.*
MOCK_CLAUDE=ok MOCK_SESSIONS="$dir_plano" run --task _probe --model claude - >/dev/null
mat=$(jq -r '.material // empty' <<<"$(tail -1 "$DELEGATE_GATE_DIR/delegate.log")")
assert_contains "a sessão do plano é achada pelo nome de diretório" "$mat" "$dir_plano/sessao-"
policy_fresh

echo "T: o log grava caminho, nunca conteúdo"
prompt_secreto="marcador-que-nao-pode-vazar-no-log"
rm -f "$DELEGATE_GATE_DIR"/slot.*
echo "$prompt_secreto" | bash "$DELEGATE" --task _probe --model codex - >/dev/null 2>&1
grep -q "$prompt_secreto" "$DELEGATE_GATE_DIR/delegate.log" \
  && fail "conteúdo do prompt vazou pro log" || ok "nenhum conteúdo de prompt no log"
grep -q 'codex-resposta' "$DELEGATE_GATE_DIR/delegate.log" \
  && fail "conteúdo da resposta vazou pro log" || ok "nenhum conteúdo de resposta no log"
tam=$(wc -c < "$DELEGATE_GATE_DIR/delegate.log")
[[ "$tam" -lt 4000 ]] && ok "o log segue sendo índice, não depósito (${tam} bytes)" \
  || fail "o log engordou pra ${tam} bytes, o que cheira a conteúdo dentro dele"
rm -f "$DELEGATE_GATE_DIR"/slot.* "$DELEGATE_GATE_DIR/delegate.log"

echo "T: o resultado da task se consulta pelo identificador do despacho"
rm -f "$DELEGATE_GATE_DIR"/slot.* "$DELEGATE_GATE_DIR"/cooldown.*
mock_codex
id_ok=$(run --task _probe --model codex --async - | sed -n 's/^task: //p')
espera_estado() { local i; for i in $(seq 1 20); do
    grep -q '^estado=em curso' "$DELEGATE_GATE_DIR/tasks/$1/meta" 2>/dev/null || return 0; sleep 0.3; done; return 1; }
espera_estado "$id_ok"
consulta=$(bash "$DELEGATE" --status "$id_ok" 2>&1); rc=$?
assert_eq "consulta sai 0" "$rc" "0"
assert_contains "a consulta nomeia o estado" "$consulta" "^estado: pronta"
assert_contains "a consulta aponta pro material" "$consulta" "out.txt"
[[ -s "$(sed -n 's/^material: //p' <<<"$consulta")" ]] \
  && ok "o material apontado existe e tem conteúdo" || fail "o material apontado não existe"

echo "T: os quatro estados terminais, e nenhum inventado"
for e in "em curso" pronta falhou "estourou o prazo"; do
  grep -q "$e" "$DELEGATE"  && ok "o despachante conhece o estado '$e'" \
    || fail "o estado '$e' não existe no despachante"
done
grep -q 'cancelada' "$DELEGATE" && fail "estado cancelada apareceu, e matar worker está fora desta entrega" \
  || ok "cancelada não existe, como a spec declara"
rm -f "$DELEGATE_GATE_DIR"/slot.*
MOCK_CODEX=fail run --task _probe --model codex - >/dev/null 2>&1
id_falho=$(ls -t "$DELEGATE_GATE_DIR/tasks" | head -1)
assert_contains "task que não fechou nomeia falha" "$(bash "$DELEGATE" --status "$id_falho" 2>&1)" "^estado: falhou"

echo "T: identificador que não existe responde sem estourar"
saida=$(bash "$DELEGATE" --status nao-existe-mesmo 2>&1); rc=$?
assert_eq "exit 1, erro de uso e não crash" "$rc" "1"
assert_contains "diz que não conhece o identificador" "$saida" "não existe"
saida=$(bash "$DELEGATE" --status "../../etc/passwd" 2>&1); rc=$?
[[ "$rc" != 0 ]] && ok "identificador com travessia de caminho é recusado" \
  || fail "identificador com ../ foi aceito"
rm -f "$DELEGATE_GATE_DIR"/slot.* "$DELEGATE_GATE_DIR"/cooldown.*

echo "T: a camada de terminal lê as tasks em curso, e não decide nada"
# AC-14 e AC-15. O leitor é o que o pane do herdr roda em laço, e a fronteira dura
# é a razão do ADR-0001: sem caminho de escrita, a camada não tem por onde
# escolher worker nem modelo, então desligá-la muda a tela e não o roteamento.
rm -f "$DELEGATE_GATE_DIR"/slot.* "$DELEGATE_GATE_DIR"/cooldown.*
rm -rf "$DELEGATE_GATE_DIR/tasks"
vazio=$(bash "$DELEGATE" --tasks 2>&1); rc=$?
assert_eq "sem task em curso a listagem sai 0" "$rc" "0"
assert_contains "e diz que não tem nada em curso" "$vazio" "nenhuma task em curso"

# Task em curso montada à mão: o que o leitor promete é ler o estado que o
# despacho deixa, e montar isso aqui prova o contrato sem esperar worker.
TID="implement-fixture"
mkdir -p "$DELEGATE_GATE_DIR/tasks/$TID"
cat > "$DELEGATE_GATE_DIR/tasks/$TID/meta" <<EOF
estado=em curso
task=implement
balde=codex
branch=delegate/$TID
comecou=2026-09-21T12:00:00Z
EOF
printf 'pid=%s\nid=%s\nprazo=%s\nbalde=%s\n' "$$" "$TID" "$(( $(date +%s) + 300 ))" "codex" \
  > "$DELEGATE_GATE_DIR/slot.codex"
lista=$(bash "$DELEGATE" --tasks 2>&1)
assert_contains "a listagem nomeia o balde" "$lista" "codex"
assert_contains "a listagem nomeia o tipo de task" "$lista" "implement"
assert_contains "a listagem nomeia a branch" "$lista" "delegate/$TID"

# Só de leitura, e o assert é o gate inteiro byte a byte: se o leitor criasse
# log, lock ou cache, a camada passaria a ter estado próprio e a fronteira do
# ADR-0001 cairia sem ninguém ver.
estado_gate() { find "$DELEGATE_GATE_DIR" | sort | tr '\n' ' '; find "$DELEGATE_GATE_DIR" -type f | sort | xargs cat 2>/dev/null | cksum; }
antes=$(estado_gate); bash "$DELEGATE" --tasks >/dev/null 2>&1; depois=$(estado_gate)
assert_eq "a leitura não escreve nada no gate" "$depois" "$antes"

# Sem policy o leitor continua inteiro: é a prova de que não existe caminho de
# escolha de worker ou modelo no meio dele, porque escolha exige policy.
sem_policy=$(DELEGATE_POLICY="$TMP/policy-que-nao-existe.json" bash "$DELEGATE" --tasks 2>&1); rc=$?
assert_eq "a listagem não depende da policy" "$rc" "0"
assert_contains "e sem policy ainda lista a task" "$sem_policy" "delegate/$TID"

# Slot órfão é task que ninguém está rodando, e listar ela mentiria pra quem olha
# a tela: a mesma expiração que solta o balde tira a linha da listagem.
printf 'pid=%s\nid=%s\nprazo=%s\nbalde=%s\n' "999999" "$TID" "1" "codex" > "$DELEGATE_GATE_DIR/slot.codex"
orfao=$(bash "$DELEGATE" --tasks 2>&1)
grep -q "delegate/$TID" <<<"$orfao" && fail "slot órfão apareceu como task em curso" \
  || ok "slot órfão não entra na listagem"
rm -f "$DELEGATE_GATE_DIR"/slot.*
rm -rf "$DELEGATE_GATE_DIR/tasks/$TID"

# Desligar a camada é não rodar o leitor, e o despachante não tem como notar.
grep -qi 'herdr' "$DELEGATE" \
  && fail "o despachante cita a ferramenta de terminal, e aí desligá-la pode mudar roteamento" \
  || ok "o despachante não conhece a ferramenta de terminal"
mock_codex
sem_camada=$(run --task _probe -)
rm -f "$DELEGATE_GATE_DIR"/slot.* "$DELEGATE_GATE_DIR"/cooldown.*
( for _i in $(seq 1 10); do bash "$DELEGATE" --tasks >/dev/null 2>&1; done ) &
_leitor=$!
com_camada=$(run --task _probe -)
wait "$_leitor"
assert_eq "com a camada lendo em laço, o roteamento é idêntico" "$com_camada" "$sem_camada"
rm -f "$DELEGATE_GATE_DIR"/slot.* "$DELEGATE_GATE_DIR"/cooldown.* "$DELEGATE_GATE_DIR/delegate.log"

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
# ACUMULA, e não apaga: quem precisa de log limpo apaga antes de chamar. O schema
# da linha de log mora só aqui, senão o campo novo entra em um sítio e o outro
# passa a medir log de forma antiga.
semeia_log() { # pool quantidade
  local i n="$2"; [[ "$n" =~ ^[0-9]+$ ]] || n=0
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
rm -f "$DELEGATE_GATE_DIR"/cooldown.* "$DELEGATE_GATE_DIR/delegate.log"
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
  semeia_log "$pool" "$teto"
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

echo "T: prompt que carrega frase de limite não castiga balde nem descarta resposta"
# Medido em 21/set/2026: revisar o diff deste despachante mandou pro worker a
# linha do próprio detector de desculpa, o codex ecoou o prompt no stdout como
# sempre faz, e o detector casou com ele mesmo. A revisão inteira foi pro lixo e
# o balde levou 60min de castigo. A população do classificador é o que o worker
# acrescentou, nunca o prompt de volta.
rm -f "$DELEGATE_GATE_DIR"/slot.* "$DELEGATE_GATE_DIR"/cooldown.*
mock_codex
out=$(printf 'Revise este trecho:\nis_sem_resposta() { grep -qiE "(run ended with no output|no recorded error)" "$1"; }\nquota exceeded aparece aqui como dado, nao como resposta\n' \
  | MOCK_CODEX=eco bash "$DELEGATE" --task _probe --model codex - 2>"$TMP/err"); rc=$?
assert_eq "resposta boa com frase de limite no prompt: exit 0" "$rc" "0"
assert_contains "a resposta do worker sobreviveu" "$out" "codex-resposta"
[[ -f "$DELEGATE_GATE_DIR/cooldown.codex" ]] \
  && fail "o prompt ecoado castigou o balde por 60min" \
  || ok "frase de limite no prompt não arma cooldown"
# Contraprova no mesmo par: a MESMA frase, agora dita pelo worker, continua
# castigando. Sem isso o conserto seria só desligar o detector.
rm -f "$DELEGATE_GATE_DIR"/slot.* "$DELEGATE_GATE_DIR"/cooldown.*
echo x | MOCK_CODEX=desculpa bash "$DELEGATE" --task _probe --model codex - >/dev/null 2>&1
[[ -f "$DELEGATE_GATE_DIR/cooldown.codex" ]] \
  && ok "desculpa dita pelo worker continua armando cooldown" \
  || fail "o detector morreu: desculpa do worker não arma mais nada"
rm -f "$DELEGATE_GATE_DIR"/slot.* "$DELEGATE_GATE_DIR"/cooldown.*

echo "T: a árvore do worker nasce no HEAD de quem despachou, não no trunk"
# Medido em 21/set/2026, no primeiro despacho real: a sessão estava na branch da
# spec, a base saiu do trunk do project.yaml, e o worker construiu contra um
# arquivo onde a flag que ele devia cobrir não existia. O diff dele não entrou
# por cherry-pick.
rm -f "$DELEGATE_GATE_DIR"/slot.* "$DELEGATE_GATE_DIR"/cooldown.*
cat > "$MOCKBIN/codex" <<'EOF'
#!/usr/bin/env bash
cat >/dev/null; echo mudanca > worker.txt; echo "codex-worktree-ok"; exit 0
EOF
chmod +x "$MOCKBIN/codex"
REPO_B="$TMP/repo-base"; rm -rf "$REPO_B"; mkdir -p "$REPO_B/.claude"
git -C "$REPO_B" init -q -b main
printf 'repo:\n  trunk: main\n' > "$REPO_B/.claude/project.yaml"
echo trunk > "$REPO_B/f.txt"
git -C "$REPO_B" add -A; git -C "$REPO_B" -c user.email=t@t -c user.name=t commit -qm base
git -C "$REPO_B" switch -q -c feature/spec
echo "so na branch" > "$REPO_B/da-branch.txt"
git -C "$REPO_B" add -A; git -C "$REPO_B" -c user.email=t@t -c user.name=t commit -qm "trabalho da spec"
out=$(run --task _probe --model codex --worktree "$REPO_B" -); rc=$?
assert_eq "despacho de branch não-trunk: exit 0" "$rc" "0"
assert_contains "a base reportada é a branch de quem despachou" "$out" "^base: feature/spec @"
wt_criada=$(git -C "$REPO_B" worktree list | grep 'delegate/' | awk '{print $1}')
[[ -f "$wt_criada/da-branch.txt" ]] \
  && ok "a árvore do worker tem o trabalho da branch" \
  || fail "a árvore nasceu sem o trabalho da branch: base errada"
git -C "$REPO_B" worktree remove --force "$wt_criada" 2>/dev/null
git -C "$REPO_B" branch -D $(git -C "$REPO_B" branch --list 'delegate/*' | tr -d ' *') 2>/dev/null
# No trunk, nada muda: a base continua sendo o trunk, e é o mesmo commit.
git -C "$REPO_B" switch -q main
out=$(run --task _probe --model codex --worktree "$REPO_B" -)
assert_contains "no trunk a base continua o trunk" "$out" "^base: main @"
wt_criada=$(git -C "$REPO_B" worktree list | grep 'delegate/' | awk '{print $1}')
[[ -f "$wt_criada/da-branch.txt" ]] && fail "a árvore do trunk trouxe trabalho da branch" \
  || ok "no trunk a árvore não tem o trabalho da branch"
git -C "$REPO_B" worktree remove --force "$wt_criada" 2>/dev/null
git -C "$REPO_B" branch -D $(git -C "$REPO_B" branch --list 'delegate/*' | tr -d ' *') 2>/dev/null
# E o explícito continua vencendo o default.
git -C "$REPO_B" switch -q feature/spec
out=$(run --task _probe --model codex --worktree "$REPO_B" --base main -)
assert_contains "--base explícito vence o default" "$out" "^base: main @"
git -C "$REPO_B" worktree remove --force "$(git -C "$REPO_B" worktree list | grep 'delegate/' | awk '{print $1}')" 2>/dev/null
git -C "$REPO_B" branch -D $(git -C "$REPO_B" branch --list 'delegate/*' | tr -d ' *') 2>/dev/null
mock_codex
rm -f "$DELEGATE_GATE_DIR"/slot.* "$DELEGATE_GATE_DIR"/cooldown.*

echo "T: a listagem pergunta se o dono está vivo, não se o slot é tomável"
# Achado da revisão do codex: o prazo do slot começa na tomada e o prazo do
# worker começa depois do preparo da chamada, então worker vivo passa do prazo do
# slot. Com a regra de "tomável", a task viva desaparecia da tela.
rm -f "$DELEGATE_GATE_DIR"/slot.*
TIDV="implement-vivo"
mkdir -p "$DELEGATE_GATE_DIR/tasks/$TIDV"
printf 'estado=em curso\ntask=implement\nbalde=codex\nbranch=delegate/%s\n' "$TIDV" \
  > "$DELEGATE_GATE_DIR/tasks/$TIDV/meta"
printf 'pid=%s\nid=%s\nprazo=1\nbalde=codex\n' "$$" "$TIDV" > "$DELEGATE_GATE_DIR/slot.codex"
vivo=$(bash "$DELEGATE" --tasks 2>&1)
assert_contains "dono vivo com prazo vencido continua na listagem" "$vivo" "$TIDV"
# E o inverso segue valendo: dono morto sai, senão a tela encheria de fantasma.
printf 'pid=999999\nid=%s\nprazo=%s\nbalde=codex\n' "$TIDV" "$(( $(date +%s) + 300 ))" \
  > "$DELEGATE_GATE_DIR/slot.codex"
morto=$(bash "$DELEGATE" --tasks 2>&1)
grep -q "$TIDV" <<<"$morto" && fail "dono morto apareceu como task em curso" \
  || ok "dono morto sai da listagem mesmo dentro do prazo"
rm -f "$DELEGATE_GATE_DIR"/slot.*; rm -rf "$DELEGATE_GATE_DIR/tasks/$TIDV"

echo "T: o meta é publicado inteiro, nunca pela metade"
# Truncar e depois escrever deixava janela: o leitor pegava o arquivo no meio e
# imprimia campo vazio. Este assert é guarda, não reprodução: a janela é de
# microssegundos, e o que ele cobra é que nenhuma leitura concorrente veja linha
# sem tipo de task.
rm -f "$DELEGATE_GATE_DIR"/slot.* "$DELEGATE_GATE_DIR"/cooldown.*
mock_codex
TIDA="implement-atomico"
mkdir -p "$DELEGATE_GATE_DIR/tasks/$TIDA"
printf 'pid=%s\nid=%s\nprazo=%s\nbalde=codex\n' "$$" "$TIDA" "$(( $(date +%s) + 300 ))" \
  > "$DELEGATE_GATE_DIR/slot.codex"
( for _i in $(seq 1 120); do
    printf 'estado=em curso\ntask=implement\nbalde=codex\nbranch=delegate/%s\ncomecou=x\n' "$TIDA" \
      > "$DELEGATE_GATE_DIR/tasks/$TIDA/meta.novo"
    mv "$DELEGATE_GATE_DIR/tasks/$TIDA/meta.novo" "$DELEGATE_GATE_DIR/tasks/$TIDA/meta"
  done ) &
_escritor=$!
parciais=0
for _i in $(seq 1 60); do
  linha=$(bash "$DELEGATE" --tasks 2>/dev/null | grep "$TIDA" || true)
  [[ -z "$linha" ]] && continue
  grep -qE "$TIDA +codex +implement +delegate/$TIDA" <<<"$linha" || parciais=$(( parciais + 1 ))
done
wait "$_escritor"
assert_eq "nenhuma leitura concorrente viu meta pela metade" "$parciais" "0"
[[ -f "$DELEGATE_GATE_DIR/tasks/$TIDA/meta.novo" ]] && fail "o temporário do meta ficou pra trás" \
  || ok "a publicação não deixa temporário"
rm -f "$DELEGATE_GATE_DIR"/slot.*; rm -rf "$DELEGATE_GATE_DIR/tasks/$TIDA"

echo "T: cascata esgotada não anuncia branch que a limpeza já apagou"
rm -f "$DELEGATE_GATE_DIR"/slot.* "$DELEGATE_GATE_DIR"/cooldown.*
REPO_D="$TMP/repo-branch-morta"; rm -rf "$REPO_D"; mkdir -p "$REPO_D"
git -C "$REPO_D" init -q -b main; echo x > "$REPO_D/f.txt"
git -C "$REPO_D" add f.txt; git -C "$REPO_D" -c user.email=t@t -c user.name=t commit -qm base
MOCK_CODEX=fail MOCK_AGY=fail MOCK_CLAUDE=fail run --task _probe --worktree "$REPO_D" - >/dev/null 2>&1
id_morta=$(ls -t "$DELEGATE_GATE_DIR/tasks" | head -1)
consulta=$(bash "$DELEGATE" --status "$id_morta" 2>&1)
grep -q '^branch:' <<<"$consulta" && fail "o meta aponta pra branch que a limpeza apagou: $consulta" \
  || ok "branch apagada não fica no meta"
git -C "$REPO_D" branch --list 'delegate/*' | grep -q . && fail "a branch do worker sobrou no repo" \
  || ok "a limpeza apagou a branch de verdade"
rm -f "$DELEGATE_GATE_DIR"/slot.* "$DELEGATE_GATE_DIR"/cooldown.*

echo "T: o leitor de tasks não cria nem toca em nada no gate"
# A revisão do codex reproduziu: antes do desvio da flag o script fazia mkdir no
# gate, touch no log e mktemp da policy fundida. Num pane lendo a cada 2s isso é
# um temporário novo por leitura. O assert de antes preparava o gate primeiro,
# então media conteúdo e nunca criação.
virgem="$TMP/gate-virgem"
rm -rf "$virgem"
saida=$(DELEGATE_GATE_DIR="$virgem" bash "$DELEGATE" --tasks 2>&1); rc=$?
assert_eq "gate inexistente: a leitura sai 0" "$rc" "0"
assert_contains "e diz que não tem nada em curso" "$saida" "nenhuma task em curso"
[[ -e "$virgem" ]] && fail "a leitura criou o gate que não existia" \
  || ok "a leitura não criou o gate"
# Log intocado: mtime é o que um laço de 2s mexeria, e conteúdo não pega isso.
touch -t 202001010000 "$DELEGATE_GATE_DIR/delegate.log"
antes_mtime=$(stat -f %m "$DELEGATE_GATE_DIR/delegate.log" 2>/dev/null || stat -c %Y "$DELEGATE_GATE_DIR/delegate.log")
bash "$DELEGATE" --tasks >/dev/null 2>&1
depois_mtime=$(stat -f %m "$DELEGATE_GATE_DIR/delegate.log" 2>/dev/null || stat -c %Y "$DELEGATE_GATE_DIR/delegate.log")
assert_eq "a leitura não toca o mtime do log" "$depois_mtime" "$antes_mtime"
# Policy local presente: a fusão nasce de um mktemp por chamada, e leitura não
# tem por que criar nenhum.
cp "$DELEGATE_POLICY" "$TMP/policy-backup.json"
echo '{"budgets":{"window_mins":300}}' > "${DELEGATE_POLICY%.json}.local.json"
tmp_antes=$(ls -1 "${TMPDIR:-/tmp}" 2>/dev/null | wc -l | tr -d ' ')
bash "$DELEGATE" --tasks >/dev/null 2>&1
tmp_depois=$(ls -1 "${TMPDIR:-/tmp}" 2>/dev/null | wc -l | tr -d ' ')
assert_eq "a leitura não deixa temporário de policy fundida" "$tmp_depois" "$tmp_antes"
rm -f "${DELEGATE_POLICY%.json}.local.json"

echo "T: flag que consome argumento e não recebe sai com erro de uso, não unbound variable"
# O script roda com `set -u`, então `"$2"` sem valor estourava antes de qualquer
# die: `delegate.sh --gc` sozinho era crash, não erro de uso. A guarda é uma só,
# e este laço é o que impede a próxima flag de nascer sem ela.
for flag in --task --tier --model --worktree --status --continue --timeout --gc --base --question --reference --expect-lines --expect-regex; do
  out=$(echo x | bash "$DELEGATE" "$flag" 2>&1); rc=$?
  assert_eq "$flag sem valor: exit 1" "$rc" "1"
  # `grep -qF --` porque o padrão começa com dois hífens: sem isso o grep leria
  # `--task` como opção dele, e o assert passaria verde provando nada.
  grep -qF -- "$flag" <<<"$out" && ok "$flag sem valor: mensagem nomeia a flag" || fail "$flag sem valor: mensagem nomeia a flag (não contém '$flag')"
  grep -q "unbound variable" <<<"$out" && fail "$flag sem valor: vazou unbound variable" || ok "$flag sem valor: não crasha"
done

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
{"ts":"2026-09-20T04:00:00Z","task":"implement","backend":"claude","status":"ok","detail":"model=cl","pool":"claude","bytes_in":1,"bytes_out":1,"dur_s":15}
{"ts":"2026-09-20T04:30:00Z","task":"implement","backend":"claude","status":"ok","detail":"model=cl","pool":"claude","bytes_in":1,"bytes_out":1,"dur_s":15}
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
# A régua não pode só apertar. O gate bloqueia em `gastas >= teto`, então o pico
# observado NUNCA passa do teto declarado: se o `--check` cobrasse igualdade, cada
# linha que sai da janela de 30 dias baixaria a régua, e ela desceria pra sempre
# sem nunca subir. Pico é piso de capacidade provada, então só é divergência
# quando a policy declara MENOS do que o balde já provou aguentar.
cat > "$TMP/apura-folga.json" <<'EOF'
{"budgets":{"window_mins":300,"pools":{"codex":{"max_calls":20}}},"timeouts":{"scan":24},"tasks":{"scan":[{"backend":"codex","model":"m1"}]}}
EOF
python3 "$APURADOR" --check --log "$APURA_LOG" --policy "$TMP/apura-folga.json" >/dev/null 2>&1
assert_eq "régua acima do pico provado não é divergência" "$?" "0"
cat > "$TMP/apura-aperto.json" <<'EOF'
{"budgets":{"window_mins":300,"pools":{"codex":{"max_calls":5}}},"timeouts":{"scan":24},"tasks":{"scan":[{"backend":"codex","model":"m1"}]}}
EOF
python3 "$APURADOR" --check --log "$APURA_LOG" --policy "$TMP/apura-aperto.json" >/dev/null 2>&1
assert_eq "régua abaixo do pico provado é divergência" "$?" "1"

# Pico medido é piso de uso, não teto de cota: duas chamadas num balde não são
# régua, e cobrar esse número estrangularia o balde que ninguém gastou ainda. A
# policy recusa a régua de propósito, e o apurador respeita sem perder o dado.
jq -e '.budgets.pools.claude.observado == 2' <<<"$apurado" >/dev/null \
  && ok "o pico observado do balde sem régua fica no relatório" \
  || fail "o pico observado do balde sem régua se perdeu: $(jq -c .budgets.pools.claude <<<"$apurado")"
jq -e '.budgets.pools.codex.max_calls == 11' <<<"$apurado" >/dev/null \
  && ok "balde com régua declarada continua sendo apurado" || fail "a régua declarada deixou de ser apurada"

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
