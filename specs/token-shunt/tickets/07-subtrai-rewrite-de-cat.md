07 [S]  O rewrite de `cat` pro rtk sai, porque economiza zero e parece que economiza

O que construir: `rtk-hook-wrapper.sh` passa a bypassar comando de leitura de
arquivo (`cat`, `head`, `tail`, `less`, `more`, `bat`), deixando o guard do
ticket 02 dono desse caminho. O rtk fica no que ele mede bem: saída de comando
(`test` 85.8%, `git diff` 96.2%, `lint` 94.2%), mais `ls`/`tree`/`grep`.

Motivo medido, em bytes: `AGENTS.md` 5223 vira 5222 no `-l minimal` e no
`-l aggressive`. `delegate.sh` 19432 **cresce** pra 19550 no `aggressive`,
porque o filtro devolve vazio e o rtk cai pro bruto mais uma linha de warning. O
default do rewrite é `-l none`, que é 0%. E `rtk gain` credita a esse comando
6914 chamadas e 25.3%, o pior percentual da tabela no maior volume.

files:      scripts/rtk-hook-wrapper.sh, docs/rtk.md
blocked_by: 02
delega:     não
verify:     bash tests/hooks.test.sh

Aceite:
- [x] `cat arquivo` sai do wrapper sem rewrite (rc=0, stdout vazio)
- [x] `git status` continua sendo reescrito pra `rtk git status`
- [x] `git commit`/`git push`/`gh pr create` seguem bypassados como antes
- [x] `docs/rtk.md` registra o número medido e o porquê do bypass
