# RTK — Rust Token Killer

CLI proxy que reduz tokens em ops de dev (60-90%). Hook reescreve comandos automaticamente (`git status` → `rtk git status`, transparente). Atua na **saída do comando**, antes de entrar no transcript. Sempre-ligado via hook.

**Meta commands** (rodar `rtk` direto, sem proxy):

```bash
rtk gain              # analytics de economia
rtk gain --history    # histórico por comando
rtk discover          # oportunidades perdidas em sessões anteriores
rtk proxy <cmd>       # raw, sem filtro (debug)
```

Se `rtk gain` falhar com "command not found", pode ser colisão de nome com reachingforthejack/rtk (Rust Type Kit). Verificar com `which rtk`.

## Headroom — removido (2026-07-04)

Camada 2 de compressão de payload, eliminada após incidente de consumo: o wrap com `--1m` foi aliasado globalmente no `.zshrc`, desabilitando o auto-compact — sessões incharam para 170k+ de contexto médio (pico 337k, faixa premium 2×), queimando o session limit em 2-3h. Economia real do headroom: só 3,4%. Lições:

- Janela de 1M sem teto de compact = hemorragia de input tokens; o custo dominante é o contexto reenviado a cada turno, não o output (`effort low` não protege).
- Wrapper de API "efêmero" pode grudar (deixou `ANTHROPIC_BASE_URL` em settings.local.json e MCP server registrado) — auditar settings após remover qualquer wrapper.
- Auto-compact hoje é forçado em 400k via `CLAUDE_CODE_AUTO_COMPACT_WINDOW=400000` + `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE=100` no settings.json.
