# Camada de terminal: ver as tasks em curso

Com despacho assíncrono, três tasks correm em baldes de cota diferentes e o
terminal da sessão mostra uma por vez. A camada é a tela que mostra as três.

A ferramenta é o herdr, e a fronteira é dura: **a camada lê o gate e nunca
escreve nele**. O despachante não cita o herdr em nenhuma linha, então desligar a
camada muda o que aparece e não muda quem trabalha. O porquê da escolha e o que
foi recusado estão em `docs/adrs/adr-0001-camada-de-terminal.md`.

## O leitor

```bash
delegate.sh --tasks
```

Uma linha por task em curso: identificador, balde, tipo de task, branch. Sem
nada em curso, imprime `nenhuma task em curso`. Task que fechou sai da listagem
no mesmo instante em que solta o balde, e slot de worker morto também sai, pela
mesma expiração que libera a cota. Para o detalhe de uma linha, incluindo o
caminho do material que o worker produziu, `delegate.sh --status <id>`.

Branch vazia é despacho sem árvore de trabalho, e não erro de leitura: quem roda
sem `--worktree` escreve na árvore da sessão e não tem branch própria.

## A tela

Dentro de uma sessão do herdr, um pane com o leitor em laço:

```bash
herdr pane split w1:p1 --direction down --ratio 0.3
herdr pane rename w1:p2 "delegate: tasks em curso"
herdr pane run w1:p2 'while :; do clear; date +%H:%M:%S; delegate.sh --tasks; sleep 2; done'
```

Os IDs de pane saem de `herdr pane list`. O `pane run` digita o comando no shell
do pane, então o laço vai como **um argumento entre aspas simples**: solto, o zsh
do pane quebra no `do` antes de rodar qualquer coisa.

## O que a camada não faz

Não escolhe worker nem modelo, não lê policy, não mata task e não mostra conteúdo
de transcript, só o caminho dele. Worker interativo dentro de pane está fora, e é
a alternativa que o ADR recusou de propósito.
