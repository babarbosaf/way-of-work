#!/usr/bin/env bash
# Suíte dos hooks de enforcement. Cada hook é alimentado com payload JSON no
# stdin, como o harness faz, e a suíte confere as duas direções: bloqueia o que
# deve bloquear, e libera o que deve passar. Uso: bash tests/hooks.test.sh
#
# Contrato dos hooks deste repo:
#   read_size_guard, noop_flush_guard, claude_md_size_guard
#     -> bloqueiam imprimindo {"decision":"block",...} no stdout, sempre exit 0
#   context7_reminder -> só avisa no stderr, nunca bloqueia
#   memory_log_append -> bloqueia com exit 2 e mensagem no stderr
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
H="$HERE/../hooks"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

PASS=0; FAIL=0
ok()   { PASS=$((PASS+1)); echo "  ✓ $1"; }
fail() { FAIL=$((FAIL+1)); echo "  ✗ $1"; }

# roda HOOK com PAYLOAD e ENV opcional. Resultado vai em RC/OUT/ERR, não no
# stdout: a mensagem de bloqueio do hook de memória contém `|`, e qualquer
# separador escolhido aqui apareceria dentro do dado.
RC=0; OUT=""; ERR=""
run_hook() {
  local hook="$1" payload="$2"; shift 2
  local fo fe
  fo=$(mktemp); fe=$(mktemp)
  printf '%s' "$payload" | env "$@" python3 "$H/$hook" >"$fo" 2>"$fe"; RC=$?
  OUT=$(cat "$fo"); ERR=$(cat "$fe")
  rm -f "$fo" "$fe"
}

assert_bloqueia_json() {
  [[ "$OUT" == *'"decision": "block"'* || "$OUT" == *'"decision":"block"'* ]] \
    && ok "$1" || fail "$1 (não bloqueou; stdout: $OUT)"
}
assert_libera_json() {
  [[ "$OUT" != *'"block"'* ]] && ok "$1" || fail "$1 (bloqueou e não devia: $OUT)"
}
assert_rc()          { [[ "$RC" == "$2" ]] && ok "$1" || fail "$1 (rc=$RC, esperado $2)"; }
assert_stderr_tem()  { [[ "$ERR" == *"$2"* ]] && ok "$1" || fail "$1 (stderr sem '$2': $ERR)"; }
assert_stderr_vazio(){ [[ -z "$ERR" ]] && ok "$1" || fail "$1 (stderr: $ERR)"; }

GRANDE="$TMP/grande.md"; seq 1 250 > "$GRANDE"
PEQUENO="$TMP/pequeno.md"; seq 1 10 > "$PEQUENO"
IMAGEM="$TMP/print.png"; seq 1 250 > "$IMAGEM"

echo "== read_size_guard: força grep antes de Read grande =="
p_read() { printf '{"tool_name":"Read","tool_input":{"file_path":"%s"%s}}' "$1" "${2:-}"; }
run_hook read_size_guard.py "$(p_read "$GRANDE")"
assert_bloqueia_json "arquivo de 250 linhas sem paginação"
run_hook read_size_guard.py "$(p_read "$GRANDE" ',"limit":50')"
assert_libera_json "mesmo arquivo com limit"
run_hook read_size_guard.py "$(p_read "$GRANDE" ',"offset":100')"
assert_libera_json "mesmo arquivo com offset"
run_hook read_size_guard.py "$(p_read "$PEQUENO")"
assert_libera_json "arquivo de 10 linhas"
run_hook read_size_guard.py "$(p_read "$IMAGEM")"
assert_libera_json "png grande é isento"
run_hook read_size_guard.py '{"tool_name":"Grep","tool_input":{"file_path":"'"$GRANDE"'"}}'
assert_libera_json "outra tool não é assunto do hook"
run_hook read_size_guard.py "$(p_read "$TMP/nao-existe.md")"
assert_libera_json "arquivo inexistente"
run_hook read_size_guard.py '{nao é json'
assert_libera_json "payload inválido não quebra sessão"
run_hook read_size_guard.py "$(p_read "$GRANDE")" READ_GUARD_DISABLED=1
assert_libera_json "kill switch libera"

echo "== noop_flush_guard: no-op puro não vira round-trip =="
p_bash() { printf '{"tool_name":"Bash","tool_input":{"command":"%s"}}' "$1"; }
run_hook noop_flush_guard.py "$(p_bash 'true')"
assert_bloqueia_json "comando true"
run_hook noop_flush_guard.py "$(p_bash ':')"
assert_bloqueia_json "comando :"
run_hook noop_flush_guard.py "$(p_bash 'sleep 5')"
assert_bloqueia_json "sleep isolado"
run_hook noop_flush_guard.py "$(p_bash 'ls -la')"
assert_libera_json "comando de verdade"
run_hook noop_flush_guard.py "$(p_bash 'echo oi')"
assert_libera_json "echo não entra no escopo"
run_hook noop_flush_guard.py "$(p_bash 'true')" NOOP_GUARD_DISABLED=1
assert_libera_json "kill switch libera"

