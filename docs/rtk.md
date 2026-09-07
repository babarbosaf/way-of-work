# RTK, Rust Token Killer

**Opcional.** O hook `scripts/rtk-hook-wrapper.sh` sai limpo quando o CLI não está
instalado, então o repo funciona sem ele. Instala por `brew install rtk`
(homepage: https://www.rtk-ai.app/, Apache-2.0). Sem o binário no PATH, nada é comprimido
e nada quebra.

CLI proxy que reduz tokens em ops de dev. Hook reescreve comandos automaticamente (`git status` vira `rtk git status`, transparente). Atua na **saída do comando**, antes de entrar no transcript. Sempre-ligado via hook.

## Leitura de arquivo não passa por aqui

`cat`, `head`, `tail`, `less`, `more` e `bat` são bypass no wrapper. Medido em bytes neste
repo: `AGENTS.md` 5223 vira 5222 no `-l minimal` e no `-l aggressive`; `delegate.sh` 19432
**cresce** pra 19550 no `aggressive`, porque o filtro devolve vazio e o rtk cai pro
conteúdo bruto mais uma linha de warning. O default do rewrite era `-l none`, que é 0%.

O `rtk gain` creditava a `rtk read` 6914 chamadas a 25.3%, o pior percentual da tabela no
maior volume, e o crédito escondia que o caminho de leitura estava descoberto. Quem manda
nele agora é o `bash_read_guard`, que roteia pro worker acima do degrau
([claude-code.md](claude-code.md)).

O rtk fica onde ele mede bem: saída de comando (`rtk test` 85.8%, `rtk git diff` 96.2%,
`rtk lint` 94.2%), mais `ls`, `tree` e `grep`.

**Meta commands** (rodar `rtk` direto, sem proxy):

```bash
rtk gain              # analytics de economia
rtk gain --history    # histórico por comando
rtk discover          # oportunidades perdidas em sessões anteriores
rtk proxy <cmd>       # raw, sem filtro (debug)
```

Se `rtk gain` falhar com "command not found", pode ser colisão de nome com reachingforthejack/rtk (Rust Type Kit). Verificar com `which rtk`.

**Cuidado com wrappers de API globais** (ex.: aliases `--1m`/context window estendida no shell): podem desabilitar auto-compact e inchar sessões muito além do necessário, sem ganho proporcional. Prefira auto-compact com teto explícito (`CLAUDE_CODE_AUTO_COMPACT_WINDOW` + `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE`) a wrapper manual.
