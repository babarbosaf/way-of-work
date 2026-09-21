# RTK, Rust Token Killer

**Opcional.** Sem o binário no PATH, `scripts/rtk-hook-wrapper.sh` sai limpo, nada é
comprimido e nada quebra. Instala e atualiza por `scripts/bootstrap-rtk.sh --apply`
(`--update` puxa o upstream antes de reescrever a config). Dry-run é o default.
Homepage: https://www.rtk-ai.app/, Apache-2.0.

CLI proxy que reduz tokens em ops de dev. O hook reescreve o comando antes de ele rodar
(`git status` vira `rtk git status`, transparente), e o ganho está na **saída**, antes de
entrar no transcript. Sempre-ligado via hook, em PreToolUse de Bash, **depois** do
`bash_read_guard` ([claude-code.md](claude-code.md)).

## O contrato desta máquina é `config/rtk.json`

| Chave | Serve pra |
|---|---|
| `versao_minima` | 0.49.0. Abaixo da 0.47 o `exclude_commands` não casa a forma peeled do comando |
| `hooks.exclude_commands` | o que sai do rewrite, aplicado no `config.toml` do próprio RTK |

O bypass **não** mora no wrapper. O regex que vivia lá casava só o começo da linha e
deixava passar `FOO=1 cat x`, `uv run pytest` e segmento de pipe; o RTK resolve os três
desde a 0.47. Sobrou no wrapper uma coisa só: sair limpo quando o binário falta.

Quem cobra: `tests/hooks.test.sh` roda o payload pelo wrapper e confere as duas direções
(o que é bypassado e o que segue reescrito), mais a igualdade entre o manifesto e o
`config.toml` ativo.

## Leitura de arquivo não passa por aqui

Medido na 0.49.0, em bytes: `AGENTS.md` sai byte a byte igual ao `cat` no default e com
um byte a menos no `aggressive`; `delegate.sh` 28906 sai 28906 nos dois. Ganho zero, e o `rtk gain` credita a `rtk read`
9248 chamadas a 25.9%, o pior percentual do maior volume. O crédito escondia que o
caminho de leitura estava descoberto. Quem manda nele é o `bash_read_guard`, que roteia
pro worker acima do degrau.

Por isso `cat`, `bat`, `less`, `more`, `head` e `tail` estão no `exclude_commands`.

## Dry-run mentiroso: `git add -n`

`rtk git add -n .` devolveu **vazio** com cinco arquivos a stagear (0.49.0). Por isso
`git add` também está no `exclude_commands`. Em máquina sem esta config, conferir staging
por plumbing: `git ls-files --others --exclude-standard` e `git check-ignore <path>`.
`git clean -n` e `git rm -n` atravessam o proxy intactos.

`rtk find` esconde entradas no rodapé (`+21 hidden: rtk recall <hash>`); o que sumiu volta
com `rtk recall <hash>`.

## Como isto não apodrece

O doc afirma coisas sobre um binário que muda sozinho, então as afirmações têm gate em
`tests/hooks.test.sh`:

| Gate | Cai quando |
|---|---|
| `versao_medida` no manifesto | o binário instalado não é mais o que foi medido |
| `rtk read` == `cat` em bytes | o upstream fizer a leitura render, e aí `cat` talvez volte pro rewrite |
| `rtk git add -n` devolve vazio | o upstream consertar o dry-run, e aí `git add` sai do exclude |

Atualizar o rtk sem mexer no doc **quebra a suíte**, que é pré-condição de commit. A saída
do teste diz o que remedir. Fechado o ciclo: remede, corrige o doc, sobe `versao_medida`.

## Onde ele mede bem

Saída de comando: `rtk vitest run` 86.3%, `rtk git diff` 96.2%, `ps aux` via filtro TOML
98.1%, `rtk find` 41.6%.

O `rtk grep` aparece com 13.2% em 12.970 chamadas, e a média engana: ela é puxada pelas
greps de saída curta, onde não há o que cortar. Num caso de saída grande (`grep -rn 'def '`
no repo) são 566.173 bytes contra 14.037, 97.5%. Fica no rewrite.

**Meta commands** (rodar `rtk` direto, sem proxy):

```bash
rtk gain              # analytics de economia
rtk gain --history    # histórico por comando
rtk discover          # oportunidades perdidas em sessões anteriores
rtk recall <hash>     # recupera o que um filtro escondeu
rtk proxy <cmd>       # raw, sem filtro (debug)
```

`rtk gain` avisa `No hook installed — run rtk init -g`: é falso negativo. O RTK procura a
si mesmo no `settings.json` e nosso hook chama o wrapper, não `rtk hook claude`.

**Não rodar `rtk init -g`.** Medido num `CLAUDE_CONFIG_DIR` descartável: ele pergunta
antes de patchar o `settings.json` (e o default não-interativo é não), mas cria um
`RTK.md` e injeta `@RTK.md` no `CLAUDE.md` sem perguntar, e o nosso `CLAUDE.md` é symlink
do `AGENTS.md`, com teto cobrado por `hooks/claude_md_size_guard.py`.

Se `rtk` sumir do PATH com "command not found", pode ser colisão de nome com
reachingforthejack/rtk (Rust Type Kit). Conferir com `which rtk`.

**Cuidado com wrappers de API globais** (ex.: aliases `--1m`/context window estendida no
shell): podem desabilitar auto-compact e inchar sessões muito além do necessário, sem
ganho proporcional. Prefira auto-compact com teto explícito
(`CLAUDE_CODE_AUTO_COMPACT_WINDOW` + `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE`) a wrapper manual.