echo "== context7_reminder: avisa e nunca bloqueia =="
run_hook context7_reminder.py '{"tool_name":"Write","tool_input":{"file_path":"/x/package.json","content":"{\"dependencies\":{\"react\":\"19\"}}"}}'
assert_rc "manifesto: exit 0" 0
assert_stderr_tem "manifesto: avisa no stderr" "context7"
assert_libera_json "manifesto: não bloqueia"
run_hook context7_reminder.py '{"tool_name":"Edit","tool_input":{"file_path":"/x/app.py","old_string":"","new_string":"import requests"}}'
assert_stderr_tem "import novo: avisa" "context7"
run_hook context7_reminder.py '{"tool_name":"Edit","tool_input":{"file_path":"/x/app.py","old_string":"a = 1","new_string":"a = 2"}}'
assert_stderr_vazio "edição sem import: silencioso"
run_hook context7_reminder.py '{"tool_name":"Edit","tool_input":{"file_path":"/x/app.py","old_string":"","new_string":"import requests"}}' CONTEXT7_REMINDER_DISABLED=1
assert_stderr_vazio "kill switch cala"

echo "== claude_md_size_guard: teto de linha do doc que carrega sempre =="
CORPO_GRANDE=$(python3 -c "print('\\\\n'.join('linha %d' % i for i in range(200)))")
run_hook claude_md_size_guard.py "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$TMP/AGENTS.md\",\"content\":\"$CORPO_GRANDE\"}}"
assert_bloqueia_json "AGENTS.md de 200 linhas estoura o teto de 130"
run_hook claude_md_size_guard.py "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$TMP/AGENTS.md\",\"content\":\"linha 1\\\\nlinha 2\"}}"
assert_libera_json "AGENTS.md curto passa"
run_hook claude_md_size_guard.py "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$TMP/qualquer.md\",\"content\":\"$CORPO_GRANDE\"}}"
assert_libera_json "arquivo fora da lista de tetos passa"
run_hook claude_md_size_guard.py "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$TMP/AGENTS.md\",\"content\":\"$CORPO_GRANDE\"}}" CLAUDE_MD_GUARD_DISABLED=1
assert_libera_json "kill switch libera"

echo "== memory_log_append: memória sem log não passa =="
FAKE_HOME="$TMP/home"
MEMDIR="$FAKE_HOME/.claude/projects/proj/memory"
mkdir -p "$MEMDIR"
ALVO="$MEMDIR/concept_teste.md"; echo "conteúdo" > "$ALVO"
p_mem() { printf '{"tool_name":"Write","session_id":"s1","tool_input":{"file_path":"%s"}}' "$1"; }

: > "$MEMDIR/log.md"
run_hook memory_log_append.py "$(p_mem "$ALVO")" HOME="$FAKE_HOME" CLAUDE_CONFIG_DIR="$FAKE_HOME/.claude"
assert_rc "sem entrada no log: exit 2" 2
assert_stderr_tem "diz o formato esperado" "log.md"

HOJE=$(date +%Y-%m-%d)
printf '## [%s] update | concept_teste.md (session=s1)\n' "$HOJE" > "$MEMDIR/log.md"
touch "$ALVO"
run_hook memory_log_append.py "$(p_mem "$ALVO")" HOME="$FAKE_HOME" CLAUDE_CONFIG_DIR="$FAKE_HOME/.claude"
assert_rc "com entrada válida: exit 0" 0

# O contrato real é fechado: só create|update|delete|lint|ingest são aceitos. A
# mensagem de bloqueio precisa dizer quais, senão ensina errado.
printf '## [%s] edit | concept_teste.md (session=s1)\n' "$HOJE" > "$MEMDIR/log.md"
touch "$ALVO"
run_hook memory_log_append.py "$(p_mem "$ALVO")" HOME="$FAKE_HOME" CLAUDE_CONFIG_DIR="$FAKE_HOME/.claude"
assert_rc "op fora da lista: exit 2" 2
if [[ "$ERR" == *"create"* && "$ERR" == *"update"* ]]; then
  ok "mensagem de bloqueio lista as ops aceitas"
else
  fail "mensagem de bloqueio não lista as ops aceitas (stderr: $ERR)"
fi

