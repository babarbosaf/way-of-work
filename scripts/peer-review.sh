#!/usr/bin/env bash
# peer-review.sh — Adversarial Evaluator: segunda opinião via reviewer LLM-agnóstico
#
# Uso:
#   peer-review.sh spec <path-to-spec.md> [--findings <path|->] [--model auto|codex|gemini]
#   peer-review.sh diff [git-ref] [--findings <path|->] [--spec <spec.md>] [--model ...]
#
#   Findings vão pro stdout (sem sidecar em disco). Registro durável = §5 da spec /
#   comentário da PR. Round 2: `--findings -` lê os findings anteriores do stdin.
#
# Cascata (--model auto, default):
#   codex → gemini → exit 2 (Claude assume via subagente adversarial / inline)
#
# Cada modelo tem cooldown próprio em ~/.claude/gate/cooldown.<model>. Cooldown de
# um não bloqueia o outro. Override de duração: PEER_COOLDOWN_MINS (default 60).
#
# Política:
#   - Pula XS/S sem input externo
#   - M/L (spec) = ≥100 linhas OU ≥5 headers `##`
#   - M/L (diff) = toca prod (agent/|apps/|bin/|libs/|migrations/|scripts/) OU input externo
#                  OU diff grande (≥500 LOC OU ≥20 arquivos)
#   - Fallback gracioso: todos reviewers indisponíveis → exit 2, Claude assume gate
#
# Logs: ~/.claude/gate/usage.log (JSONL, sem conteúdo de spec/diff — só metadados)

set -euo pipefail

GATE_DIR="$HOME/.claude/gate"
USAGE_LOG="$GATE_DIR/usage.log"
mkdir -p "$GATE_DIR"
touch "$USAGE_LOG"
chmod 600 "$USAGE_LOG"

die() { echo "ERRO: $*" >&2; exit 1; }
log_usage() {
    local type="$1" target="$2" decision="$3" reason="${4:-}" reviewer="${5:-}"
    local ts
    ts=$(date +"%Y-%m-%dT%H:%M:%S%z")
    local json
    json=$(jq -cn \
        --arg ts "$ts" \
        --arg type "$type" \
        --arg target "$target" \
        --arg decision "$decision" \
        --arg reason "$reason" \
        --arg reviewer "$reviewer" \
        '{ts: $ts, type: $type, target: $target, decision: $decision, reason: $reason, reviewer: $reviewer}')
    echo "$json" >> "$USAGE_LOG"
}

# Circuit-breaker per-model vive no delegate.sh (SPEC-2026-002 D-04) —
# a invocação de workers externos é toda dele; aqui fica só gating + prompts.

