#!/usr/bin/env bash
# delegate.sh — dispatcher multi-modelo (SPEC-2026-002)
#
#   delegate.sh --task <review|implement|scan|boilerplate>
#   delegate.sh --task implement --tier <padrao|amplo>   # tier troca o ponto de entrada
#               [--model <backend>] [--worktree <repo-dir>] [--continue <slug>]
#               [--timeout N] [--gc <repo-dir>] -
#
#   Modo bulk (o script monta o prompt, sem heredoc):
#   delegate.sh --task scan --paths <f1> <f2>... --question "<pergunta>"
#   delegate.sh --task boilerplate --paths <f>... --question "<spec>" --reference <f>
#
#   --paths/--question andam sempre juntos; um sem o outro é erro de uso. Em
#   --task boilerplate o --reference é obrigatório nesse modo: sem padrão a
#   seguir, o worker gera código que não encaixa em nada e a revisão custa mais
#   que escrever à mão.
#
#   --continue <slug>: reusa a worktree/branch delegate/<slug> já criada (não
#   remonta prompt do zero; a mensagem que vem pelo stdin vira um follow-up
#   commitado na mesma branch). Slug inexistente → erro claro, nunca cria nova
#   silenciosamente.
#
#   Prompt via stdin ('-' obrigatório). Resposta no stdout.
#   Roteamento vem de ~/.claude/config/model-policy.json (dado, não código):
#   custo zero primeiro; Claude Code é o fallback implícito quando a cascata esgota.
#
# Exit codes: 0 ok · 2 nenhum worker disponível (a sessão assume) · 1 erro de uso ·
# 5 worker rodou mas não produziu diff/commit em --worktree (falha silenciosa suspeita).
# (3=cooldown e 4=CLI ausente são internos à cascata, nunca externalizados.)
#
# Modo --worktree: cria git worktree + branch delegate/<slug>, roda o worker com
# sandbox nativo do CLI confinado ao diretório, reporta a branch. NUNCA mergeia —
# revisão e integração são do orquestrador. Backend sem worktree_invoke na policy
# não é elegível pra este modo.
#
# Kill switch: DELEGATE_DISABLED=1 → exit 2 (a sessão assume tudo).
# Overrides p/ teste: DELEGATE_POLICY, DELEGATE_GATE_DIR, DELEGATE_INBOX.

set -uo pipefail

GATE_DIR="${DELEGATE_GATE_DIR:-$HOME/.claude/gate}"
POLICY="${DELEGATE_POLICY:-$HOME/.claude/config/model-policy.json}"
# Override project-specific (finding_routing) vive em
# <base>.local.json (gitignored). Merge base * local (deep; arrays do local vencem).
# Espelho consciente de model-policy-effective.sh — manter em sincronia.
_LOCAL_POLICY="${POLICY%.json}.local.json"
if [[ -f "$_LOCAL_POLICY" ]] && jq -e . "$POLICY" >/dev/null 2>&1 && jq -e . "$_LOCAL_POLICY" >/dev/null 2>&1; then
    _EFF=$(mktemp); jq -s '.[0] * .[1]' "$POLICY" "$_LOCAL_POLICY" > "$_EFF" && POLICY="$_EFF"
fi
INBOX="${DELEGATE_INBOX:-$HOME/.claude/inbox.md}"
LOG="$GATE_DIR/delegate.log"
COOLDOWN_MINS="${PEER_COOLDOWN_MINS:-60}"
# Falha transiente de provider (modelo 404, sem acesso) não é o mesmo bicho que
# rate limit: passa em minutos, não em uma hora. Cooldown curto tira o custo de
# ficar batendo numa janela ruim sem esconder o backend quando ela passa.
TRANSIENT_COOLDOWN_MINS="${DELEGATE_TRANSIENT_COOLDOWN_MINS:-10}"
mkdir -p "$GATE_DIR"; touch "$LOG"; chmod 600 "$LOG"

die() { echo "delegate: $*" >&2; exit 1; }

log_usage() { # task backend status detail pool [bytes_in] [bytes_out] [dur_s]
    # bytes_* existem pra calibrar o threshold do shunt (config .shunt) com
    # número em vez de palpite: sem tamanho, "quanto o scan economizou" não tem
    # resposta. dur_s existe pelo mesmo motivo, pra `.timeouts`: sem duração
    # gravada, "300s em review é suficiente?" só tinha resposta por cronômetro na
    # mão, e o número da policy envelhecia calado quando o modelo da cascata
    # mudava. jq escapa os campos (JSONL sempre válido).
    local bin bout dur
    bin=$(tr -dc '0-9' <<<"${6:-0}"); bout=$(tr -dc '0-9' <<<"${7:-0}")
    dur=$(tr -dc '0-9' <<<"${8:-0}")
    jq -cn --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" --arg task "$1" --arg backend "$2" \
        --arg status "$3" --arg detail "${4:-}" --arg pool "${5:-}" \
        --argjson bytes_in "${bin:-0}" --argjson bytes_out "${bout:-0}" \
        --argjson dur_s "${dur:-0}" \
        '{ts:$ts,task:$task,backend:$backend,status:$status,detail:$detail,pool:$pool,bytes_in:$bytes_in,bytes_out:$bytes_out,dur_s:$dur_s}' >> "$LOG"
}