run_hook memory_log_append.py "$(p_mem "$MEMDIR/log.md")" HOME="$FAKE_HOME" CLAUDE_CONFIG_DIR="$FAKE_HOME/.claude"
assert_rc "log.md não se auto-exige" 0
run_hook memory_log_append.py "$(p_mem "$TMP/fora.md")" HOME="$FAKE_HOME" CLAUDE_CONFIG_DIR="$FAKE_HOME/.claude"
assert_rc "arquivo fora de memory/ não é assunto" 0
: > "$MEMDIR/log.md"
run_hook memory_log_append.py "$(p_mem "$ALVO")" HOME="$FAKE_HOME" MEMORY_HOOK_DISABLED=1 CLAUDE_CONFIG_DIR="$FAKE_HOME/.claude"
assert_rc "kill switch libera" 0

echo "== shunt_policy: threshold é dado, não número mágico =="
sp() { # env... → imprime JSON da config efetiva
  local fo fe; fo=$(mktemp); fe=$(mktemp)
  env "$@" python3 "$H/shunt_policy.py" >"$fo" 2>"$fe"; RC=$?
  OUT=$(cat "$fo"); ERR=$(cat "$fe"); rm -f "$fo" "$fe"
}
assert_json_num() { # label campo valor
  [[ "$(jq -r ".$2" <<<"$OUT" 2>/dev/null)" == "$3" ]] && ok "$1" || fail "$1 (obtido: $OUT)"
}
[[ -f "$H/shunt_policy.py" ]] && ok "helper existe em disco" || fail "hooks/shunt_policy.py não existe"
sp SHUNT_NOOP=1
assert_rc "helper roda como script e sai 0" 0
assert_json_num "grep_max vem da policy do repo" grep_max 200
assert_json_num "worker_min vem da policy do repo" worker_min 500
sp SHUNT_GREP_MAX=77
assert_json_num "SHUNT_GREP_MAX sobrescreve" grep_max 77
sp SHUNT_MIN_LINES=999
assert_json_num "SHUNT_MIN_LINES sobrescreve worker_min" worker_min 999
LIXO="$TMP/policy-lixo.json"; echo '{nao é json' > "$LIXO"
sp SHUNT_POLICY="$LIXO"
assert_rc "policy corrompida não propaga exceção" 0
assert_json_num "policy corrompida cai no default" grep_max 200
sp SHUNT_POLICY="$TMP/nao-existe.json"
assert_json_num "policy ausente cai no default" worker_min 500

echo "== read_size_guard: o bloqueio roteia por degrau =="
ENORME="$TMP/enorme.md"; seq 1 900 > "$ENORME"
run_hook read_size_guard.py "$(p_read "$GRANDE")"
assert_bloqueia_json "250 linhas (entre os degraus) bloqueia"
[[ "$OUT" == *"offset"* ]] && ok "entre os degraus, rota é Read paginado" \
  || fail "entre os degraus sem rota de paginação ($OUT)"
[[ "$OUT" != *"--task scan"* ]] && ok "entre os degraus não manda pro worker" \
  || fail "entre os degraus mandou pro worker ($OUT)"
run_hook read_size_guard.py "$(p_read "$ENORME")"
assert_bloqueia_json "900 linhas bloqueia"
[[ "$OUT" == *"--task scan"* ]] && ok "acima do worker_min, rota é delegate scan" \
  || fail "acima do worker_min sem rota pro worker ($OUT)"
[[ "$OUT" == *"$ENORME"* ]] && ok "comando sugerido traz o path real" \
  || fail "comando sugerido sem o path ($OUT)"
run_hook read_size_guard.py "$(p_read "$ENORME")" SHUNT_MIN_LINES=2000
assert_bloqueia_json "worker_min alto rebaixa 900 linhas pra paginação"
[[ "$OUT" != *"--task scan"* ]] && ok "threshold por env muda a rota" \
  || fail "threshold por env não mudou a rota ($OUT)"

