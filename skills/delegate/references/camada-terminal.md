# Camada de terminal: ver as tasks em curso

Com despacho assíncrono, três tasks correm em baldes de cota diferentes e o
terminal da sessão mostra uma por vez. A camada é a tela que mostra as três.

A ferramenta é o herdr, e a fronteira é dura no caminho padrão: **a camada lê o
gate e nunca escreve nele**. Sem pedir nada, o despacho não toca a ferramenta, e
desligar a camada muda o que aparece e não muda quem trabalha.

Existe um caminho de escrita, e um só: `delegate.sh --visivel <trabalho>` faz a
task virar uma aba nomeada com o worker rodando dentro dela. Ele se pede, falha
nomeando a causa quando a ferramenta não está lá, e não muda nada de quem não o
pede. O porquê da escolha e o que foi recusado estão em
`docs/adrs/adr-0002-camada-de-sessoes.md`.

## Índice

- **O leitor**, os dois modos de `delegate.sh --tasks` e o contrato de cada um
- **A tela**, a barra de status como default e o pane em laço como alternativa
- **O modo visível**, a aba nomeada com o worker vivo dentro
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

Ele devolve `dlg: <balde> <balde>` com os baldes que têm worker vivo, **não
devolve nada** quando não há nenhum, e devolve `dlg: ?` quando não consegue ler o
estado. Ocioso e quebrado precisam de telas diferentes: sair vazio nos dois casos
foi o que deixou a camada morta por um dia inteiro sem ninguém notar. O silêncio é o contrato, não economia de
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

## O modo visível

```bash
delegate.sh --task implement --visivel t04-revisao
```

A task vira uma aba com o nome do trabalho, o worker sobe dentro dela em modo
interativo, e o despacho devolve o endereço do painel. A aba nasce no grupo do
projeto, prefixada por `» `, que é o que distingue as dirigidas da sessão que
dirige.

Quem escolhe o worker é a mesma cascata de sempre, filtrada por quem a medição
aprovou para o modo interativo: o veredito de cada backend mora na policy, com
data e motivo, e worker não medido fica de fora. Cascata inteira inelegível
recusa em vez de cair calada no modo de lote.

Depois de aberta, a sessão se dirige:

```bash
dirige-sessao.sh instruir <painel> "<instrução>"
dirige-sessao.sh ler <painel>
dirige-sessao.sh assumir <painel>
```

`assumir` foca o painel que já existe, então a conversa inteira continua viva e o
processo não troca. Dois detalhes medidos: a instrução vai como texto digitado,
porque o canal de prompt da ferramenta entrega instrução longa como conteúdo
colado e o worker a recusa como injeção; e a espera é por consulta de estado com
prazo próprio, porque a espera embutida já pendurou além de dois minutos com o
worker já tendo respondido.

Os nomes da ferramenta moram em `scripts/herdr-adapter.sh`, e em nenhum outro
arquivo. Trocar de multiplexer é reescrever esse arquivo.

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
de transcript, só o caminho dele. Worker interativo dentro de aba entra pelo modo
visível, que se pede: no caminho padrão ele continua fora, que é a recusa que a
ADR-0001 escreveu e que a ADR-0002 substitui só onde o modo é pedido.