# --- pool: só rótulo pro log de auditoria; prioridade real vem da ordem da cascata na policy ---
pool_key() { # backend model → chave de bolsão ("backend" ou "backend:pool")
    local p=""
    [[ -n "${2:-}" ]] && p=$(jq -r --arg b "$1" --arg m "$2" \
        '.backends[$b].pools // {} | to_entries[] | select(.value | index($m)) | .key' "$POLICY" 2>/dev/null | head -1)
    echo "$1${p:+:$p}"
}

# --- cooldown per-backend (mesmo mecanismo do peer-review) ---
cooldown_remaining() { # backend → 0 + segundos restantes se ativo; 1 se livre
    local f="$GATE_DIR/cooldown.$1"
    [[ -f "$f" ]] || return 1
    local armed now rem
    armed=$(cat "$f" 2>/dev/null) || return 1
    now=$(date +%s)
    rem=$(( armed + COOLDOWN_MINS*60 - now ))
    if (( rem > 0 )); then echo "$rem"; return 0; fi
    rm -f "$f"; return 1
}
arm_cooldown()   { date +%s > "$GATE_DIR/cooldown.$1"; }
# Transiente arma com o relógio adiantado, pra expirar em TRANSIENT_COOLDOWN_MINS
# usando o mesmo cooldown_remaining de sempre (um mecanismo, não dois).
arm_transient_cooldown() { echo $(( $(date +%s) - (COOLDOWN_MINS - TRANSIENT_COOLDOWN_MINS)*60 )) > "$GATE_DIR/cooldown.$1"; }
clear_cooldown() { rm -f "$GATE_DIR/cooldown.$1"; }

is_ratelimit() { grep -qiE "(rate.?limit|too many requests|status.*429|quota.*(exceeded|reached)|usage limit|limit reached|out of (credits|tokens)|insufficient_quota|RESOURCE_EXHAUSTED)" "$1"; }

# Janela ruim de provider, e não backend morto. Medido em 07/set/2026: o mesmo
# `codex exec --model gpt-5.5` respondeu às 19h06 e devolveu 404 "does not exist
# or you do not have access" às 19h31, no mesmo diretório e na mesma conta; os 7
# nomes de modelo do CLI acompanharam a janela em bloco. Esse sinal NUNCA vira
# `enabled: false` na policy: um fato que depende da hora não é decisão de
# roteamento, e desabilitar apaga um tier que funciona parte do tempo.
# Worker que desiste nem sempre devolve vazio: às vezes devolve uma desculpa
# curta com rc=0, e aí a guarda de vazio não dispara. Medido em 2026-09-15:
# 320.985 bytes entraram, 56 voltaram ("warning: run ended with no output and no
# recorded error"), e a chamada foi gravada como ok. Desculpa é falha do pool,
# tratada como o vazio: cooldown e cascata desce.
is_sem_resposta() { grep -qiE "(run ended with no output|no recorded error|no output (was )?(produced|generated)|i (was |am )?(unable|not able) to (process|complete|read)|context (length|window) exceeded|prompt is too long|input too large)" "$1"; }

is_transient() { grep -qiE "(does not exist or you do not have access|model .* not (found|supported)|status 404|502 bad gateway|503 service unavailable|504 gateway timeout|overloaded_error|temporarily unavailable)" "$1"; }

# --- args ---
TASK="" TIER="" FORCE_MODEL="" WORKTREE="" TIMEOUT="" GC="" BASE_REF="" CONTINUE_SLUG=""
QUESTION="" REFERENCE="" PATHS=() EXPECT_LINES="" EXPECT_REGEX=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --task) TASK="$2"; shift 2 ;;
        --tier) TIER="$2"; shift 2 ;;
        --question) QUESTION="$2"; shift 2 ;;
        --reference) REFERENCE="$2"; shift 2 ;;
        --expect-lines) EXPECT_LINES="$2"; shift 2 ;;
        --expect-regex) EXPECT_REGEX="$2"; shift 2 ;;
        # variádico: consome até a próxima flag (ou o '-' do modo heredoc)
        --paths) shift; while [[ $# -gt 0 && "$1" != -* ]]; do PATHS+=("$1"); shift; done ;;
        --model) FORCE_MODEL="$2"; shift 2 ;;
        --worktree) WORKTREE="$2"; shift 2 ;;
        --continue) CONTINUE_SLUG="$2"; shift 2 ;;
        --timeout) TIMEOUT="$2"; shift 2 ;;
        --gc) GC="$2"; shift 2 ;;
        --base) BASE_REF="$2"; shift 2 ;;
        -) shift ;;
        *) die "arg desconhecido: $1" ;;
    esac