echo "== bash_read_guard: despejo por Bash apanha igual ao Read =="
# Sem esta linha, hook ausente deixa todo assert_libera_json passar por stdout vazio.
[[ -f "$H/bash_read_guard.py" ]] && ok "hook existe em disco" || fail "hook bash_read_guard.py não existe"
p_cmd() { python3 -c 'import json,sys; print(json.dumps({"tool_name":"Bash","tool_input":{"command":sys.argv[1]}}))' "$1"; }
run_hook bash_read_guard.py "$(p_cmd "cat $GRANDE")"
assert_bloqueia_json "cat de arquivo grande bloqueia"
run_hook bash_read_guard.py "$(p_cmd "cat $PEQUENO")"
assert_libera_json "cat de arquivo pequeno libera"
run_hook bash_read_guard.py "$(p_cmd "cat $GRANDE | grep foo")"
assert_libera_json "cat grande com pipe que filtra libera"
run_hook bash_read_guard.py "$(p_cmd "cat $GRANDE | rg foo")"
assert_libera_json "pipe pro rg libera"
run_hook bash_read_guard.py "$(p_cmd "cat $GRANDE | wc -l")"
assert_libera_json "pipe pro wc libera"
run_hook bash_read_guard.py "$(p_cmd "head -50 $GRANDE")"
assert_libera_json "head -50 é paginação, libera"
run_hook bash_read_guard.py "$(p_cmd "head -400 $ENORME")"
assert_bloqueia_json "head -400 passa do grep_max, bloqueia"
run_hook bash_read_guard.py "$(p_cmd "tail -20 $GRANDE")"
assert_libera_json "tail -20 libera"
run_hook bash_read_guard.py "$(p_cmd "sed -n '1,40p' $GRANDE")"
assert_libera_json "sed -n com range pequeno libera"
run_hook bash_read_guard.py "$(p_cmd "cat $GRANDE > /tmp/copia.md")"
assert_libera_json "redirect não entra no transcript, libera"
run_hook bash_read_guard.py "$(p_cmd "rtk read $GRANDE")"
assert_bloqueia_json "rtk read é o mesmo despejo com outro nome"
run_hook bash_read_guard.py "$(p_cmd "cat $PEQUENO $GRANDE")"
assert_bloqueia_json "soma das linhas passa do degrau"
run_hook bash_read_guard.py "$(p_cmd "cat")"
assert_libera_json "cat sem argumento não é leitura de arquivo"
run_hook bash_read_guard.py "$(p_cmd "cat $IMAGEM")"
assert_libera_json "imagem é isenta"
run_hook bash_read_guard.py "$(p_cmd "cat $TMP/nao-existe.md")"
assert_libera_json "arquivo inexistente libera"
run_hook bash_read_guard.py "$(p_cmd "git status")"
assert_libera_json "comando que não lê arquivo não é assunto"
run_hook bash_read_guard.py '{nao é json'
assert_libera_json "payload inválido não quebra sessão"
run_hook bash_read_guard.py "$(p_cmd "cat $GRANDE")" BASH_READ_GUARD_DISABLED=1
assert_libera_json "kill switch libera"
run_hook bash_read_guard.py "$(p_cmd "cat $ENORME")"
[[ "$OUT" == *"--task scan"* ]] && ok "acima do worker_min roteia pro worker" \
  || fail "sem rota pro worker ($OUT)"

echo "== settings.json: o guard roda antes do rtk =="
ORDEM=$(jq -r '.hooks.PreToolUse[] | select(.matcher=="Bash") | .hooks[].command' "$HERE/../settings.json")
i_guard=$(grep -n bash_read_guard <<<"$ORDEM" | cut -d: -f1)
i_rtk=$(grep -n rtk-hook-wrapper <<<"$ORDEM" | cut -d: -f1)
if [[ -n "$i_guard" && -n "$i_rtk" && "$i_guard" -lt "$i_rtk" ]]; then
  ok "bash_read_guard registrado antes do rtk-hook-wrapper"
else
  fail "ordem dos hooks de Bash não põe o guard antes do rtk"
fi

echo "== rtk-hook-wrapper: leitura de arquivo sai do rewrite =="
W="$HERE/../scripts/rtk-hook-wrapper.sh"
wrap() { OUT=$(printf '%s' "$1" | bash "$W" 2>/dev/null); RC=$?; }
wrap "$(p_cmd "cat $GRANDE")"
[[ -z "$OUT" ]] && ok "cat não é mais reescrito pro rtk read" || fail "cat ainda reescrito ($OUT)"
wrap "$(p_cmd "head -20 $GRANDE")"
[[ -z "$OUT" ]] && ok "head não é reescrito" || fail "head ainda reescrito ($OUT)"
wrap "$(p_cmd 'git commit -m x')"
[[ -z "$OUT" ]] && ok "git commit segue bypassado" || fail "git commit foi reescrito ($OUT)"
if command -v rtk >/dev/null 2>&1; then
  wrap "$(p_cmd 'git status')"
  [[ "$OUT" == *"rtk git status"* ]] && ok "git status segue reescrito pro rtk" \
    || fail "git status deixou de ser reescrito ($OUT)"
else
  ok "rtk ausente: rewrite de git status não testável nesta máquina (skip)"
fi

echo
echo "== $PASS passed, $FAIL failed =="
[[ $FAIL -eq 0 ]]
