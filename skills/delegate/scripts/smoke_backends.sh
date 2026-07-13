#!/usr/bin/env bash
# smoke_backends.sh — eval de conformidade real (sem mock) pro roteamento do
# delegate: invoca CADA modelo/pool de ~/.claude/config/model-policy.json com
# um prompt trivial e confirma que a resposta não vem vazia.
#
# delegate.test.sh é 100% mockado — nunca pegaria um pool que responde vazio
# com rc=0 do lado real do provider (achado em produção, 2026-07-08: todo o
# pool "gemini" do backend agy fazia isso, silenciosamente contado como
# sucesso pela cascata). Este script fecha esse ponto cego.
#
# Efeito colateral intencional: usa os MESMOS arquivos de cooldown que
# delegate.sh lê (~/.claude/gate/cooldown.<backend[:pool]>) — pool vazio aqui
# arma cooldown real, pool que respondeu limpa cooldown stale. Rodar isto
# antes de uma sessão que vai delegar pesado deixa a cascata com estado
# fresco em vez de descobrir no meio de uma task real.
#
# Não desabilita nada na policy: tiers resetam (ex.: semanal) — cooldown
# reativo (60min default) já revalida sozinho a cada nova chamada.
#
# Uso: smoke_backends.sh [--task <type>]   (default: sonda todo backend/model
# habilitado na policy, independente de cascata; --task restringe à cascata
# daquela task, útil pra checar só o que uma task específica vai tentar)
set -uo pipefail

GATE_DIR="${DELEGATE_GATE_DIR:-$HOME/.claude/gate}"
POLICY="${DELEGATE_POLICY:-$HOME/.claude/config/model-policy.json}"
mkdir -p "$GATE_DIR"

PROMPT="responda apenas a palavra: ok"
TASK_FILTER=""
[[ "${1:-}" == "--task" ]] && TASK_FILTER="$2"

pool_key() {
    local p=""
    [[ -n "${2:-}" ]] && p=$(jq -r --arg b "$1" --arg m "$2" \
        '.backends[$b].pools // {} | to_entries[] | select(.value | index($m)) | .key' "$POLICY" 2>/dev/null | head -1)
    echo "$1${p:+:$p}"
}
arm_cooldown()   { date +%s > "$GATE_DIR/cooldown.$1"; }
clear_cooldown() { rm -f "$GATE_DIR/cooldown.$1"; }

# --- monta a lista de (backend, model) a sondar ---
if [[ -n "$TASK_FILTER" ]]; then
    PROBE_LIST=$(jq -c --arg t "$TASK_FILTER" '.tasks[$t] // empty | .[] | {backend, model: (.model // null)}' "$POLICY")
    [[ -n "$PROBE_LIST" ]] || { echo "smoke: task-type '$TASK_FILTER' não existe na policy" >&2; exit 1; }
else
    # todo backend habilitado; se tiver .models, sonda cada um — senão, sonda o backend puro
    PROBE_LIST=$(jq -c '
        .backends | to_entries[] | select(.value.enabled) |
        (if ((.value.models // []) | length) > 0
         then .value.models[] as $m | {backend: .key, model: $m}
         else {backend: .key, model: null} end)
    ' "$POLICY")
fi

PASS=0 FAIL=0 SKIP=0
while IFS= read -r entry; do
    backend=$(jq -r '.backend' <<<"$entry")
    model=$(jq -r '.model' <<<"$entry")
    [[ "$model" == "null" ]] && model=""
    pkey=$(pool_key "$backend" "$model")

    scope=$(jq -r --arg b "$backend" '.backends[$b].scope_pattern // empty' "$POLICY")
    if [[ -n "$scope" && "$PWD" != *"$scope"* ]]; then
        echo "○ SKIP  $pkey${model:+ [$model]} — scope_pattern '$scope' não casa com cwd"
        SKIP=$((SKIP+1)); continue
    fi
    envvar=$(jq -r --arg b "$backend" '.backends[$b].env_var // empty' "$POLICY")
    if [[ -n "$envvar" ]]; then
        envfile=$(jq -r --arg b "$backend" '.backends[$b].env_file // empty' "$POLICY")
        grep -qm1 "^${envvar}=." "$envfile" 2>/dev/null || { echo "○ SKIP  $pkey — sem $envvar em $envfile"; SKIP=$((SKIP+1)); continue; }
    fi

    bin=$(jq -r --arg b "$backend" '.backends[$b].bin // $b' "$POLICY")
    command -v "$bin" >/dev/null 2>&1 || { echo "○ SKIP  $pkey — CLI '$bin' ausente"; SKIP=$((SKIP+1)); continue; }

    cmd=$(jq -r --arg b "$backend" '.backends[$b].invoke' "$POLICY")
    prompt_via=$(jq -r --arg b "$backend" '.backends[$b].prompt_via // "arg"' "$POLICY")
    model_flag=$(jq -r --arg b "$backend" '.backends[$b].model_flag // empty' "$POLICY")

    out=$(mktemp)
    if [[ "$prompt_via" == "stdin" ]]; then
        echo "$PROMPT" | timeout 60 $cmd > "$out" 2>&1
    elif [[ -n "$model" && -n "$model_flag" ]]; then
        timeout 60 $cmd "$PROMPT" "$model_flag" "$model" < /dev/null > "$out" 2>&1
    else
        timeout 60 $cmd "$PROMPT" < /dev/null > "$out" 2>&1
    fi
    rc=$?

    if [[ $rc -eq 0 ]] && grep -qE '[^[:space:]]' "$out"; then
        echo "✓ OK    $pkey${model:+ [$model]}"
        clear_cooldown "$pkey"
        PASS=$((PASS+1))
    elif [[ $rc -eq 0 ]]; then
        echo "✗ VAZIO $pkey${model:+ [$model]} — rc=0 mas stdout vazio (falha silenciosa do provider)"
        arm_cooldown "$pkey"
        FAIL=$((FAIL+1))
    else
        echo "✗ FALHA $pkey${model:+ [$model]} — rc=$rc: $(head -c 120 "$out" | tr '\n' ' ')"
        arm_cooldown "$pkey"
        FAIL=$((FAIL+1))
    fi
    rm -f "$out"
done <<<"$PROBE_LIST"

echo ""
echo "== $PASS ok, $FAIL falha/vazio, $SKIP pulado =="
[[ $FAIL -eq 0 ]]