[[ $# -ge 1 ]] || die "uso: $0 <spec|diff> [alvo] [--findings <path|->] [--spec <path>] [--model auto|codex|gemini]"
MODE="$1"
shift

TARGET=""
PREV_FINDINGS=""
ACTIVE_SPEC=""
MODEL="auto"

# TARGET é o primeiro arg posicional restante
if [[ $# -gt 0 && "$1" != --* ]]; then
    TARGET="$1"; shift
fi

while [[ $# -gt 0 ]]; do
    case "$1" in
        --findings) PREV_FINDINGS="$2"; shift 2 ;;
        --spec)     ACTIVE_SPEC="$2";   shift 2 ;;
        --model)    MODEL="$2";          shift 2 ;;
        *)          shift ;;
    esac
done

# Validação de backend é do delegate/policy (autoridade única) — qualquer valor
# ≠ auto é repassado como --model e o delegate falha claro se não existir na cascata.

# Classifier
is_ml_spec() {
    local file="$1"
    [[ -f "$file" ]] || return 1
    local lines sections
    lines=$(wc -l < "$file")
    sections=$(grep -c "^## " "$file" || true)
    [[ "$lines" -ge 100 ]] || [[ "$sections" -ge 5 ]]
}
touches_prod_agent() {
    local ref="${1:-HEAD}"
    git diff "$ref" --name-only 2>/dev/null | grep -qE '^(agent/|apps/|bin/|libs/|migrations/|scripts/.*\.(py|sh)$|.*(handler|endpoint|webhook|cron).*)' || return 1
}
is_large_diff() {
    local ref="${1:-HEAD}"
    local loc files
    loc=$(git diff "$ref" --shortstat 2>/dev/null | grep -oE '[0-9]+ insertion' | grep -oE '[0-9]+' || echo 0)
    files=$(git diff "$ref" --name-only 2>/dev/null | wc -l | tr -d ' ')
    [[ "${loc:-0}" -ge 500 ]] || [[ "${files:-0}" -ge 20 ]]
}
has_external_input() {
    local ref_or_file="$1"
    if [[ -f "$ref_or_file" ]]; then
        grep -qE '^\s*(def\s+.*(handler|webhook|endpoint)|@app\.route|@router\.|app\.post|app\.get|slack.*event|requests\.(get|post)|urllib|httpx|aiohttp)' "$ref_or_file" 2>/dev/null
    else
        git diff "$ref_or_file" 2>/dev/null | grep -qE 'webhook|handler|endpoint|@app\.route|def.*_handler|slack.*event' -i
    fi
}

# Injeta primeiras 40 linhas do CLAUDE.md do projeto. Escapa backticks e $ pra não
# disparar substitution quando concatenado em heredoc unquoted.
inject_project_context() {
    local root
    root=$(git rev-parse --show-toplevel 2>/dev/null) || return 0
    local claude_md="$root/CLAUDE.md"
    [[ -f "$claude_md" ]] || return 0
    head -40 "$claude_md" | sed 's/`/\\`/g; s/\$/\\$/g'
}

inject_idea_context() {
    local spec_path="$1"
    [[ -f "$spec_path" ]] || return 0
    local root
    root=$(git rev-parse --show-toplevel 2>/dev/null) || return 0
    local idea_ref
    idea_ref=$(grep -m1 '^idea_ref:' "$spec_path" 2>/dev/null | sed 's/^idea_ref:[[:space:]]*//' | tr -d '"')
    local idea_file=""
    if [[ -n "$idea_ref" && -f "$root/$idea_ref" ]]; then
        idea_file="$root/$idea_ref"
    else
        local slug
        slug=$(basename "$spec_path" .md | sed 's/SPEC-[0-9-]*//;s/^[-_]*//')
        local candidate="$root/docs/prd/${slug}.md"
        [[ -f "$candidate" ]] && idea_file="$candidate"
    fi
    [[ -n "$idea_file" ]] || return 0
    printf 'PRD do sistema por trás desta spec (use para avaliar se os ACs resolvem o problema real):\n'
    head -60 "$idea_file" | sed 's/`/\\`/g; s/\$/\\$/g'
}

inject_prev_findings() {
    local findings_path="$1"
    [[ -n "$findings_path" ]] || return 0
    printf 'Findings do round anterior (confirme se foram resolvidos; não reabra issues já fechadas):\n'
    if [[ "$findings_path" == "-" ]]; then
        sed 's/`/\\`/g; s/\$/\\$/g'                 # round 2 via stdin: nada gravado em disco
    elif [[ -f "$findings_path" ]]; then
        sed 's/`/\\`/g; s/\$/\\$/g' < "$findings_path"
    fi
}

inject_spec_acs() {
    local spec_path="$1"
    [[ -n "$spec_path" && -f "$spec_path" ]] || return 0
    local acs
    acs=$(awk '/^## (Critérios de Aceite|Acceptance Criteria|AC)/,/^## [^C]/' "$spec_path" | head -60)
    [[ -n "$acs" ]] || return 0
    printf 'ACs da spec ativa (verifique se o diff os implementa):\n'
    printf '%s\n' "$acs" | sed 's/`/\\`/g; s/\$/\\$/g'
}

# Decide se invoca gate ou pula
should_skip=false
skip_reason=""
case "$MODE" in
    spec)
        [[ -n "$TARGET" ]] || die "uso: $0 spec <path-to-spec.md>"
        [[ -f "$TARGET" ]] || die "spec não encontrada: $TARGET"
        if ! is_ml_spec "$TARGET" && ! has_external_input "$TARGET"; then
            should_skip=true
            skip_reason="spec XS/S sem input externo"
        fi
        ;;
    diff)
        TARGET="${TARGET:-HEAD}"
        if ! touches_prod_agent "$TARGET" && ! has_external_input "$TARGET" && ! is_large_diff "$TARGET"; then
            should_skip=true
            skip_reason="diff sem prod-path, sem input externo, e pequeno (<500 LOC, <20 arquivos)"
        fi
        ;;
    *)
        die "modo inválido: $MODE (use spec ou diff)"
        ;;
esac

