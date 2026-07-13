# Runbook — workflow multi-modelo (delegate + rankings)

Spec: SPEC-2026-002 (`specs/done/spec-2026-002-multi-model-dispatch/`)
Atualizado em: 2026-07-05

## Quando rodar

- **Automático:** cron local dias 1 e 15 às 10h17 (`crontab -l | grep refresh`)
  roda `scripts/refresh-model-rankings-cron.sh` → proposta em
  `gate/model-rankings/proposal-*.md` + linha no `inbox.md`.
- **Manual:** invocar `/refresh-model-rankings` numa sessão Claude.
- **Aprovação de proposta:** ao processar o inbox — a skill cobre a aplicação
  (Fase 3: aplicar diff, validar jq, suite verde, copiar pra
  `config/model-policy-history/`, commit).

## Pré-requisitos (one-time)

- `codex` logado (`~/.codex/auth.json`) e `agy` logado.
- `jq` instalado; `~/.claude` é repo git.
- Backend `claude_api` (só projetos com scope pago configurado): `DELEGATE_ANTHROPIC_API_KEY` viva
  no `env_file` da policy (`$HOME/.config/your-project/.env`). Chave ausente/rotacionada → backend é pulado
  com aviso no stderr, cascata segue.

## Fluxo do dia a dia

- Delegar: `~/.claude/scripts/delegate.sh --task <type> - < prompt` (a skill
  `delegate` orquestra; types e hierarquia em `config/model-policy.json`).
- Worktree órfã: `delegate.sh --gc <repo-dir>`.
- Log de uso: `gate/delegate.log`; log do cron: `gate/model-rankings/cron.log`.

## Troubleshooting

- **Timestamps do `delegate.log` são UTC** (−3h vs São Paulo) — 16:37Z = 13:37
  local do mesmo dia.
- **Sangria de quota**: não há cap diário fixo (dentro de um CLI, a prioridade
  cede primeiro sem derrubar os outros). A quota costuma ser proporcional a
  tokens, então a defesa real é fatiar prompts grandes (um scan por subsistema),
  não contar despachos.
- **Tudo caindo em exit 2 ("Claude assume")**: checar cooldowns
  (`ls gate/cooldown.*` — apagar pra resetar), login/quota dos CLIs, e se
  `DELEGATE_DISABLED` está setado.
- **"policy inválida" no stderr**: `jq . config/model-policy.json`; corrigir e
  a linha do inbox some de reaparecer (append é idempotente).
- **Cron não rodou**: `grep refresh <(crontab -l)`; log em
  `gate/model-rankings/cron.log`; macOS pede Full Disk Access pro cron em
  algumas versões.
- **Desligar tudo**: `export DELEGATE_DISABLED=1` (peer-review cai no fallback
  adversarial do Claude, fluxo antigo).
