#!/usr/bin/env bash
# delegate.sh — dispatcher multi-modelo
#
#   delegate.sh --task <review|implement|scan|boilerplate|pesquisa>
#   delegate.sh --task implement --tier <padrao|amplo>   # tier troca o ponto de entrada
#               [--model <backend>] [--worktree <repo-dir>] [--continue <slug>]
#               [--timeout N] [--gc <repo-dir>] [--async] -
#   delegate.sh --status <id>     # estado e material de um despacho assíncrono
#   delegate.sh --tasks           # as tasks em curso, uma por linha (só leitura)
#   delegate.sh --tasks --oneline # os baldes em curso numa linha, nada se ocioso
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
# Onde a worktree nasce: DELEGATE_WT_ROOT (default ~/.delegate-wt, FORA do repo).

set -uo pipefail

GATE_DIR="${DELEGATE_GATE_DIR:-$HOME/.claude/gate}"
POLICY="${DELEGATE_POLICY:-$HOME/.claude/config/model-policy.json}"
# O repositório expõe delegate.sh também por um link em scripts/, então o link se
# resolve na origem: presumir UMA topologia de link fazia a falha aparecer como
# "arquivo não encontrado" no meio da cascata, e um segundo ponto de exposição
# pediria mais um fallback.
LIMITES_DIR="$(cd "$(dirname "$(python3 -c 'import os,sys; print(os.path.realpath(sys.argv[1]))' "${BASH_SOURCE[0]}")")" && pwd)"
source "$LIMITES_DIR/lib-limites.sh"
source "$LIMITES_DIR/lib-orcamento.sh"
source "$LIMITES_DIR/lib-slot.sh"
# Override project-specific (finding_routing) vive em
# <base>.local.json (gitignored). Merge base * local (deep; arrays do local vencem).
# Espelho consciente de model-policy-effective.sh — manter em sincronia.
# Roda depois das flags de leitura, e não aqui: a fusão cria um temporário por
# chamada, e a camada de terminal lê a cada 2s. Medido, era um arquivo novo em
# $TMPDIR por leitura, pra responder pergunta que não olha policy.
policy_efetiva() {
    local local_policy="${POLICY%.json}.local.json"
    [[ -f "$local_policy" ]] || return 0
    jq -e . "$POLICY" >/dev/null 2>&1 && jq -e . "$local_policy" >/dev/null 2>&1 || return 0
    _EFF=$(mktemp); jq -s '.[0] * .[1]' "$POLICY" "$local_policy" > "$_EFF" && POLICY="$_EFF"
}
INBOX="${DELEGATE_INBOX:-$HOME/.claude/INBOX.md}"
# A árvore de trabalho nasce FORA do repositório. Medido em 21/set/2026: o
# worker do plano principal recusa escrita dentro do diretório de configuração
# dele, e quando o repositório clonado É esse diretório, árvore interna deixa
# aquele degrau sem como rodar. A recusa nem pede confirmação, porque a sessão
# do worker não tem terminal. Contraprova no mesmo par de chamadas: o mesmo
# modelo escreveu sem reclamar em diretório fora do repo.
WT_ROOT="${DELEGATE_WT_ROOT:-$HOME/.delegate-wt}"
# Nome do repo dentro da raiz, sem o ponto inicial: repositório oculto viraria
# subdiretório oculto, e caminho que ainda contém o nome do diretório de
# configuração do worker é exatamente o que dispara a recusa que esta mudança
# existe pra evitar.
wt_nome_repo() { local n; n=$(basename "$(cd "$1" && pwd)"); echo "${n#.}"; }
LOG="$GATE_DIR/delegate.log"
TMP_OUT=""; MATERIAL=""; _EFF=""
# `slot_configurar` só aponta o diretório, e quem cria é quem escreve: consultar
# o estado do gate não pode deixar rastro, e criar diretório é rastro.
slot_configurar "$GATE_DIR"
gate_para_escrita() { mkdir -p "$GATE_DIR"; touch "$LOG"; chmod 600 "$LOG"; }

die() { echo "delegate: $*" >&2; exit 1; }
# Guarda de flag que consome valor: sob `set -u`, referenciar "$2" sem ele
# existir estoura unbound variable antes de qualquer die. $1=flag $2=$# do loop.
need_arg() { (( $2 >= 2 )) || die "$1: falta valor"; }

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
    # `material` é o campo que liga a chamada ao que o worker produziu. Vai em
    # TODA chamada, e não só quando falha: transcript existe e não rotaciona,
    # e medido em 21/set/2026 eram mais de mil arquivos de nome opaco desde
    # fevereiro, sem nada que ligasse uma task ao material dela. Gravado aqui, a
    # ligação sobrevive ao terminal fechar, que é o que "imprimir na falha" não
    # dá. CAMINHO, nunca conteúdo: o prompt pode carregar o repo inteiro, e
    # despejar isso no log é vazamento, não diagnóstico.
    jq -cn --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" --arg task "$1" --arg backend "$2" \
        --arg status "$3" --arg detail "${4:-}" --arg pool "${5:-}" \
        --arg material "${MATERIAL:-$TMP_OUT}" \
        --argjson bytes_in "${bin:-0}" --argjson bytes_out "${bout:-0}" \
        --argjson dur_s "${dur:-0}" \
        '{ts:$ts,task:$task,backend:$backend,status:$status,detail:$detail,pool:$pool,material:$material,bytes_in:$bytes_in,bytes_out:$bytes_out,dur_s:$dur_s}' >> "$LOG"
}