if $should_skip; then
    echo "Adversarial Evaluator pulado: $skip_reason"
    log_usage "$MODE" "$(basename "$TARGET")" "skipped" "$skip_reason" ""
    exit 0
fi

# Monta prompt focado
build_prompt_spec() {
    local ctx idea prev
    ctx=$(inject_project_context)
    idea=$(inject_idea_context "$TARGET")
    prev=$(inject_prev_findings "$PREV_FINDINGS")
    cat <<PROMPT
${ctx:+Contexto do projeto (use para calibrar severidade — padrões estabelecidos aqui não são issues):
$ctx

}${idea:+$idea

}${prev:+$prev

}Você é um revisor de specs. Analise a spec anexada buscando estes 5 antipatterns:

1. **Dual writer**: duas fontes escrevem o mesmo dado sem resolução de conflito
2. **Payload perdido em fluxo alternativo**: campo/dado não propagado em erro, timeout ou cancel
3. **Abstração inacessível**: conceito citado em AC/Plano que não existe concretamente na spec
4. **AC ambíguo de contagem**: "N itens criados" sem definir fonte de contagem ou o que conta
5. **Débito embutido**: escopo cria abstração que vai sobrar (infra "reutilizável" sem 2º consumidor real), API surface além do necessário, feature flag/migração sem critério de cleanup, ou acoplamento novo entre módulos antes separados

Verifique também consistência estrutural (AGNÓSTICO DE FORMATO — a spec pode usar
seções "Resumo/Mudanças/Plano" OU "§1 Contrato/§2 Design/§3 Slices". Cobre a
presença do CONTEÚDO, nunca nomes literais de seção; não trate ausência de um nome
específico como issue):
- O contrato existe: contexto do problema, critérios de aceite e fora de escopo.
- Critérios de aceite testáveis (SIM/NÃO comportamental OU Dado/Quando/Então) — cada um prova um comportamento observável, não "funciona corretamente".
- Toda função/tabela/abstração citada num critério ou slice existe concretamente na spec ou no design.
- Quando há prod ou input externo: design técnico presente (contratos externos, Security com modelo de ameaça ou "n/a", Rollback concreto).
- O escopo de mudança (Mudanças/Slices) bate com o que o contrato promete: nada prometido sem entregável, nada entregue fora do contrato.

**Definição de CRÍTICO**: impede funcionamento em prod, risco de perda de dado, falha de segurança real, OU compromisso de débito técnico irreversível (abstração prematura que vai bloquear refactor futuro).
Naming ambíguo, ausência de type hints, otimizações prematuras e melhorias de legibilidade NÃO são críticos — vão em SUGESTÕES ou são omitidos.
Para cada item CRÍTICO, responda: (1) o que quebra ou trava, (2) quando quebra ou trava, (3) impacto observável no usuário, dado ou velocidade de evolução do código. Se não conseguir preencher os 3, mova para MELHORIAS IMPORTANTES.

Saída em 3 baldes (máximo 3 itens cada):
- **ISSUES CRÍTICAS** — bloqueiam aprovação
- **MELHORIAS IMPORTANTES** — resolver antes do build
- **SUGESTÕES** — opcional

Se um balde estiver vazio, escreva "nenhum". Se a spec está sólida, uma linha basta: "Sem bloqueantes."
PROMPT
}