done

if [[ -n "$GC" ]]; then
    git -C "$GC" worktree prune
    git -C "$GC" worktree list | grep 'delegate/' || echo "nenhuma worktree delegate/ ativa"
    exit 0
fi

if [[ "${DELEGATE_DISABLED:-0}" == "1" ]]; then
    echo "delegate: desabilitado via DELEGATE_DISABLED, a sessão assume." >&2
    log_usage "${TASK:-?}" "-" "disabled" "kill switch"
    exit 2
fi

[[ -n "$TASK" ]] || die "uso: delegate.sh --task <type> [--model B] [--worktree DIR] [--continue SLUG] - < prompt"
[[ -z "$TIMEOUT" || "$TIMEOUT" =~ ^[0-9]+$ ]] || die "--timeout deve ser inteiro em segundos (recebido: '$TIMEOUT')"

# --- modo bulk: o script monta o prompt em vez de cobrar heredoc do chamador ---
# Existe porque a fricção matava o shunt: no log, 211 chamadas de review (que o
# peer-review.sh dispara sozinho) contra 22 de scan e 3 de boilerplate. O que
# dependia de montar heredoc à mão não era chamado.
BULK=0
if [[ ${#PATHS[@]} -gt 0 || -n "$QUESTION" ]]; then
    BULK=1
    [[ ${#PATHS[@]} -gt 0 ]] || die "--question exige --paths <arquivo>... (as duas flags andam juntas)"
    [[ -n "$QUESTION" ]] || die "--paths exige --question \"<pergunta>\" (as duas flags andam juntas)"
    for _p in "${PATHS[@]}"; do
        [[ -f "$_p" ]] || die "--paths: arquivo não existe: $_p"
    done
    [[ -z "$REFERENCE" || -f "$REFERENCE" ]] || die "--reference: arquivo não existe: $REFERENCE"
    if [[ "$TASK" == "boilerplate" && -z "$REFERENCE" ]]; then
        die "--task boilerplate exige --reference <arquivo>: sem padrão a seguir, o worker gera código sem contexto que não encaixa no projeto"
    fi
fi

# --- policy load (inválida → fallback default RUIDOSO) ---
# Degradação troca a ORIGEM dos dados, não o caminho: uma DEFAULT_POLICY mínima
# embutida roda pelo mesmo jq de sempre (zero conhecimento de backend em case/if).
# Espelho consciente de config/model-policy.json — manter em sincronia ao mudar flags de CLI.
if ! jq -e . "$POLICY" >/dev/null 2>&1; then
    echo "⚠️  delegate: policy inválida ($POLICY) — usando policy default embutida codex→agy (modo degradado)" >&2
    log_usage "$TASK" "-" "policy_invalid" "fallback default policy"
    inbox_line="- [ ] **[S]** model-policy.json inválida em $(date +%Y-%m-%d) — delegate rodando em cascata default; corrigir e validar com jq — owner: ${DELEGATE_OWNER:-dono do repo}"
    grep -qF "$inbox_line" "$INBOX" 2>/dev/null || echo "$inbox_line" >> "$INBOX"
    POLICY=$(mktemp)
    cat > "$POLICY" <<'JSON'
{
  "backends": {
    "codex": {"enabled": true, "prompt_via": "stdin",
              "invoke": "codex exec --skip-git-repo-check -",
              "worktree_invoke": "codex exec --sandbox workspace-write --full-auto -"},
    "agy":   {"enabled": true, "prompt_via": "arg", "model_flag": "--model",
              "invoke": "agy --sandbox --dangerously-skip-permissions --mode plan --print-timeout 15m -p",
              "worktree_invoke": "agy --dangerously-skip-permissions --add-dir {worktree} --print-timeout 30m -p"}
  },
  "tasks": {"_any": [{"backend": "codex"}, {"backend": "agy"}]}
}
JSON
fi
# Tier troca o PONTO DE ENTRADA da cascata, não o task-type: só o tier amplo é
# declarado na policy, e padrão (ou tier ausente) resolve a lista de tasks.<task>.
# Duas listas da mesma fila divergiriam, e foi o que já aconteceu com a matriz.
CASCADE=$(jq -c --arg t "$TASK" --arg tier "$TIER" '.tiers[$t][$tier]? // .tasks[$t] // .tasks["_any"] // empty' "$POLICY")
[[ -n "$CASCADE" ]] || die "task-type desconhecido na policy: $TASK"

# O conjunto de tiers válidos sai da policy. `padrao` é o implícito e nunca é
# declarado (é tasks.<task>), então entra aqui e não lá. Tier que a task não
# declara é erro, e não fila padrão calada: pedir amplo e receber padrão é
# exatamente a divergência que o tier existe pra evitar.
if [[ -n "$TIER" ]]; then
    TIERS_OK=$(jq -r --arg t "$TASK" '["padrao"] + (.tiers[$t] // {} | keys) | join("|")' "$POLICY")
    [[ "|$TIERS_OK|" == *"|$TIER|"* ]] || die "--tier '$TIER' não existe em '$TASK'; a policy declara: $TIERS_OK"
fi

# --- review espelha a classe da sessão master ---
# Fila fixa punia o dono: em sessão Fable o revisor saía de classe abaixo do
# master. O pairing filtra e ordena tasks.review pela classe em curso. `/model`
# em runtime não reescreve settings.json, então DELEGATE_SESSION_CLASS é o
# override manual, e classe desconhecida mantém a ordem declarada na policy.
session_class() {
    local m="${DELEGATE_SESSION_CLASS:-}" k
    [[ -n "$m" ]] || m=$(jq -r '.model // empty' "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/settings.json" 2>/dev/null)
    for k in $(jq -r '.review_pairing // {} | keys[] | select(startswith("$") | not)' "$POLICY"); do
        [[ "$m" == *"$k"* ]] && { echo "$k"; return; }
    done
    echo ""
}
if [[ "$TASK" == "review" ]]; then
    SESSION_CLASS=$(session_class)
    PAIR_ORDER=$(jq -c --arg c "${SESSION_CLASS:-none}" '.review_pairing[$c] // empty' "$POLICY")
    if [[ -n "$PAIR_ORDER" ]]; then
        paired=$(jq -c --argjson ord "$PAIR_ORDER" \
            '[.[] | select(.model as $m | $ord | index($m))] | sort_by(.model as $m | $ord | index($m))' <<<"$CASCADE")
        # pairing que não cruza com a cascata não vale silêncio nem cascata vazia
        if [[ -n "$paired" && "$paired" != "[]" ]]; then
            CASCADE="$paired"
            echo "▶ review na classe da sessão ($SESSION_CLASS)" >&2
        else
            echo "⚠️  review_pairing.$SESSION_CLASS não cruza com tasks.review — usando a ordem declarada" >&2
        fi
    fi
fi

[[ -n "$TIMEOUT" ]] || TIMEOUT=$(jq -r --arg t "$TASK" '.timeouts[$t] // 120' "$POLICY")

# --- timeout wrapper ---
if command -v gtimeout >/dev/null 2>&1; then TIMEOUT_CMD="gtimeout $TIMEOUT"
elif command -v timeout >/dev/null 2>&1; then TIMEOUT_CMD="timeout $TIMEOUT"
else TIMEOUT_CMD=""; fi

PROMPT_FILE=$(mktemp); TMP_OUT=$(mktemp)
trap 'rm -f "$PROMPT_FILE" "$TMP_OUT"' EXIT
abs_path() { case "$1" in /*) printf '%s' "$1" ;; *) printf '%s/%s' "$PWD" "$1" ;; esac; }

build_bulk_prompt() { # pergunta + corpus em tag XML + contrato de saída
    printf 'Pergunta: %s\n\n' "$QUESTION"
    printf 'Responda usando SÓ o conteúdo dos arquivos abaixo. Cada arquivo vem\n'
    printf 'delimitado por tag, com o caminho absoluto no atributo path.\n\n'
    if [[ -n "$REFERENCE" ]]; then
        printf '<reference path="%s">\n' "$(abs_path "$REFERENCE")"
        cat "$REFERENCE"
        printf '\n</reference>\n\n'
        printf 'A tag reference é o padrão a seguir: mesma estrutura, mesmas\n'
        printf 'convenções, mesmo estilo. Não invente padrão novo.\n\n'
    fi
    local f
    for f in "${PATHS[@]}"; do
        printf '<file path="%s">\n' "$(abs_path "$f")"
        cat "$f"
        printf '\n</file>\n'
    done
    printf '\n---\nFormato da resposta: bullets estruturados, sem prosa, sem preâmbulo,\n'
    printf 'sem saudação e sem repetir a pergunta. Cite path e linha quando afirmar\n'
    printf 'algo sobre o código. O que os arquivos não respondem, diga que não\n'
    printf 'responde, em vez de inferir.\n'
}

if [[ "$BULK" == "1" ]]; then
    build_bulk_prompt > "$PROMPT_FILE"
else
    cat > "$PROMPT_FILE"   # stdin
fi

# --- validação do prompt: falha alto em vez de delegar lixo silenciosamente ---
if [[ ! -s "$PROMPT_FILE" ]] || ! grep -qE '[^[:space:]]' "$PROMPT_FILE"; then
    die "prompt vazio (stdin) — nada foi lido antes de '-'; confira o heredoc/pipe do chamador"
fi
# Prompt grande não falha na hora: ele queima o timeout inteiro e devolve
# desculpa. Recusar aqui custa zero e diz o que fazer; o teto vem da policy
# porque é número medido, e número medido muda.
PROMPT_BYTES=$(wc -c < "$PROMPT_FILE" | tr -d ' ')
WARN_BYTES=$(jq -r '.limits.prompt_warn_bytes // 100000' "$POLICY")
MAX_BYTES=$(jq -r '.limits.prompt_max_bytes // 250000' "$POLICY")
if (( PROMPT_BYTES > MAX_BYTES )); then
    log_usage "$TASK" "-" "oversize" "bytes=$PROMPT_BYTES max=$MAX_BYTES" "" "$PROMPT_BYTES" 0
    die "prompt de $PROMPT_BYTES bytes passa do teto de $MAX_BYTES: fatie o corpus (--paths menor, ou uma pergunta por rodada). Acima do teto o worker estoura o timeout e devolve desculpa, e a chamada custa ${TIMEOUT:-600}s pra não produzir nada."
fi
if (( PROMPT_BYTES > WARN_BYTES )); then
    echo "⚠️  prompt de $PROMPT_BYTES bytes: acima de $WARN_BYTES o log não tem caso de sucesso. Se voltar curto, fatie." >&2
fi

if head -c 200 "$PROMPT_FILE" | grep -qE '^\{"backend"'; then
    die "prompt suspeito: parece JSON de cascata da policy (\"{\\\"backend\\\":...\") em vez de texto de tarefa — chamador vazou dado interno no lugar do prompt"
fi

# --- contrato de report: todo worker recebe o footer, não só a tarefa ---
# Bulk one-shot não recebe o footer: ele pede 3 seções de relato numa tarefa que
# não roda verify nem toca arquivo, e output token de worker também custa tempo
# de leitura aqui. O contrato de saída do bulk é o de bullets, montado acima.
if [[ "$BULK" != "1" || -n "$WORKTREE" ]]; then
    REPORT_FOOTER=$'\n\n---\nContrato de report obrigatório ao final da resposta:\n1. Rode a verificação declarada na task e cole o output (comando + resultado).\n2. Liste os arquivos tocados (paths absolutos).\n3. Declare explicitamente o que NÃO foi feito (escopo cortado, TODO deixado, etc).\nResposta sem essas 3 seções é considerada incompleta.'
    printf '%s' "$REPORT_FOOTER" >> "$PROMPT_FILE"
fi

backend_field() { # backend field → valor da policy (ou vazio)
    jq -r --arg b "$1" --arg f "$2" '.backends[$b][$f] // empty' "$POLICY"
}
backend_enabled() {
    [[ "$(jq -r --arg b "$1" '.backends[$b].enabled // false' "$POLICY")" == "true" ]]
}

invoke_backend() { # backend model → rc semântico (0 ok, 3 cooldown/ratelimit, 4 ausente, 1 falha)
    local backend="$1" model="$2" effort="${3:-}" rem cmd model_flag effort_config
    # cooldown por pool (backend:pool), não por backend inteiro — agy tem pools
    # independentes (gemini vs claude_gpt); um pool ruim não deve derrubar o outro.
    local pkey; pkey=$(pool_key "$backend" "$model")
    if rem=$(cooldown_remaining "$pkey"); then
        echo "▶ $pkey em cooldown (~$(( (rem+59)/60 ))min)" >&2; return 3
    fi
    backend_enabled "$backend" || { echo "▶ $backend desabilitado na policy" >&2; return 4; }
    local bin; bin=$(backend_field "$backend" bin)
    command -v "${bin:-$backend}" >/dev/null 2>&1 || return 4

    if [[ -n "$WORKTREE" ]]; then
        cmd=$(backend_field "$backend" worktree_invoke)
        [[ -n "$cmd" ]] || { echo "▶ $backend sem worktree_invoke (sandbox) — inelegível pra worktree" >&2; return 4; }
        # {worktree} vira o caminho absoluto da worktree. Existe porque `cd` não
        # basta em todo worker: o agy não começa no cwd e seu --sandbox restringe
        # terminal, não sistema de arquivos, então sem passar o caminho ele sai
        # caçando a raiz do repo e escreve na árvore principal.
        cmd="${cmd//\{worktree\}/$WT_DIR}"
    else
        cmd=$(backend_field "$backend" invoke)
        [[ -n "$cmd" ]] || return 4
    fi

    echo "▶ delegando ($TASK) → $backend${model:+ [$model]}..." >&2
    local prompt_via; prompt_via=$(backend_field "$backend" prompt_via)
    [[ -n "$prompt_via" ]] || prompt_via=arg
    model_flag=$(backend_field "$backend" model_flag)
    effort_config=$(backend_field "$backend" effort_config)
    local effort_flag; effort_flag=$(backend_field "$backend" effort_flag)

    # Modelo e esforço vêm da ENTRADA da cascata (policy `tasks.<task>[]`), não
    # do config global do CLI: é o que deixa review pedir mais cabeça que scan
    # sem tocar em ~/.codex/config.toml. Backend sem effort_config ignora effort.
    local -a extra=()
    [[ -n "$model" && -n "$model_flag" ]] && extra+=("$model_flag" "$model")
    [[ -n "$effort" && -n "$effort_config" ]] && extra+=(-c "$effort_config=$effort")
    # claude pede esforço por flag; codex por -c chave=valor. Backend sem os dois ignora.
    [[ -n "$effort" && -n "$effort_flag" ]] && extra+=("$effort_flag" "$effort")

    local rc
    if [[ "$prompt_via" == "stdin" ]]; then
        # o `-` final do invoke é "prompt por stdin"; as flags entram antes dele
        local head="${cmd% -}" tail=""
        [[ "$head" != "$cmd" ]] && tail="-"
        env -u ANTHROPIC_API_KEY $TIMEOUT_CMD $head "${extra[@]}" $tail < "$PROMPT_FILE" > "$TMP_OUT" 2>&1; rc=$?
    else
        # </dev/null explícito: sem stdin próprio (prompt vai por --arg), o worker
        # herdaria o pipe do `while read` de run_cascade e drenaria o file
        # descriptor do loop — cascata parava na 1a entrada mesmo falhando.
        if [[ -n "$model" && -n "$model_flag" ]]; then
            env -u ANTHROPIC_API_KEY $TIMEOUT_CMD $cmd "$(cat "$PROMPT_FILE")" "$model_flag" "$model" < /dev/null > "$TMP_OUT" 2>&1; rc=$?
        else
            env -u ANTHROPIC_API_KEY $TIMEOUT_CMD $cmd "$(cat "$PROMPT_FILE")" < /dev/null > "$TMP_OUT" 2>&1; rc=$?
        fi
    fi

    if [[ $rc -eq 124 ]]; then echo "⚠️  $backend timeout (${TIMEOUT}s)" >&2; return 1; fi
    if [[ $rc -ne 0 ]]; then
        if is_ratelimit "$TMP_OUT"; then
            arm_cooldown "$pkey"
            echo "⚠️  $pkey rate-limited — cooldown armado (${COOLDOWN_MINS}min)" >&2
            return 3
        fi
        if is_transient "$TMP_OUT"; then
            arm_transient_cooldown "$pkey"
            echo "⚠️  $pkey em falha transiente de provider — cooldown curto armado (${TRANSIENT_COOLDOWN_MINS}min). O backend segue habilitado: janela ruim passa sozinha, e nunca vira enabled:false na policy." >&2
            return 3
        fi
        echo "⚠️  $backend falhou (rc=$rc):" >&2; cat "$TMP_OUT" >&2
        return 1
    fi

    # rc=0 mas stdout vazio (modo one-shot) = falha silenciosa, não sucesso.
    # Observado em produção (2026-07-08): pools com tier/cota esgotada do lado
    # do provider respondem vazio com rc=0 em vez de erro — o worker some sem
    # avisar. Trata como o mesmo sinal de rate-limit real (cooldown por pool,
    # cascata desce); nunca desabilita o pool na policy — tier reseta (ex.:
    # semanal), cooldown reativo já revalida sozinho na próxima chamada após
    # expirar, sem precisar de intervenção manual.
    if [[ -z "$WORKTREE" ]] && ! grep -qE '[^[:space:]]' "$TMP_OUT"; then
        arm_cooldown "$pkey"
        echo "⚠️  $pkey devolveu vazio (rc=0, falha silenciosa) — cooldown armado (${COOLDOWN_MINS}min)" >&2
        return 3
    fi

    if [[ -z "$WORKTREE" ]] && is_sem_resposta "$TMP_OUT"; then
        arm_cooldown "$pkey"
        echo "⚠️  $pkey devolveu desculpa em vez de resposta (rc=0) — cooldown armado (${COOLDOWN_MINS}min)" >&2
        return 3
    fi

    # Forma pedida não conferida é "voltou incompleto" virando resposta. Só o
    # chamador sabe a forma, então ela é opcional; quando declarada, cascata
    # desce sem cooldown: a forma errada é do worker, não do pool.
    if [[ -z "$WORKTREE" && -n "$EXPECT_LINES" ]]; then
        local linhas; linhas=$(grep -cE '[^[:space:]]' "$TMP_OUT" || true)
        if (( linhas < EXPECT_LINES )); then
            echo "⚠️  $backend devolveu $linhas linha(s); esperava >= $EXPECT_LINES linhas — cascata desce" >&2
            return 1
        fi
    fi
    if [[ -z "$WORKTREE" && -n "$EXPECT_REGEX" ]] && ! grep -qE "$EXPECT_REGEX" "$TMP_OUT"; then
        echo "⚠️  $backend devolveu resposta que não casa com --expect-regex — cascata desce" >&2
        return 1
    fi

    clear_cooldown "$pkey"
    return 0
}

# --- worktree setup ---
WT_DIR="" WT_BRANCH="" WT_BASE_SHA="" WT_FRESH=""
if [[ -n "$WORKTREE" ]]; then
    git -C "$WORKTREE" rev-parse --git-dir >/dev/null 2>&1 || die "--worktree: $WORKTREE não é repo git"
    # worktree é checkout separado — sujeira do repo principal não contamina o worker; só avisa.
    [[ -z "$(git -C "$WORKTREE" status --porcelain)" ]] || echo "⚠️  $WORKTREE tem alterações não commitadas (não bloqueia — worktree é isolada)" >&2

    if [[ -n "$CONTINUE_SLUG" ]]; then
        # reusa worktree/branch existente — não recria, não remonta prompt do zero
        WT_FRESH=0
        WT_BRANCH="delegate/$CONTINUE_SLUG"
        WT_DIR="$(git -C "$WORKTREE" rev-parse --path-format=absolute --git-common-dir)/../.delegate-wt/$CONTINUE_SLUG"
        git -C "$WT_DIR" rev-parse --git-dir >/dev/null 2>&1 || die "--continue: worktree do slug '$CONTINUE_SLUG' não existe em $WT_DIR — rode sem --continue pra criar uma nova"
        base_ref="${BASE_REF:-$(git -C "$WORKTREE" merge-base HEAD "$WT_BRANCH" 2>/dev/null)}"
        [[ -n "$base_ref" ]] || base_ref="$WT_BRANCH^"
        WT_BASE_SHA=$(git -C "$WORKTREE" rev-parse --short "$base_ref" 2>/dev/null || echo "?")
    else
        # base da worktree: --base explícito > repo.trunk do project.yaml > HEAD atual. NUNCA origin/main implícito.
        base_ref="$BASE_REF"
        if [[ -z "$base_ref" && -f "$WORKTREE/.claude/project.yaml" ]]; then
            base_ref=$(awk '/^repo:/{f=1;next} f && /^[^ ]/{f=0} f && /trunk:/{gsub(/^[ \t]*trunk:[ \t]*/,""); sub(/[ \t]*#.*$/,""); gsub(/["\x27]/,""); sub(/[ \t]+$/,""); print; exit}' "$WORKTREE/.claude/project.yaml")
        fi
        [[ -n "$base_ref" ]] || base_ref="HEAD"
        git -C "$WORKTREE" rev-parse --verify -q "$base_ref" >/dev/null || die "--base '$base_ref' não resolve em $WORKTREE"
        WT_BASE_SHA=$(git -C "$WORKTREE" rev-parse --short "$base_ref")

        slug="$TASK-$(date +%s | tail -c 6)$RANDOM"
        WT_BRANCH="delegate/$slug"
        WT_DIR="$(git -C "$WORKTREE" rev-parse --path-format=absolute --git-common-dir)/../.delegate-wt/$slug"
        git -C "$WORKTREE" worktree add -q -b "$WT_BRANCH" "$WT_DIR" "$base_ref" || die "falha ao criar worktree (base=$base_ref)"
        WT_FRESH=1
    fi
fi

# O caminho da worktree entra no PROMPT, e não só no `cd` e no --add-dir. Motivo
# medido: o agy não começa no cwd, ele abre na pasta de artefato dele. Sem o
# caminho escrito, o worker sai caçando a raiz do repo, acha a árvore principal
# e escreve lá. Foi assim que uma delegação deixou o working tree do dono meio
# editado. O `cd` normaliza o `/../` do WT_DIR pra ele servir os três consumidores
# (prompt, --add-dir da policy, mensagens de erro) com o mesmo caminho.
if [[ -n "$WT_DIR" ]]; then
    WT_DIR=$(cd "$WT_DIR" && pwd)
    { printf 'Diretório de trabalho: %s\n\nEsse é o caminho absoluto da sua worktree. Leia e escreva SÓ dentro dele, sempre pelo caminho absoluto. Se os arquivos da task não estiverem aí, pare e diga isso: não procure o repositório em outro lugar do disco, e nunca escreva fora desse diretório.\n\n---\n\n' "$WT_DIR"; cat "$PROMPT_FILE"; } > "$PROMPT_FILE.wt"
    mv "$PROMPT_FILE.wt" "$PROMPT_FILE"
fi

# --model forçado tem que existir na cascata da task, senão erro claro em vez de
# exit 2 mudo. Todo backend da policy é de custo marginal zero e entra em alguma
# cascata: não há mais backend fora-de-cascata que só `--model` alcança.
if [[ -n "$FORCE_MODEL" ]] && ! jq -e --arg b "$FORCE_MODEL" 'any(.[]; .backend == $b)' <<<"$CASCADE" >/dev/null; then
    die "backend '$FORCE_MODEL' não está na cascata da task '$TASK' (ver $POLICY — backend removido/desabilitado?)"
fi

# Cascata esgotada dizia só "cascata esgotada": 119 das 302 linhas do log, sem
# como saber qual degrau caiu nem por quê. TRILHA acumula <pool>=<rc> por degrau
# e vai inteira pro detail — um campo string, o schema do log não muda.
TRILHA=""
trilha_add() { TRILHA="${TRILHA:+$TRILHA }$1=$2"; }

run_cascade() {
    local entry backend model effort rc
    while IFS= read -r entry; do
        backend=$(jq -r '.backend' <<<"$entry")
        model=$(jq -r '.model // empty' <<<"$entry")
        effort=$(jq -r '.effort // empty' <<<"$entry")
        if [[ -n "$FORCE_MODEL" && "$backend" != "$FORCE_MODEL" ]]; then
            trilha_add "$(pool_key "$backend" "$model")" "outro_modelo"; continue
        fi
        local t0=$SECONDS
        if [[ -n "$WT_DIR" ]]; then
            ( cd "$WT_DIR" && invoke_backend "$backend" "$model" "$effort" ); rc=$?
        else
            invoke_backend "$backend" "$model" "$effort"; rc=$?
        fi
        DUR_S=$(( SECONDS - t0 ))
        [[ $rc -eq 0 ]] && { USED="$backend"; USED_POOL=$(pool_key "$backend" "$model"); USED_MODEL="$model"; return 0; }
        trilha_add "$(pool_key "$backend" "$model")" "rc$rc"
    done < <(jq -c '.[]' <<<"$CASCADE")
    return 1
}

USED="" USED_POOL="" USED_MODEL=""
if run_cascade; then
    echo "worker: $USED" >&2   # linha estável pra consumidores (peer-review) — não reformatar
    if [[ -n "$WT_DIR" ]]; then
        ( cd "$WT_DIR" && git add -A && git -c user.name=delegate -c user.email=delegate@local commit -qm "delegate($TASK): output de $USED" ) || true

        # diff vazio ≠ sucesso: worker pode devolver rc=0 sem ter feito nada (falha silenciosa).
        if [[ -z "$(git -C "$WT_DIR" status --porcelain)" ]] && \
           [[ -z "$(git -C "$WORKTREE" diff --name-only "$base_ref...$WT_BRANCH" 2>/dev/null)" ]]; then
            echo "⚠️  worker ($USED) produced no changes (suspected silent failure)" >&2
            echo "branch: $WT_BRANCH (base=$base_ref @ $WT_BASE_SHA)" >&2
            echo "--- resumo do worker ---" >&2
            cat "$TMP_OUT" >&2
            log_usage "$TASK" "$USED" "empty_diff" "${USED_MODEL:+model=$USED_MODEL }branch=$WT_BRANCH base=$base_ref" "$USED_POOL" 0 0 "${DUR_S:-0}"
            exit 5
        fi

        echo "worker: $USED"
        echo "branch: $WT_BRANCH"
        echo "base: $base_ref @ $WT_BASE_SHA"
        echo "worktree: $WT_DIR"
        echo "--- resumo do worker ---"
        cat "$TMP_OUT"
        echo "--- diff stat ---"
        git -C "$WORKTREE" diff --stat "$base_ref...$WT_BRANCH" 2>/dev/null || true
        echo "ℹ️  Revisar o diff, rodar verify e integrar manualmente; depois: git worktree remove '$WT_DIR' && git branch -d '$WT_BRANCH'" >&2
    else
        cat "$TMP_OUT"
    fi
    log_usage "$TASK" "$USED" "ok" "${USED_MODEL:+model=$USED_MODEL}${WT_BRANCH:+ branch=$WT_BRANCH}" "$USED_POOL" \
        "$(wc -c < "$PROMPT_FILE")" "$(wc -c < "$TMP_OUT")" "${DUR_S:-0}"
    exit 0
fi

# cascata esgotada — só remove worktree criada nesta chamada; --continue nunca apaga trabalho reaproveitado
[[ -n "$WT_DIR" && "$WT_FRESH" == "1" ]] && { git -C "$WORKTREE" worktree remove --force "$WT_DIR" 2>/dev/null; git -C "$WORKTREE" branch -D "$WT_BRANCH" 2>/dev/null; } >/dev/null
echo "⚠️  Nenhum worker disponível na cascata pra task '$TASK'. A sessão assume." >&2
log_usage "$TASK" "-" "unavailable" "cascata esgotada: ${TRILHA:-nenhum degrau elegível}"
exit 2
