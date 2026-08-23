# Runbook do workflow multi-modelo (delegate)


## Pré-requisitos (one-time)

- `codex` logado (`~/.codex/auth.json`) e `agy` logado.
- `jq` instalado; `~/.claude` é repo git.
- Backend `claude_api` (só projetos com scope pago configurado): `DELEGATE_ANTHROPIC_API_KEY` viva
  no `env_file` da policy. Chave ausente/rotacionada → backend é pulado
  com aviso no stderr, cascata segue.

## Fluxo do dia a dia

- Delegar: `~/.claude/scripts/delegate.sh --task <type> - < prompt` (a skill
  `delegate` orquestra; types e hierarquia em `config/model-policy.json`).
- Ajustar hierarquia: editar `config/model-policy.json` direto. Git é o histórico.
- Worktree órfã: `delegate.sh --gc <repo-dir>`.
- Log de uso: `gate/delegate.log`.

## Troubleshooting

- **Timestamps do `delegate.log` são UTC** (−3h vs São Paulo).
- **Sangria de quota**: quota costuma ser proporcional a tokens; a defesa real é
  fatiar prompts grandes (um scan por subsistema), não contar despachos.
- **Tudo caindo em exit 2 ("a sessão assume")**: checar cooldowns
  (`ls gate/cooldown.*`, apagar pra resetar), login/quota dos CLIs, e se
  `DELEGATE_DISABLED` está setado.
- **"policy inválida" no stderr**: `jq . config/model-policy.json` e corrigir.
- **Desligar tudo**: `export DELEGATE_DISABLED=1` (peer-review cai no fallback
  adversarial do Claude).
