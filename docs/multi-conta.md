# Multi-conta no Claude Code (trabalho + pessoal simultâneos)

Duas contas rodando ao mesmo tempo, em abas diferentes do terminal, sem logout.

## Comandos

```
claude            # conta PESSOAL  (perfil ~/.claude)
claude-pessoal    # idem, explícito — também limpa CLAUDE_CONFIG_DIR herdado
claude-work       # conta de TRABALHO (perfil ~/.claude-trabalho)
```

Wrappers em `~/.local/bin/`. Flags passam direto (`claude-work --resume`, `-p`, etc.).
Statusline mostra `[PESSOAL]` / `[TRABALHO]` (`scripts/statusline.sh`).

## Mecanismo

`CLAUDE_CONFIG_DIR` troca o diretório de estado do Claude Code. A credencial vai
pro Keychain do macOS no serviço `Claude Code-credentials-<sha256(CLAUDE_CONFIG_DIR)[0:8]>`;
o dir default (`~/.claude`) usa o nome legado `Claude Code-credentials`, sem sufixo.
Perfil novo nasce **sem** credencial (`loggedIn: false`) — não herda nada do default.

Ver entradas ativas:

```sh
security dump-keychain | grep -A1 '"svce"' | grep -i claude | sort -u
printf '%s' "$HOME/.claude-trabalho" | shasum -a 256 | cut -c1-8   # hash do perfil
```

`CLAUDE_CONFIG_DIR` é env **não documentado**. Funciona na 2.1.219; pode mudar sem aviso.

## O que é compartilhado

Symlink pro `~/.claude` (edita num lugar, vale nos dois): `AGENTS.md`, `CLAUDE.md`,
`skills/`, `hooks/`, `scripts/`, `config/`, `docs/`, `project-template/`, `plugins/`.

Isolado por perfil: credencial, `projects/` (memória, histórico), `sessions/`,
`.claude.json` (MCP), `settings.json`, caches.

Estado que segue compartilhado de propósito, por path fixo nos scripts:
`~/.claude/gate/` (cooldown do Evaluator) e `~/.claude/relatorios/`.

Hook que precisou virar config-dir-aware: `hooks/memory_log_append.py` — valida
`<config-dir>/projects/*/memory/` via `CLAUDE_CONFIG_DIR` (antes era `.claude` fixo,
e o enforcement morria calado no perfil novo). Coberto por
`hooks/test_memory_log_append.py` cenário 7.

## Login (uma vez por perfil)

Ordem importa. **Nunca rodar `logout`** — logout revoga refresh token no servidor.

1. `claude-work` → `/login` com a conta de trabalho. Cria a entrada com hash própria.
2. `claude` → `/login` com a conta pessoal. Sobrescreve só a entrada legada.

Verificar (sem `ANTHROPIC_API_KEY` no ambiente, senão o status reporta `api_key`):

```sh
env -u ANTHROPIC_API_KEY claude auth status
env -u ANTHROPIC_API_KEY claude-work auth status
```

## MCP

OAuth de MCP mora na mesma entrada de Keychain do perfil → re-login por perfil.
`.claude.json` do perfil novo é cópia, então servidores de scope local (por cwd)
precisam ser recadastrados no perfil onde forem usados.
Ver memória `reference_mcp_scope_precedence`.

## Rollback

```sh
rm -rf ~/.claude-trabalho
rm ~/.local/bin/claude-work ~/.local/bin/claude-pessoal
security delete-generic-password -s "Claude Code-credentials-$(printf '%s' "$HOME/.claude-trabalho" | shasum -a 256 | cut -c1-8)"
```

Statusline volta ao default removendo `statusLine` de `~/.claude/settings.json`.

## Limites

Uso/rate limit contam por conta (efeito desejado). Usar cada conta só no escopo dela.
Perfil não é amarrado a diretório: `cd` na pasta de trabalho + `claude` por reflexo
roda na conta pessoal. Amarração por cwd é evolução possível do wrapper.
