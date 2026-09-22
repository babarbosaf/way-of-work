# Camada de terminal: ver as tasks em curso

Com despacho assíncrono, três tasks correm em baldes de cota diferentes e o
terminal da sessão mostra uma por vez. A camada é a tela que mostra as três.

A ferramenta é o herdr, e a fronteira é dura: **a camada lê o gate e nunca
escreve nele**. O despachante não cita o herdr em nenhuma linha, então desligar a
camada muda o que aparece e não muda quem trabalha. O porquê da escolha e o que
foi recusado estão em `docs/adrs/adr-0001-camada-de-terminal.md`.

## Índice

- **O leitor**, os dois modos de `delegate.sh --tasks` e o contrato de cada um
- **A tela**, a barra de status como default e o pane em laço como alternativa
- **Como o servidor sobe**, o pty e o ambiente que ele guarda enquanto viver
- **O que a camada não faz**, a fronteira que o ADR desenhou

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

Para caber numa barra de status existe o modo de uma linha:

```bash
delegate.sh --tasks --oneline
```

Ele devolve `dlg: <balde> <balde>` com os baldes que têm worker vivo, e **não
devolve nada** quando não há nenhum. O silêncio é o contrato, não economia de
texto: a barra do herdr limpa a entrada quando o output vem vazio, então ocioso
custa zero. Pedir `--oneline` sem `--tasks` é erro de uso e sai 1, porque
modificador de leitura aceito num despacho despacharia calado.

## A tela

Duas superfícies, e a escolha é de quem olha.

### Barra de status, o default

No `~/.config/herdr/config.toml`, que é config do cliente e mora fora deste repo:

```toml
[ui]
tab_bar_right = [
  { type = "command", command = "~/.claude/scripts/delegate.sh --tasks --oneline", interval_seconds = 5, timeout_seconds = 2 },
]
tab_bar_right_separator = " · "
```

O herdr roda o comando no servidor, sem bloquear render e sem sobrepor uma
execução na anterior, aproveita a **última linha** do output e apaga a entrada
quando ele falha, estoura o timeout ou vem vazio. Ocioso então não ocupa nada, e
é por isso que o leitor cala em vez de dizer "nenhuma". Em barra estreita o
status cede espaço pras abas, o que é o comportamento que se quer: a aba importa
mais que o balde.

### Pane em laço, pra acompanhar despacho simultâneo

```bash
herdr pane split w1:p1 --direction down --ratio 0.85
herdr pane rename w1:p2 "delegate: tasks em curso"
herdr pane run w1:p2 'while :; do clear; delegate.sh --tasks; sleep 2; done'
```

Os IDs de pane saem de `herdr pane list`. Dois detalhes medidos custaram tela
antes de entrarem aqui. O `--ratio` é a fatia do **primeiro** pane, não do novo,
então `0.3` dá 69% ao leitor; e o `pane run` digita o comando no shell do pane,
então o laço vai como **um argumento entre aspas simples**, porque solto o zsh do
pane quebra no `do` antes de rodar qualquer coisa.

Num pane vale o modo de várias linhas, que mostra identificador e branch. O
`date` que já apareceu neste laço era heartbeat de quem estava testando, e num
pane ocioso ele vira um relógio ocupando a tela: fora.

## Como o servidor sobe, e por que isso importa

O herdr não tem comando de subida: `herdr server` só aceita `stop` e
`reload-config`, e quem levanta o servidor é o TUI, na primeira vez que alguém
roda `herdr`. Daí sai a armadilha, porque **o servidor guarda o ambiente de quem
o levantou enquanto viver**, e todo pane nasce filho dele.

Subir de dentro de uma sessão de agente exporta as variáveis `CLAUDE_*` daquela
sessão pra cada pane, e a `CLAUDE_CODE_CHILD_SESSION=1` desliga o salvamento de
transcript de qualquer sessão aberta ali, dias depois, sem que nada no cliente
mostre a causa.

Suba de um terminal de gente. Se for preciso subir de um script, limpe o
ambiente antes do `exec`:

```zsh
#!/bin/zsh
for v in ${(f)"$(env | grep -o '^CLAUDE[^=]*')"}; do unset "$v"; done
exec script -q /dev/null herdr
```

O `script -q /dev/null` existe porque o TUI precisa de pty, que é o que falta
quando um agente chama o binário direto. Conferir é `ps eww <pid-do-servidor>`,
e a prova de verdade é abrir um pane e olhar o ambiente lá dentro: numa máquina
limpa sobra só o que o `.zshenv` do dono põe.

## O que a camada não faz

Não escolhe worker nem modelo, não lê policy, não mata task e não mostra conteúdo
de transcript, só o caminho dele. Worker interativo dentro de pane está fora, e é
a alternativa que o ADR recusou de propósito.
