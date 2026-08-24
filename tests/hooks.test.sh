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

echo
echo "== $PASS passed, $FAIL failed =="
[[ $FAIL -eq 0 ]]