# Chamada que alcançou o worker e voltou em falha gastou cota igual à que fechou.
# Até aqui só o caminho de sucesso deixava linha, e como o gate de saldo e o
# apurador leem esse mesmo log, os dois subcontavam: numa janela ruim passava mais
# chamada do que a régua permite. Só entra aqui o que chegou ao worker — pulo por
# castigo, por saldo, por slot ocupado ou por backend ausente não gastou nada e
# continua fora, que é o que mantém `unavailable` significando cascata esgotada.
log_falha_gasta() { # backend status detail pool dur_s
    log_usage "$TASK" "$1" "$2" "$3" "$4" \
        "$(wc -c < "$PROMPT_FILE")" "$(wc -c < "$TMP_OUT")" "$5"
}

# --- pool: só rótulo pro log de auditoria; prioridade real vem da ordem da cascata na policy ---
pool_key() { # backend model → chave de bolsão ("backend" ou "backend:pool")
    local p=""
    [[ -n "${2:-}" ]] && p=$(jq -r --arg b "$1" --arg m "$2" \
        '.backends[$b].pools // {} | to_entries[] | select(.value | index($m)) | .key' "$POLICY" 2>/dev/null | head -1)
    echo "$1${p:+:$p}"
}

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
is_sem_resposta() { [[ "$(classificar_limite "$1")" == silent_fail ]]; }

# --- args ---
TASK="" TIER="" FORCE_MODEL="" WORKTREE="" TIMEOUT="" GC="" BASE_REF="" CONTINUE_SLUG=""
ASYNC=0; STATUS_ID=""; TASKS=0; ONELINE=0; VISIVEL=""
QUESTION="" REFERENCE="" PATHS=() EXPECT_LINES="" EXPECT_REGEX=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --task) need_arg --task $#; TASK="$2"; shift 2 ;;
        --tier) need_arg --tier $#; TIER="$2"; shift 2 ;;
        --question) need_arg --question $#; QUESTION="$2"; shift 2 ;;
        --reference) need_arg --reference $#; REFERENCE="$2"; shift 2 ;;
        --expect-lines) need_arg --expect-lines $#; EXPECT_LINES="$2"; shift 2 ;;
        --expect-regex) need_arg --expect-regex $#; EXPECT_REGEX="$2"; shift 2 ;;
        # variádico: consome até a próxima flag (ou o '-' do modo heredoc)
        --paths) shift; while [[ $# -gt 0 && "$1" != -* ]]; do PATHS+=("$1"); shift; done ;;
        --model) need_arg --model $#; FORCE_MODEL="$2"; shift 2 ;;
        --worktree) need_arg --worktree $#; WORKTREE="$2"; shift 2 ;;
        --async) ASYNC=1; shift ;;
        --status) need_arg --status $#; STATUS_ID="$2"; shift 2 ;;
        --visivel) need_arg --visivel $#; VISIVEL="$2"; shift 2 ;;
        --tasks) TASKS=1; shift ;;
        --oneline) ONELINE=1; shift ;;
        --continue) need_arg --continue $#; CONTINUE_SLUG="$2"; shift 2 ;;
        --timeout) need_arg --timeout $#; TIMEOUT="$2"; shift 2 ;;
        --gc) need_arg --gc $#; GC="$2"; shift 2 ;;
        --base) need_arg --base $#; BASE_REF="$2"; shift 2 ;;
        -) shift ;;
        *) die "arg desconhecido: $1" ;;
    esac
done

# Modificador de leitura pedido sem a leitura despacharia calado, e quem pediu
# formato de barra ficaria olhando uma barra vazia achando que não há task.
[[ "$ONELINE" == 1 && "$TASKS" != 1 ]] && die "--oneline: só vale junto com --tasks"

if [[ "$TASKS" == 1 ]]; then
    # A camada de terminal (ADR-0002) roda isto em laço num pane: o gate é a fonte,
    # a leitura não escreve nada, e não existe aqui caminho que toque policy. É o
    # que faz desligar a camada mudar a tela e não o roteamento.
    # Quem está em curso é o que a biblioteca de slot diz, e não a lista de
    # diretórios em `tasks/`: task que terminou deixa o diretório pra trás de
    # propósito, e listar ele mostraria trabalho que ninguém está fazendo.
    # Uma abertura por task: dois `sed` no mesmo arquivo podiam cair em lados
    # diferentes de uma reescrita e imprimir tipo de uma versão com branch de
    # outra.
    # Ocioso e quebrado precisam de telas diferentes. A barra some quando não há
    # nada em curso e sumia igual quando a leitura quebrou, e foi assim que um
    # caminho de config errado deixou a camada morta por um dia inteiro sem
    # ninguém notar. Gate que não dá pra ler não é "nada em curso": é não saber.
    if [[ ! -d "$GATE_DIR" || ! -r "$GATE_DIR" || ! -x "$GATE_DIR" ]]; then
        if [[ "$ONELINE" == 1 ]]; then echo "dlg: ?"
        else echo "estado ilegível em $GATE_DIR"; fi
        exit 0
    fi
    if [[ "$ONELINE" == 1 ]]; then
        # A barra de status limpa a entrada quando o output vem vazio, então
        # ocioso aqui é silêncio, e não frase: "nenhuma task em curso" deixaria a
        # entrada acesa sem informação nenhuma. A ordem sai do glob de slot, que
        # é estável, e por isso a linha não embaralha entre duas leituras iguais.
        _baldes=""
        while read -r _pool _id; do
            [[ -n "$_id" && -f "$GATE_DIR/tasks/$_id/meta" ]] || continue
            _baldes="${_baldes:+$_baldes }$_pool"
        done < <(slot_em_curso)
        if [[ -n "$_baldes" ]]; then echo "dlg: $_baldes"; fi
        exit 0
    fi
    _n=0
    while read -r _pool _id; do
        [[ -n "$_id" && -f "$GATE_DIR/tasks/$_id/meta" ]] || continue
        awk -v id="$_id" -v pool="$_pool" -F= \
            '$1=="task"{t=$2} $1=="branch"{b=$2} END{printf "%-22s %-12s %-12s %s\n", id, pool, t, b}' \
            "$GATE_DIR/tasks/$_id/meta"
        _n=$(( _n + 1 ))
    done < <(slot_em_curso)
    (( _n )) || echo "nenhuma task em curso"
    exit 0
