# Multi-conta no Claude Code

Duas contas rodando ao mesmo tempo, em abas diferentes do terminal, sem logout.

Neste doc, `<a>` e `<b>` são os nomes dos seus perfis — troque pelos que você usar.
A convenção que o resto do repo assume: o perfil default fica em `~/.claude-<a>`, o
segundo em `~/.claude-<b>`.

## Comandos

```
claude          # perfil <a> (~/.claude-<a>) — o default
claude-<b>      # perfil <b> (~/.claude-<b>)
```

`claude` é **função no `~/.zshrc`** (seta `CLAUDE_CONFIG_DIR` e chama `command claude`)
— função, não wrapper, pra sobreviver a updates do binário em `~/.local/bin/claude`.
Baseline no `~/.zshenv`: `export CLAUDE_CONFIG_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude-<a>}"`
— default guardado, que cobre shell novo de qualquer tipo sem clobrar o outro perfil.
**Aba aberta antes da mudança não relê rc**: `source ~/.zshrc` nela, ou abrir aba nova.
`claude-<b>` é wrapper em `~/.local/bin/`. Flags passam direto (`--resume`, `-p`, etc.).
Statusline mostra `[A]` / `[B]` — `scripts/statusline.sh` deriva o rótulo do nome do
diretório, então perfil novo aparece sozinho, sem editar o script.

O dir default `~/.claude` continua sendo o clone deste repo (skills, docs, hooks
compartilhados). Ele pode servir de perfil também, mas separar os dois papéis é mais
limpo: o repo num lugar, o estado de cada conta em `~/.claude-<nome>`.

## Mecanismo

`CLAUDE_CONFIG_DIR` troca o diretório de estado do Claude Code. A credencial vai
pro Keychain do macOS no serviço `Claude Code-credentials-<sha256(CLAUDE_CONFIG_DIR)[0:8]>`;
o dir default (`~/.claude`) usa o nome legado `Claude Code-credentials`, sem sufixo.
Perfil novo nasce **sem** credencial (`loggedIn: false`) — não herda nada do default.

**Renomear um perfil muda o hash** e a credencial antiga fica órfã. Ou você copia a
entrada do Keychain pro serviço com hash novo, ou faz `/login` uma vez no perfil
renomeado. Vale saber antes de renomear, não depois.

Ver entradas ativas:

```sh
security dump-keychain | grep -A1 '"svce"' | grep -i claude | sort -u
printf '%s' "$HOME/.claude-<b>" | shasum -a 256 | cut -c1-8   # hash do perfil
```

`CLAUDE_CONFIG_DIR` é env **não documentado**. Funciona na 2.1.219; pode mudar sem aviso.

## O que é compartilhado

Symlink pro clone do repo (edita num lugar, vale nos dois): `AGENTS.md`, `CLAUDE.md`,
`skills/`, `hooks/`, `scripts/`, `config/`, `docs/`, `plugins/`.

Isolado por perfil: credencial, `projects/` (memória, histórico), `sessions/`,
`.claude.json` (MCP), `settings.json`, caches.

Estado compartilhado de propósito, por path fixo nos scripts: `~/.claude/gate/`
(cooldown do peer-review) e `~/.claude/relatorios/`.

Hook config-dir-aware: `hooks/memory_log_append.py` valida
`<config-dir>/projects/*/memory/` via `CLAUDE_CONFIG_DIR` (linhas 31 e 36), então a
fronteira de segurança acompanha o perfil em vez de assumir `~/.claude`.

## Login (uma vez por perfil)

**Nunca rodar `logout`** — logout revoga o refresh token no servidor, e o estrago
não é local. Perfil sem credencial: abrir e `/login` com a conta certa.

Verificar (sem `ANTHROPIC_API_KEY` no ambiente, senão o status reporta `api_key`):

```sh
env -u ANTHROPIC_API_KEY claude auth status
env -u ANTHROPIC_API_KEY claude-<b> auth status
```

## MCP

OAuth de MCP mora na mesma entrada de Keychain do perfil, então re-login é por perfil.
`.claude.json` é por perfil; servidor de scope local (por cwd) precisa ser recadastrado
no perfil onde for usado. Se você aposentar um perfil, os MCPs user-scope que só
existiam no `.claude.json` dele somem com ele — recadastrar no que sobrou.

## Rollback

```sh
# desfaz o default: remover a função `claude()` do ~/.zshrc e a linha do ~/.zshenv
mv ~/.claude-<b> ~/.claude-<nome-antigo>   # desfaz rename: a credencial antiga volta a casar
rm ~/.local/bin/claude-<b>
```

Statusline volta ao default removendo `statusLine` do `settings.json` do perfil.

## Limites

Uso e rate limit contam por conta, que é o efeito desejado — cada conta no escopo dela.
Perfil não é amarrado a diretório: `cd` na pasta de um cliente e `claude` por reflexo
roda na outra conta. Amarração por cwd é evolução possível do wrapper.
