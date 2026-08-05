# Multi-conta no Claude Code (maracaja + exitlag simultâneos)

Duas contas rodando ao mesmo tempo, em abas diferentes do terminal, sem logout.

## Comandos

```
claude            # conta MARACAJA (perfil ~/.claude-maracaja) — default da casa
claude-exitlag    # conta EXITLAG  (perfil ~/.claude-exitlag)
```

`claude` é **função no `~/.zshrc`** (seta `CLAUDE_CONFIG_DIR` e chama `command claude`)
— função, não wrapper, pra sobreviver a updates do binário em `~/.local/bin/claude`.
Baseline no `~/.zshenv`: `export CLAUDE_CONFIG_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude-maracaja}"`
(default guardado — cobre shell novo de qualquer tipo sem clobrar o exitlag).
**Aba aberta antes da mudança não relê rc** — `source ~/.zshrc` nela ou abrir aba nova.
`claude-exitlag` é wrapper em `~/.local/bin/`. Flags passam direto (`--resume`, `-p`, etc.).
Statusline mostra `[MARACAJA]` (amarelo) / `[EXITLAG]` (vermelho) — `scripts/statusline.sh`.

O perfil PESSOAL (dir default `~/.claude` como config) foi aposentado em 2026-08-05:
o estado dele (projects/memórias) foi fundido no maracaja, e o que era de exitlag foi
pro perfil exitlag. `~/.claude/projects/` original permanece como backup da fusão.
`~/.claude` segue sendo o repo way-of-work (skills/docs/hooks compartilhados).

## Mecanismo

`CLAUDE_CONFIG_DIR` troca o diretório de estado do Claude Code. A credencial vai
pro Keychain do macOS no serviço `Claude Code-credentials-<sha256(CLAUDE_CONFIG_DIR)[0:8]>`;
o dir default (`~/.claude`) usa o nome legado `Claude Code-credentials`, sem sufixo.
Perfil novo nasce **sem** credencial (`loggedIn: false`) — não herda nada do default.

**Renomear um perfil muda o hash** → a credencial antiga fica órfã. Ou se copia a
entrada no Keychain pro serviço com hash novo, ou se faz `/login` uma vez no perfil
renomeado (aconteceu no rename trabalho→exitlag).

Ver entradas ativas:

```sh
security dump-keychain | grep -A1 '"svce"' | grep -i claude | sort -u
printf '%s' "$HOME/.claude-exitlag" | shasum -a 256 | cut -c1-8   # hash do perfil
```

`CLAUDE_CONFIG_DIR` é env **não documentado**. Funciona na 2.1.219; pode mudar sem aviso.

## O que é compartilhado

Symlink pro `~/.claude` (edita num lugar, vale nos dois): `AGENTS.md`, `CLAUDE.md`,
`skills/`, `hooks/`, `scripts/`, `config/`, `docs/`, `plugins/`.

Isolado por perfil: credencial, `projects/` (memória, histórico), `sessions/`,
`.claude.json` (MCP), `settings.json`, caches.

Estado que segue compartilhado de propósito, por path fixo nos scripts:
`~/.claude/gate/` (cooldown do peer-review) e `~/.claude/relatorios/`.

Hook config-dir-aware: `hooks/memory_log_append.py` — valida
`<config-dir>/projects/*/memory/` via `CLAUDE_CONFIG_DIR`. Coberto por
`hooks/test_memory_log_append.py` cenário 7.

## Login (uma vez por perfil)

**Nunca rodar `logout`** — logout revoga refresh token no servidor. Perfil sem
credencial: abrir e `/login` com a conta certa.

Verificar (sem `ANTHROPIC_API_KEY` no ambiente, senão o status reporta `api_key`):

```sh
env -u ANTHROPIC_API_KEY claude auth status
env -u ANTHROPIC_API_KEY claude-exitlag auth status
```

## MCP

OAuth de MCP mora na mesma entrada de Keychain do perfil → re-login por perfil.
`.claude.json` é por perfil; servidores de scope local (por cwd) precisam ser
recadastrados no perfil onde forem usados. MCPs user-scope que só existiam no
`.claude.json` do perfil pessoal aposentado: recadastrar no maracaja se fizerem falta.
Ver memória `reference_mcp_scope_precedence`.

## Rollback

```sh
# desfazer o default maracaja: remover a função `claude()` do ~/.zshrc
mv ~/.claude-exitlag ~/.claude-trabalho     # desfaz o rename (credencial antiga volta a casar)
rm ~/.local/bin/claude-exitlag
```

Statusline volta ao default removendo `statusLine` de `~/.claude/settings.json`.

## Limites

Uso/rate limit contam por conta (efeito desejado). Usar cada conta só no escopo dela.
Perfil não é amarrado a diretório: `cd` na pasta de exitlag + `claude` por reflexo
roda na conta maracaja. Amarração por cwd é evolução possível do wrapper.