build_prompt_diff() {
    local ctx acs prev
    ctx=$(inject_project_context)
    acs=$(inject_spec_acs "$ACTIVE_SPEC")
    prev=$(inject_prev_findings "$PREV_FINDINGS")
    cat <<PROMPT
${ctx:+Contexto do projeto (use para calibrar severidade — padrões estabelecidos aqui não são issues):
$ctx

}${acs:+$acs

}${prev:+$prev

}Você é um revisor de código pré-ship. Analise o diff anexado focando em:

1. **Validação de input externo**: handlers HTTP/webhook/Slack validam tipo, tamanho e formato na boundary?
2. **Erros vazam internos?**: stack traces ou detalhes internos expostos ao usuário final?
3. **Logs expõem sensíveis?**: tokens, senhas, PII nos logs?
4. **Idempotência**: cron/handler/webhook pode executar 2x sem efeito colateral?
5. **Credenciais**: \`.env\` hardcoded? Token no código?
6. **Error handling amplo**: \`except Exception: pass\` sem tratamento específico?
7. **Race conditions**: estado compartilhado sem lock, dicts module-level com workers concorrentes?
8. **Débito iminente**: abstração prematura (regra de 3 violada — extraiu helper na 1ª ou 2ª duplicação)? duplicação nova que vai pedir DRY em 3 sprints? acoplamento novo entre módulos antes separados? \`TODO\`/\`FIXME\`/feature flag sem prazo ou critério de cleanup?

**Definição de BLOCKER**: impede funcionamento em prod, risco de perda de dado, falha de segurança real, OU compromisso de débito irreversível (abstração que vai travar refactor futuro, acoplamento que vai forçar reescrita).
Naming, style e otimizações prematuras NÃO são blockers — vão em SUGESTÕES ou são omitidos.
Para cada BLOCKER, responda: (1) o que quebra ou trava, (2) quando quebra ou trava, (3) impacto observável. Se não conseguir os 3, mova para IMPORTANTE.

Saída em 3 baldes (máximo 3 itens cada):
- **BLOCKERS** — não dá ship
- **IMPORTANTE** — resolver antes do ship
- **SUGESTÕES** — opcional

Se um balde estiver vazio, escreva "nenhum". Cite linhas. Se o diff está seguro, uma linha basta: "Sem bloqueantes."
PROMPT
}

# Monta payload completo num temp file (reusado pelos reviewers da cascata)
PROMPT_FILE=$(mktemp)
TMP_OUT=$(mktemp)
trap 'rm -f "$PROMPT_FILE" "$TMP_OUT"' EXIT

if [[ "$MODE" == "spec" ]]; then
    {
        build_prompt_spec
        printf '\n\n---\nSPEC:\n\n'
        cat "$TARGET"
    } > "$PROMPT_FILE"
else
    diff_content=$(git diff "$TARGET" -- 2>/dev/null)
    line_count=$(wc -l <<< "$diff_content")
    if [[ $line_count -gt 2000 ]]; then
        echo "⚠️  Diff truncado: $line_count linhas → 2000 enviadas ao reviewer" >&2
        diff_content=$(head -2000 <<< "$diff_content")
    fi
    {
        build_prompt_diff
        printf '\n\n---\nDIFF:\n\n'
        printf '%s' "$diff_content"
    } > "$PROMPT_FILE"
fi

# Dispatch via delegate.sh (SPEC-2026-002 D-04). Mapeamento de exit codes:
# delegate 0 → 0 (findings no stdout); delegate 1/2 (cascata esgotada, erro) → 2
# (fallback adversarial). Códigos internos da cascata (cooldown, CLI ausente)
# nunca chegam aqui — o delegate os resolve tentando o próximo backend.
DELEGATE="$HOME/.claude/scripts/delegate.sh"
DG_ERR=$(mktemp)
trap 'rm -f "$PROMPT_FILE" "$TMP_OUT" "$DG_ERR"' EXIT

delegate_args=(--task review --timeout 120)
[[ "$MODEL" != "auto" ]] && delegate_args+=(--model "$MODEL")

USED_REVIEWER=""
bash "$DELEGATE" "${delegate_args[@]}" - < "$PROMPT_FILE" > "$TMP_OUT" 2>"$DG_ERR"
dg_rc=$?
cat "$DG_ERR" >&2
if [[ $dg_rc -eq 0 ]]; then
    # linha estável 'worker: <backend>' emitida pelo delegate no sucesso
    USED_REVIEWER=$(sed -n 's/^worker: //p' "$DG_ERR" | tail -1)
    USED_REVIEWER="${USED_REVIEWER:-delegate}"
fi

if [[ -z "$USED_REVIEWER" ]]; then
    echo "⚠️  Nenhum reviewer disponível na cascata do delegate (ver config/model-policy.json, task 'review'). Claude assume gate via subagente adversarial (ver ~/.claude/docs/adversarial-evaluator.md § Fallback)." >&2
    log_usage "$MODE" "$(basename "$TARGET")" "unavailable" "all reviewers failed/in cooldown" ""
    exit 2
fi

cat "$TMP_OUT"
log_usage "$MODE" "$(basename "$TARGET")" "ok" "" "$USED_REVIEWER"

# Sem sidecar. Os findings já foram pro stdout (cat acima). O registro durável é a
# §5 da spec (modo spec) ou o comentário da PR (modo diff); nada é gravado em disco.
# Round 2 reusa os findings anteriores via stdin (`--findings -`).
echo "ℹ️  Findings em stdout. Resuma na §5 da spec (ou no comentário da PR); round 2 reusa via '--findings -' (stdin)." >&2
exit 0