fi
if [[ -n "$STATUS_ID" ]]; then
    # Identificador é nome de diretório, então travessia de caminho é recusada
    # antes de qualquer leitura: consulta é a porta mais fácil de empurrar.
    case "$STATUS_ID" in
        */*|..*|"") die "--status: identificador inválido: $STATUS_ID" ;;
    esac
    _meta="$GATE_DIR/tasks/$STATUS_ID/meta"
    [[ -f "$_meta" ]] || die "--status: identificador não existe: $STATUS_ID"
    echo "id: $STATUS_ID"
    # Um sed só, na ordem em que o arquivo grava, e campo vazio não vira linha.
    sed -nE 's/^(estado|task|balde|branch|rc|comecou|terminou)=(..*)/\1: \2/p' "$_meta"
    # Caminho, nunca conteúdo: o material pode carregar o repo inteiro, e despejar
    # isso no terminal é vazamento, não diagnóstico.
    [[ -f "$GATE_DIR/tasks/$STATUS_ID/out.txt" ]] && echo "material: $GATE_DIR/tasks/$STATUS_ID/out.txt"
    [[ -f "$GATE_DIR/tasks/$STATUS_ID/report.txt" ]] && echo "report: $GATE_DIR/tasks/$STATUS_ID/report.txt"
    exit 0
fi
if [[ -n "$GC" ]]; then
    find "$GATE_DIR/tasks" -mindepth 1 -maxdepth 1 -type d -mtime +7 -exec rm -rf {} + 2>/dev/null
    rm -f "$GATE_DIR"/resgate.*
    # Ocupado é o que a biblioteca de slot diz que está ocupado; o resto é órfão e
    # sai. Refazer a varredura aqui espalhava o formato do arquivo de slot por dois
    # arquivos, e o `--gc` não passava pelo teste que cobre órfão.
    _ocupados=$(slot_em_curso | awk '{print $1}')
    for _s in "$GATE_DIR"/slot.*; do
        [[ -f "$_s" ]] || continue
        grep -qxF "$(sed -n 's/^balde=//p' "$_s")" <<<"$_ocupados" || rm -f "$_s"
    done
    # A aba de sessão dirigida morre aqui, no mesmo lugar em que a worktree do
    # worker morre: a varredura por prazo precisava de quem a chamasse, e este é
    # o único gancho que já roda depois da integração. A guarda é ter REGISTRO de
    # sessão, não ter a ferramenta instalada: máquina que nunca pediu o modo
    # visível não tem registro nenhum, não chega a tocar o adaptador, e o caminho
    # padrão segue byte a byte o de antes.
    if compgen -G "$GATE_DIR/sessoes/*.json" >/dev/null 2>&1; then
        _fechador="${DELEGATE_FECHADOR:-$LIMITES_DIR/../../../scripts/fecha-sessao.sh}"
        if [[ -x "$_fechador" ]]; then
            # A policy FUNDIDA, nunca a base: o prazo pode morar no override
            # local, e ler a base aqui faria os dois lados divergirem calados.
            policy_efetiva
            DELEGATE_POLICY="$POLICY" "$_fechador" --ociosas \
                || echo "delegate: a varredura de sessões ociosas não completou" >&2
            rm -f ${_EFF:+"$_EFF"}
        fi
    fi
    git -C "$GC" worktree prune
    git -C "$GC" worktree list | grep 'delegate/' || echo "nenhuma worktree delegate/ ativa"
    exit 0
fi

# Daqui pra baixo o script escreve: gate, log e policy fundida nascem agora, e
# não no topo, pra que `--tasks` e `--status` sejam leitura de verdade.
gate_para_escrita
policy_efetiva

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
  "tasks": {"_any": [{"backend": "codex"}, {"backend": "agy"}]},
  "cooldowns": {"rate_limit_mins": 1, "tier_fallback_mins": 60, "transient_mins": 10, "silent_fail_mins": 60},
  "budgets": {"window_mins": 300, "pools": {}}
}
JSON
fi
limites_configurar "$POLICY" "$GATE_DIR" || die "policy sem cooldowns válidos"
orcamento_configurar "$POLICY" "$LOG" || die "policy sem budgets válidos"
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

# --- modo visível: a task vira uma aba nomeada, em vez de um worker invisível ---
# Desvio pedido explicitamente. Sem `--visivel` nada aqui roda, e é isso que
# mantém o despacho de hoje idêntico ao de ontem. Não reordena a cascata: lê a
# mesma fila, na mesma ordem, e fica com o primeiro que a medição aprovou pro
# modo interativo.
if [[ -n "$VISIVEL" ]]; then
    # shellcheck disable=SC1091
    source "$LIMITES_DIR/lib-visivel.sh" || die "--visivel: lib-visivel.sh não carregou"
    visivel_configurar "$POLICY" || die "--visivel: policy ilegível"
    escolhido="" modelo="" esforco=""
    while IFS=$'\t' read -r b m e; do
        [[ -n "$b" ]] || continue
        if visivel_elegivel "$b"; then escolhido="$b"; modelo="$m"; esforco="$e"; break; fi
    done < <(jq -r '.[] | [.backend, (.model // ""), (.effort // "")] | @tsv' <<<"$CASCADE")
    # Cair no modo de lote aqui entregaria trabalho feito onde ninguém pediu, e
    # quem pediu pra ver ficaria olhando uma aba que nunca abre.
    [[ -n "$escolhido" ]] || die "--visivel: nenhum backend da fila de '$TASK' é elegível no modo interativo; a policy guarda o motivo medido de cada um"
    ABRIDOR="${DELEGATE_ABRIDOR:-$LIMITES_DIR/../../../scripts/abre-sessao.sh}"
    [[ -x "$ABRIDOR" ]] || die "--visivel: abridor não encontrado em $ABRIDOR"
    args=(--nome "$VISIVEL" --backend "$escolhido")
    [[ -n "$modelo"   ]] && args+=(--model "$modelo")
    [[ -n "$esforco"  ]] && args+=(--effort "$esforco")
    [[ -n "$WORKTREE" ]] && args+=(--cwd "$WORKTREE")
    # A policy que decidiu vai junto. Sem isso o abridor relê a policy BASE, e
    # quando o veredito mora no override local os dois lados divergem calados:
    # um escolhe o backend, o outro recusa ou sobe outro comando.
    export DELEGATE_POLICY="$POLICY"
    # O dono é quem PEDIU o despacho, e sem `exec` o pai do abridor passa a ser
    # este processo, que morre em seguida: toda sessão nasceria órfã.
    export DELEGATE_DONO_PID="${DELEGATE_DONO_PID:-$PPID}"
    "$ABRIDOR" "${args[@]}"; _rc=$?
    # Sem `exec`, a limpeza volta a acontecer: o temporário da fusão ficava em
    # $TMPDIR pra sempre a cada despacho visível.
    rm -f ${_EFF:+"$_EFF"}
    exit $_rc
fi


# --- timeout wrapper ---
if command -v gtimeout >/dev/null 2>&1; then TIMEOUT_CMD="gtimeout $TIMEOUT"
elif command -v timeout >/dev/null 2>&1; then TIMEOUT_CMD="timeout $TIMEOUT"
else TIMEOUT_CMD=""; fi

# Identidade da task e casa durável do material dela. O output capturado deixa de
# ser mktemp: despachar sem esperar e jogar o material num arquivo que morre no
# fim do processo é perder o trabalho, e é esse caminho que a consulta por
# identificador vai ler depois. O prompt segue transitório de propósito, porque
# ele carrega conteúdo do repo e guardar isso não serve a diagnóstico nenhum.
# `mktemp -d` em vez de epoch mais RANDOM: dois despachos no mesmo segundo
# colidiam calados, e o `mkdir -p` não reclamava, então o segundo sobrescrevia o
# meta do primeiro. Quem garante a unicidade é o sistema de arquivos.
mkdir -p "$GATE_DIR/tasks"
TASK_DIR=$(mktemp -d "$GATE_DIR/tasks/$TASK-XXXXXX") || die "não consegui criar o diretório da task"
TASK_ID=$(basename "$TASK_DIR")
mkdir -p "$TASK_DIR"; chmod 700 "$TASK_DIR"
PROMPT_FILE=$(mktemp); TMP_OUT="$TASK_DIR/out.txt"; : > "$TMP_OUT"; chmod 600 "$TMP_OUT"
SLOT_TOMADO=""; HOUVE_PRAZO=0
trap 'rm -f "$PROMPT_FILE" ${_EFF:+"$_EFF"}; [[ -n "$SLOT_TOMADO" ]] && slot_soltar "$SLOT_TOMADO"' EXIT
# O estado terminal reescreve o arquivo, então o que veio antes e continua
# valendo tem que ser recomposto aqui: `comecou` era perdido, e o leitor procurava
# um campo que a escrita terminal nunca produzia. O `id` saiu porque é o nome do
# diretório, e o leitor já o tem na mão.
# O `branch` entra porque a camada de terminal o mostra, e derivar
# `delegate/<id>` na leitura mentiria pra despacho sem árvore de trabalho, que não
# tem branch nenhuma.
# Publica por rename: truncar e depois escrever deixava uma janela em que o
# leitor abria o arquivo no meio e imprimia campo vazio, ou misturava a versão
# velha com a nova. `mv` no mesmo diretório é atômico, então quem lê vê a versão
# inteira de antes ou a inteira de depois, e nunca metade.
task_estado() { # estado [rc]
    local novo="$TASK_DIR/meta.novo"
    {
        printf 'estado=%s\ntask=%s\nbalde=%s\nbranch=%s\nrc=%s\ncomecou=%s\n' \
            "$1" "$TASK" "${USED_POOL:-}" "${WT_BRANCH:-}" "${2:-}" "$COMECOU"
        [[ "$1" == "em curso" ]] || printf 'terminou=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    } > "$novo"
    mv "$novo" "$TASK_DIR/meta"
}
COMECOU=$(date -u +%Y-%m-%dT%H:%M:%SZ)
task_estado "em curso"
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
# Pesquisa não toca arquivo nem roda verify, e o contrato de implementação faz o
# worker inventar um comando pra ter o que colar: o primeiro despacho real saiu
# tentando `curl` num sandbox sem DNS, em vez de usar a busca que a fila liga.
# O que se cobra de uma pesquisa é fonte.
if [[ "$TASK" == "pesquisa" && -z "$WORKTREE" ]]; then
    REPORT_FOOTER=$'\n\n---\nContrato de report obrigatório ao final da resposta:\n1. Responda a pergunta, direto.\n2. Cite a URL de cada fonte que sustenta a resposta.\n3. Declare o que não deu pra confirmar, e por quê.\nResposta sem fonte citada é considerada incompleta.'
    printf '%s' "$REPORT_FOOTER" >> "$PROMPT_FILE"
elif [[ "$BULK" != "1" || -n "$WORKTREE" ]]; then
    REPORT_FOOTER=$'\n\n---\nContrato de report obrigatório ao final da resposta:\n1. Rode a verificação declarada na task e cole o output (comando + resultado).\n2. Liste os arquivos tocados (paths absolutos).\n3. Declare explicitamente o que NÃO foi feito (escopo cortado, TODO deixado, etc).\nResposta sem essas 3 seções é considerada incompleta.'
    printf '%s' "$REPORT_FOOTER" >> "$PROMPT_FILE"
fi

backend_field() { # backend field → valor da policy (ou vazio)
    jq -r --arg b "$1" --arg f "$2" '.backends[$b][$f] // empty' "$POLICY"
}
backend_enabled() {
    [[ "$(jq -r --arg b "$1" '.backends[$b].enabled // false' "$POLICY")" == "true" ]]
}

# O transcript do worker vence o output capturado quando existe: o output traz o
# que o worker imprimiu, o transcript traz como ele chegou lá. Eles não rotacionam,
# mas são mais de mil arquivos de nome opaco, e a chave que distingue um é o
# diretório de trabalho, que o despachante conhece porque foi ele que criou.
# O `-newer` sobre o arquivo de prompt, montado antes da chamada, descarta sessão
# de chamada anterior sem aritmética de data: o nome do arquivo do worker de código
# vem em hora local e o log em UTC, e reconciliar isso à mão erraria de uma hora.
transcript_de() { # backend cwd marco → caminho do transcript, ou nada
    local caminho padrao alvo f plano
    # A guarda barata vem ANTES do jq, e os dois campos saem de uma leitura só:
    # backend sem `sessions` declarado (o agy é um) pagava dois forks de jq por
    # degrau pra descobrir que não tinha nada a procurar.
    [[ -n "${2:-}" && -f "${3:-}" ]] || return 0
    IFS=$'\t' read -r caminho padrao < <(
        jq -r --arg b "$1" '[.backends[$b].sessions.path // "", .backends[$b].sessions.grep // ""] | @tsv' "$POLICY")
    [[ -n "$caminho" ]] || return 0
    caminho="${caminho//\$CLAUDE_CONFIG_DIR/${CLAUDE_CONFIG_DIR:-$HOME/.claude}}"
    caminho="${caminho/#\~/$HOME}"
    # Os dois workers medidos guardam a sessão de formas diferentes, e um `case`
    # por formato punha o esquema de nomes de cada provider dentro do script. A
    # policy declara onde procurar, com `{cwd}` e `{cwd_flat}` no caminho, e um
    # `grep` opcional pra quem grava o diretório de trabalho DENTRO do arquivo em
    # vez de no nome dele. Backend novo passa a ser linha de policy, não branch.
    # Achatar sem subshell, e só quando o token existe: `tr` num subshell custava
    # 2,6ms contra 0,03ms da substituição do próprio shell, medido.
    if [[ "$caminho" == *'{cwd_flat}'* ]]; then
        plano="${2//\//-}"; plano="${plano//./-}"
        caminho="${caminho//\{cwd_flat\}/$plano}"
    fi
    caminho="${caminho//\{cwd\}/$2}"
    padrao="${padrao//\{cwd\}/$2}"
    local -a achados=()
    while IFS= read -r f; do
        [[ -z "$padrao" ]] || grep -qF "$padrao" "$f" || continue
        achados+=("$f")
    done < <(find "$caminho" -name '*.jsonl' -newer "$3" 2>/dev/null)
    (( ${#achados[@]} )) || return 0
    # Uma chamada pode render mais de um arquivo: a continuação aponta pro pai por
    # `parent_thread_id`. O de escrita mais recente é o que tem o fim da história,
    # e medido no par real de 21/set/2026 o mais recente é o pai.
    alvo=$(ls -t "${achados[@]}" 2>/dev/null | head -1)
    [[ -n "$alvo" && -f "$alvo" ]] && printf '%s\n' "$alvo"
    return 0
}

# O worker devolve o prompt junto: o codex ecoa a entrada inteira no stdout. E a
# frase que classifica limite pode estar no prompt, não na resposta. Medido em
# 21/set/2026: revisar o diff deste despachante mandou pro worker a linha do
# próprio detector de desculpa, o detector casou com ela no eco e jogou fora uma
# revisão completa, de brinde castigando o balde por 60min. A população da
# classificação é só o que o worker acrescentou, e a subtração é por linha
# literal, porque não depende de conhecer o formato de eco de cada CLI.
resposta_pura() { # → caminho de um arquivo com as linhas que o worker acrescentou
    local pura="$TASK_DIR/resposta.txt"
    [[ -s "$PROMPT_FILE" && -f "$TMP_OUT" ]] || { printf '%s\n' "$TMP_OUT"; return 0; }
    grep -vxF -f "$PROMPT_FILE" "$TMP_OUT" > "$pura" 2>/dev/null || true
    printf '%s\n' "$pura"
}

invoke_backend() { # backend model → rc semântico (0 ok, 3 cooldown/ratelimit, 4 ausente, 1 falha)
    local backend="$1" model="$2" effort="${3:-}" rem cmd model_flag effort_config
    # cooldown por pool (backend:pool), não por backend inteiro — agy tem pools
    # independentes (gemini vs claude_gpt); um pool ruim não deve derrubar o outro.
    local pkey; pkey=$(pool_key "$backend" "$model")
    if rem=$(cooldown_remaining "$pkey"); then
        echo "▶ $pkey em cooldown (~$(( (rem+59)/60 ))min)" >&2; return 3
    fi
    # Saldo antes de gastar. Pular por saldo é o mesmo movimento de pular por
    # castigo, e é por isso que devolve o mesmo rc: a cascata desce, e cascata
    # inteira sem saldo esgota igual a cascata inteira em castigo, entregando o
    # trabalho pra sessão em vez de virar erro.
    if ! SALDO_NA_ESCOLHA=$(orcamento_restante "$pkey"); then
        echo "▶ $pkey sem saldo na janela de ${ORCAMENTO_WINDOW_MINS}min, pulando sem gastar chamada" >&2
        return 3
    fi
    # Um worker por balde. Vale no despacho serial também, porque duas sessões
    # despachando ao mesmo tempo colidem do mesmo jeito que duas tasks de uma só.
    if ! slot_tomar "$pkey" "$TASK_ID" "$TIMEOUT"; then
        echo "▶ $pkey ocupado por outro worker, pulando sem gastar chamada" >&2
        return 3
    fi
    SLOT_TOMADO="$pkey"
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
    # Config declarada NA ENTRADA da cascata, pelo mesmo canal do effort. É o que
    # deixa a fila de pesquisa ligar web no codex sem ligar web em review e scan:
    # no invoke global, todo worker sairia navegando sem ninguém ter pedido.
    while IFS=$'\t' read -r ck cv; do
        [[ -n "$ck" ]] && extra+=(-c "$ck=$cv")
    done < <(jq -r 'to_entries[] | [.key, (.value|tostring)] | @tsv' <<<"$ENTRY_CONFIG")
    # claude pede esforço por flag; codex por -c chave=valor. Backend sem os dois ignora.
    [[ -n "$effort" && -n "$effort_flag" ]] && extra+=("$effort_flag" "$effort")

    local rc t0=$SECONDS
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

    # Prazo estourado é tropeço de provider, e a sonda já tratava assim. Enquanto
    # o despachante não armava nada aqui, o mesmo rc=124 castigava num invocador
    # e passava batido no outro: dois comportamentos pro mesmo sinal.
    local resposta; resposta=$(resposta_pura)
    local dur=$(( SECONDS - t0 ))

    if [[ $rc -eq 124 ]]; then
        HOUVE_PRAZO=1
        armar_limite "$pkey" "$resposta" "$rc" >/dev/null
        log_falha_gasta "$backend" "timeout" "rc=124 limite=${TIMEOUT}s" "$pkey" "$dur"
        echo "⚠️  $backend timeout (${TIMEOUT}s), cooldown de tropeço armado pela policy" >&2
        return 3
    fi
    if [[ $rc -ne 0 ]]; then
        local limite; limite=$(classificar_limite "$resposta")
        if [[ "$limite" != desconhecido ]]; then
            armar_limite "$pkey" "$resposta" >/dev/null
            log_falha_gasta "$backend" "limited" "classe=$limite rc=$rc" "$pkey" "$dur"
            echo "⚠️  $pkey em limite $limite, cooldown armado pela policy" >&2
            return 3
        fi
        log_falha_gasta "$backend" "error" "rc=$rc" "$pkey" "$dur"
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
    if [[ -z "$WORKTREE" ]] && ! grep -qE '[^[:space:]]' "$resposta"; then
        limites_armar_classe "$pkey" silent_fail
        log_falha_gasta "$backend" "empty_out" "rc=0 sem resposta" "$pkey" "$dur"
        echo "⚠️  $pkey devolveu vazio (rc=0, falha silenciosa), cooldown armado pela policy" >&2
        return 3
    fi

    if [[ -z "$WORKTREE" ]] && is_sem_resposta "$resposta"; then
        limites_armar_classe "$pkey" silent_fail
        log_falha_gasta "$backend" "no_answer" "rc=0 desculpa em vez de resposta" "$pkey" "$dur"
        echo "⚠️  $pkey devolveu desculpa em vez de resposta (rc=0), cooldown armado pela policy" >&2
        return 3
    fi

    # Forma pedida não conferida é "voltou incompleto" virando resposta. Só o
    # chamador sabe a forma, então ela é opcional; quando declarada, cascata
    # desce sem cooldown: a forma errada é do worker, não do pool.
    if [[ -z "$WORKTREE" && -n "$EXPECT_LINES" ]]; then
        local linhas; linhas=$(grep -cE '[^[:space:]]' "$TMP_OUT" || true)
        if (( linhas < EXPECT_LINES )); then
            log_falha_gasta "$backend" "bad_shape" "linhas=$linhas esperado>=$EXPECT_LINES" "$pkey" "$dur"
            echo "⚠️  $backend devolveu $linhas linha(s); esperava >= $EXPECT_LINES linhas — cascata desce" >&2
            return 1
        fi
    fi
    if [[ -z "$WORKTREE" && -n "$EXPECT_REGEX" ]] && ! grep -qE "$EXPECT_REGEX" "$TMP_OUT"; then
        log_falha_gasta "$backend" "bad_shape" "não casa --expect-regex" "$pkey" "$dur"
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
        # Lugar novo primeiro, lugar antigo depois: árvore criada antes desta mudança
        # continua reaproveitável, e --continue nunca apaga trabalho.
        WT_DIR="$WT_ROOT/$(wt_nome_repo "$WORKTREE")/$CONTINUE_SLUG"
        if ! git -C "$WT_DIR" rev-parse --git-dir >/dev/null 2>&1; then
            WT_DIR="$(git -C "$WORKTREE" rev-parse --path-format=absolute --git-common-dir)/../.delegate-wt/$CONTINUE_SLUG"
        fi
        git -C "$WT_DIR" rev-parse --git-dir >/dev/null 2>&1 || die "--continue: worktree do slug '$CONTINUE_SLUG' não existe nem em $WT_ROOT nem no lugar antigo dentro do repo — rode sem --continue pra criar uma nova"
        base_ref="${BASE_REF:-$(git -C "$WORKTREE" merge-base HEAD "$WT_BRANCH" 2>/dev/null)}"
        [[ -n "$base_ref" ]] || base_ref="$WT_BRANCH^"
        WT_BASE_SHA=$(git -C "$WORKTREE" rev-parse --short "$base_ref" 2>/dev/null || echo "?")
    else
        # base da worktree: --base explícito > branch em que o repo está > HEAD.
        # NUNCA origin/main implícito, e não mais o trunk do project.yaml: a sessão
        # que despacha quase sempre está na branch de uma spec, e o trunk fazia o
        # worker construir contra uma base sem o trabalho dela. Medido em
        # 21/set/2026: ele cobriu doze flags porque a décima terceira não existia
        # na base que recebeu, e o diff não entrou por cherry-pick. Repo parado no
        # trunk cai no mesmo commit de antes, porque aí a branch É o trunk. O nome
        # da branch em vez de "HEAD" porque ele vai pro report, e "base: HEAD" não
        # diz a ninguém de onde o trabalho saiu.
        base_ref="$BASE_REF"
        [[ -n "$base_ref" ]] || base_ref=$(git -C "$WORKTREE" symbolic-ref --short -q HEAD)
        [[ -n "$base_ref" ]] || base_ref="HEAD"
        git -C "$WORKTREE" rev-parse --verify -q "$base_ref" >/dev/null || die "--base '$base_ref' não resolve em $WORKTREE"
        WT_BASE_SHA=$(git -C "$WORKTREE" rev-parse --short "$base_ref")

        # Mesma identidade da task: antes a árvore tinha um slug próprio, então
        # `tasks/<id>/` e `branch=delegate/<slug>` não se juntavam, e casar os dois
        # à mão era a caçada que o campo `material` existe pra matar.
        slug="$TASK_ID"
        WT_BRANCH="delegate/$slug"
        WT_DIR="$WT_ROOT/$(wt_nome_repo "$WORKTREE")/$slug"
        mkdir -p "$(dirname "$WT_DIR")" || die "não consegui criar a raiz das árvores em $WT_ROOT"
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
# A branch nasce aqui, depois do meta inicial: reestampar é o que dá à camada de
# terminal o que mostrar enquanto a task corre, em vez de só quando ela fecha.
[[ -n "$WT_BRANCH" ]] && task_estado "em curso"
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

# Config da entrada em curso da cascata. Global e não `local` porque quem a lê é
# o invoke_backend, e nasce `{}` porque entrada sem config é o caso comum.
ENTRY_CONFIG='{}'

run_cascade() {
    local entry backend model effort rc
    while IFS= read -r entry; do
        backend=$(jq -r '.backend' <<<"$entry")
        model=$(jq -r '.model // empty' <<<"$entry")
        effort=$(jq -r '.effort // empty' <<<"$entry")
        ENTRY_CONFIG=$(jq -c '.config // {}' <<<"$entry")
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
        # Degrau que não deu certo devolve o balde na hora. Soltar só no fim
        # deixaria um erro prender o balde pelo resto da chamada, e a cascata
        # desceria por um motivo que já passou.
        [[ -n "$SLOT_TOMADO" ]] && { slot_soltar "$SLOT_TOMADO"; SLOT_TOMADO=""; }
        trilha_add "$(pool_key "$backend" "$model")" "rc$rc"
    done < <(jq -c '.[]' <<<"$CASCADE")
    return 1
}

USED="" USED_POOL="" USED_MODEL="" SALDO_NA_ESCOLHA=""

# O corpo da chamada vira função porque ele roda em dois lugares: aqui, quando o
# despacho é serial, e num filho, quando é assíncrono. Duplicar isso seria manter
# dois caminhos de report que divergem calados.
executar() {
    if run_cascade; then
        echo "worker: $USED" >&2   # linha estável pra consumidores (peer-review), não reformatar
        # Uma vez, e depois de saber quem atendeu. Dentro do laço da cascata a
        # função rodava por degrau e só o último valor virava log, então num
        # despacho que pula todos os baldes dois terços do trabalho dela era
        # descartado. Quem não alcançou worker nenhum cai no output capturado.
        MATERIAL=$(transcript_de "$USED" "${WT_DIR:-$PWD}" "$PROMPT_FILE")
        if [[ -n "$WT_DIR" ]]; then
            ( cd "$WT_DIR" && git add -A && git -c user.name=delegate -c user.email=delegate@local commit -qm "delegate($TASK): output de $USED" ) || true

            # diff vazio ≠ sucesso: worker pode devolver rc=0 sem ter feito nada (falha silenciosa).
            if [[ -z "$(git -C "$WT_DIR" status --porcelain)" ]] && \
               [[ -z "$(git -C "$WORKTREE" diff --name-only "$base_ref...$WT_BRANCH" 2>/dev/null)" ]]; then
                echo "⚠️  worker ($USED) produced no changes (suspected silent failure)" >&2
                echo "branch: $WT_BRANCH (base=$base_ref @ $WT_BASE_SHA)" >&2
                echo "--- resumo do worker ---" >&2
                cat "$TMP_OUT" >&2
                log_usage "$TASK" "$USED" "empty_diff" "${USED_MODEL:+model=$USED_MODEL }branch=$WT_BRANCH base=$base_ref saldo=${SALDO_NA_ESCOLHA:-livre}" "$USED_POOL" 0 0 "${DUR_S:-0}"
                task_estado falhou 5
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
        log_usage "$TASK" "$USED" "ok" "${USED_MODEL:+model=$USED_MODEL}${WT_BRANCH:+ branch=$WT_BRANCH} saldo=${SALDO_NA_ESCOLHA:-livre}" "$USED_POOL" \
            "$(wc -c < "$PROMPT_FILE")" "$(wc -c < "$TMP_OUT")" "${DUR_S:-0}"
        task_estado pronta 0
        exit 0
    fi

    # cascata esgotada: só remove worktree criada nesta chamada; --continue nunca apaga trabalho reaproveitado
    # A branch sai do meta junto com a branch de verdade: o campo diz onde o
    # trabalho está, e apontar pra ref apagada é pior que não apontar pra nada.
    [[ -n "$WT_DIR" && "$WT_FRESH" == "1" ]] && { git -C "$WORKTREE" worktree remove --force "$WT_DIR" 2>/dev/null; git -C "$WORKTREE" branch -D "$WT_BRANCH" 2>/dev/null; WT_BRANCH=""; } >/dev/null
    echo "⚠️  Nenhum worker disponível na cascata pra task '$TASK'. A sessão assume." >&2
    log_usage "$TASK" "-" "unavailable" "cascata esgotada: ${TRILHA:-nenhum degrau elegível}"
    # Dos quatro estados terminais, prazo estourado é o único que a cascata sabe
    # separar de falha comum, e separar importa: prazo diz que o worker estava
    # trabalhando, falha diz que ele não assumiu.
    if [[ "$HOUVE_PRAZO" == 1 ]]; then task_estado "estourou o prazo" 2; else task_estado falhou 2; fi
    exit 2
}

if [[ "$ASYNC" == 1 ]]; then
    echo "task: $TASK_ID"
    if [[ -n "${DELEGATE_SERIAL:-}" ]]; then
        # Escape hatch do rollback: devolve o despacho pro modo serial sem que o
        # chamador precise mudar de flag.
        echo "▶ DELEGATE_SERIAL ligado, despachando em modo serial" >&2
        executar   # termina em exit por todos os caminhos, então nada segue daqui
    fi
    # O prompt muda de casa antes do fork: o trap do pai apagaria ele debaixo do
    # filho. O filho apaga quando termina, porque prompt guardado é conteúdo do
    # repo parado no disco sem servir a diagnóstico nenhum.
    mv "$PROMPT_FILE" "$TASK_DIR/prompt.txt" && PROMPT_FILE="$TASK_DIR/prompt.txt"
    # Sem redirecionar, a substituição de comando do chamador esperaria o filho
    # fechar o pipe, e o despacho continuaria pendurado com outro nome.
    trap - EXIT
    # O redirecionamento é do subshell INTEIRO, e não só do executar: qualquer
    # comando do filho que ainda enxergue o pipe do pai mantém ele aberto, e a
    # substituição de comando do chamador segue esperando, com o despacho
    # pendurado sob outro nome.
    # O trap vai DENTRO do filho porque o executar termina em exit, e comando
    # depois dele no subshell nunca roda: sem isso o balde só voltava a ficar
    # livre por expiração, e o slot ficava no disco sem dono.
    ( trap 'rm -f "$TASK_DIR/prompt.txt"; [[ -n "$SLOT_TOMADO" ]] && slot_soltar "$SLOT_TOMADO"' EXIT
      executar ) >"$TASK_DIR/report.txt" 2>&1 <&- &
    disown 2>/dev/null || true
    exit 0
fi
executar
