# Claude Code specifics

Enforcement do Claude Code. Outros harnesses ignoram tudo aqui.

O hook bloqueia e explica na hora, então este doc é mapa, não manual: serve pra saber o
que existe e onde mexer, não pra consultar durante o trabalho.

## Hooks

| Hook | Evento | O que faz | Kill |
|---|---|---|---|
| `read_size_guard.py` | PreToolUse, Read | bloqueia Read grande sem `offset`/`limit` e roteia por degrau | `READ_GUARD_DISABLED=1` |
| `bash_read_guard.py` | PreToolUse, Bash | mesmo bloqueio pro despejo por `cat`/`head`/`rtk read`; leitura apontada passa | `BASH_READ_GUARD_DISABLED=1` |
| `noop_flush_guard.py` | PreToolUse, Bash | bloqueia comando no-op usado como flush de resultado | `NOOP_GUARD_DISABLED=1` |
| `claude_md_size_guard.py` | PreToolUse, Edit/Write | bloqueia edição que estoure o teto de linhas do doc de raiz | `CLAUDE_MD_GUARD_DISABLED=1` |
| `context7_reminder.py` | PreToolUse, Edit/Write | lembra `use context7` em import novo ou manifesto de dependência; não bloqueia | `CONTEXT7_REMINDER_DISABLED=1` |
| `memory_log_append.py` | PostToolUse, Edit/Write | exige append em `memory/log.md` antes de criar ou editar memória | `MEMORY_HOOK_DISABLED=1` |
| `wiki_push_guard.py` | SessionStart | acusa trabalho parado em qualquer repositório do Mac | `WIKI_PUSH_GUARD_DISABLED=1` |

Todos menos o último vivem em `~/.claude/settings.json`. O `wiki_push_guard` é registrado
em `$CLAUDE_CONFIG_DIR/settings.json` do perfil que o usa, e só roda nesse perfil.

RTK entra por `scripts/rtk-hook-wrapper.sh`, também em PreToolUse de Bash, **depois** do
`bash_read_guard` na cadeia. A ordem importa: o guard decide se a leitura entra nesta
janela antes de o rtk decidir como comprimi-la. Detalhe em [rtk.md](rtk.md).

### Degraus de leitura

Os dois guards de leitura leem o mesmo dado, `.shunt` da `config/model-policy.json`, por
`hooks/shunt_policy.py`. Nenhum dos dois carrega número próprio.

| Tamanho | Rota |
|---|---|
| até `grep_max` (200) | lê inline |
| `grep_max` a `worker_min` (500) | grep pra achar a seção, depois Read com `offset`+`limit` |
| acima de `worker_min` | `delegate.sh --task scan`, e o corpus não entra nesta janela |

Override por sessão: `SHUNT_GREP_MAX` e `SHUNT_MIN_LINES`. Calibrar com o `bytes_in`/
`bytes_out` do `gate/delegate.log`, não por palpite: acima do degrau o worker cobra 10 a
30s de latência, e abaixo dele o overhead come a economia.

### Tetos do size guard

Estão em `hooks/claude_md_size_guard.py`, e valem por nome de arquivo:

| Arquivo | Teto |
|---|---|
| `CLAUDE.md` | 80 |
| `AGENT.md`, `AGENTS.md` | 130 |
| `departments.md` | 40 |
| `MEMORY.md` | 200 (override por `MEMORY_MD_LINE_LIMIT`) |

Como `CLAUDE.md` costuma ser symlink pro `AGENTS.md`, o teto aplicado depende de qual
nome a edição usa. Estourou é sinal de compactar, e o kill switch existe pro caso raro em
que a edição precisa passar antes da limpeza.

## Auto-compact

Forçado em 400k por variável de ambiente. Com trabalho aberto, rodar `/handoff` antes.

## Comandos

Skill despacha por `/`. O REFACTOR do ciclo de testes usa o builtin `/simplify`; em outro
harness, é simplificar na mão com a suíte verde.
