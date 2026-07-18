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

**Cuidado com wrappers de API globais** (ex.: aliases `--1m`/context window estendida no shell): podem desabilitar auto-compact e inchar sessões muito além do necessário, sem ganho proporcional. Prefira auto-compact com teto explícito (`CLAUDE_CODE_AUTO_COMPACT_WINDOW` + `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE`) a wrapper manual.
