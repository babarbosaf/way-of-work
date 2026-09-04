# Claude Code specifics

Enforcement do Claude Code. Outros harnesses ignoram tudo aqui.

O hook bloqueia e explica na hora, então este doc é mapa, não manual: serve pra saber o
que existe e onde mexer, não pra consultar durante o trabalho.

## Hooks

| Hook | Evento | O que faz | Kill |
|---|---|---|---|
| `read_size_guard.py` | PreToolUse, Read | bloqueia Read acima de 200 linhas sem `offset`/`limit` | `READ_GUARD_DISABLED=1` |
| `noop_flush_guard.py` | PreToolUse, Bash | bloqueia comando no-op usado como flush de resultado | `NOOP_GUARD_DISABLED=1` |
| `claude_md_size_guard.py` | PreToolUse, Edit/Write | bloqueia edição que estoure o teto de linhas do doc de raiz | `CLAUDE_MD_GUARD_DISABLED=1` |
| `context7_reminder.py` | PreToolUse, Edit/Write | lembra `use context7` em import novo ou manifesto de dependência; não bloqueia | `CONTEXT7_REMINDER_DISABLED=1` |
| `memory_log_append.py` | PostToolUse, Edit/Write | exige append em `memory/log.md` antes de criar ou editar memória | `MEMORY_HOOK_DISABLED=1` |
| `wiki_push_guard.py` | SessionStart | acusa trabalho parado em qualquer repositório do Mac | `WIKI_PUSH_GUARD_DISABLED=1` |

Os cinco primeiros vivem em `~/.claude/settings.json`. O `wiki_push_guard` é registrado
em `~/.claude-maracaja/settings.json`, e só roda nesse perfil.

RTK entra por `scripts/rtk-hook-wrapper.sh`, também em PreToolUse de Bash. Detalhe em
[rtk.md](rtk.md).

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
