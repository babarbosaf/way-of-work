---
status: vigente
harvest: README.md, AGENTS.md
---

# PRD: way-of-work

## 1. Visão geral

Um modelo de trabalho com agentes, versionado, que transforma pedido em código
entregue com rastro. Quem usa é uma pessoa que trabalha com agentes em muitos
projetos ao mesmo tempo, e os próprios agentes, que leem daqui o que fazer.

O produto é o conjunto de regras, fases e travas que torna o trabalho de agente
auditável depois, e não a ferramenta que o executa. Quatro pilares:

- **Uma instrução, muitos harnesses.** O `AGENTS.md` é a fonte, e qualquer
  ferramenta que leia o padrão consome sem tradução. Nada do núcleo depende de
  um modelo ou de um harness específico.
- **Cada fase deixa artefato que sobrevive à sessão.** Spec, ticket, ADR,
  memória e handoff existem porque a janela de contexto acaba no meio do
  trabalho, e o que não virou arquivo morre com ela.
- **Trabalho mecânico sai da sessão.** O que não precisa do contexto vivo vai
  pra um worker externo, com cota, prazo e protocolo de integração.
- **Toda regra nomeia quem a cobra.** Hook que bloqueia em runtime, lint que roda
  antes do commit, ou assert na suíte. Regra sem nenhum dos três não entra.

Os domínios abaixo são numerados na ordem em que aparecem num dia de trabalho.

## 2. Ciclo de trabalho

### Modelo

Pedido entra, e a primeira decisão é o trilho. Errar o trilho para cima custa
cerimônia sobre trabalho de dez minutos; errar para baixo perde o contrato de
uma feature que vai durar semanas. O default é o trilho mais barato, com
promoção quando o trabalho cresce.

### Estrutura

| Trilho | Quando | O que produz |
|---|---|---|
| Direto, com TDD | todo o resto | commit verde |
| Plan mode | o *quê* está fechado, o *como* tem mais de uma forma defensável | plano com arquivo tocado por passo |
| `/kickoff-project` | projeto novo | PRD, ROUTES, DESIGN, CONVENTIONS, AGENTS, FEEDBACK |
| `/to-spec` → `/to-tickets` → `/execute` | várias sessões, muitos arquivos, toca contrato ou prod | uma PR, um commit verde por ticket |

A promoção é mecânica: plano que passou de cinco passos, ou que o dono quis
salvar, já é spec.

### Regras

O backlog tem cinco estágios de maturidade, e um item aparece em exatamente um
deles. Promover é mover, nunca copiar.

| Estágio | Onde vive | O que já existe | Morre em |
|---|---|---|---|
| 0 capturado | `INBOX.md` | uma linha crua | 30 dias |
| 1 aceito | `TODOS.md` | uma linha, tipo e tamanho | 90 dias no `## Pool` |
| 2 contratado | `docs/specs/<slug>/spec.md` | contrato e decisões | ao entregar |
| 3 endereçado | `docs/specs/<slug>/tickets/` | arquivos, aceite, verify | ao entregar |
| 4 entregue | some | PRD, código e `CHANGELOG.md` | n/a |

O custo de entrada cresce com o estágio: captura é uma linha, dossiê só se
escreve na véspera do build. Fundir os estágios 1 e 2 é o gerador de lixo, porque
produz 25 linhas de análise antes de alguém decidir que o item importa.

### Edge cases

- **Spec aprovada é append-only.** Contrato que muda no caminho ganha
  `## Revisão N` com a decisão nova e o ticket que ela cria. O texto aprovado
  fica. Sem isso, cada rodada de review engorda o contrato em vez de gerar
  trabalho.
- **Ticket fora do brief não roda.** Escopo cresce por ticket novo, e o dono vê.
- **Ticket que estourou o prazo ou voltou pro orquestrador no meio era amplo**, e
  essa medição retrospectiva é o que recalibra o corte de tamanho.
- **Achado colateral se resolve na sessão** quando tem a ver com o trabalho em
  curso, ou quando não tem mas bloqueia. Só o resto desce pro backlog.


## 3. Delegação e orquestração de workers

### Modelo

O orquestrador é a sessão que conversa com o dono, e ela não gasta a própria
janela em trabalho mecânico. Varredura de codebase, boilerplate, teste repetido
e segunda opinião vão pra um worker externo, que roda numa worktree separada e
devolve um diff. Quem integra é sempre o orquestrador, depois de revisar.

O que decide onde a task roda é dado, nunca julgamento na hora:
`config/model-policy.json` é a fonte única, com override pessoal em
`config/model-policy.local.json`, que é gitignored e funde em runtime.

### Estrutura

Cinco tipos de task (`boilerplate`, `implement`, `pesquisa`, `review`, `scan`),
três backends (`codex`, `agy`, `claude`), e uma cascata por tipo: o despachante
desce a fila até achar backend elegível, com cota e sem castigo.

Cota é por **balde**, e balde não é backend: um provedor com dois pools conta
separado.

| Balde | Teto por janela |
|---|---|
| `codex` | 10 chamadas |
| `agy:gemini` | 4 chamadas |
| `agy:claude_gpt` | 2 chamadas |
| `claude` | sem régua, porque o pico medido é piso de uso e não teto de cota |

Falha não desabilita backend, arma cooldown, e a classe do limite escolhe a
duração.

| Classe | Espera |
|---|---|
| `rate_limit` | 1 min |
| `transient` | 10 min |
| `tier_fallback` | 60 min |
| `silent_fail` | 60 min |

### Regras

- **Cota esgotada de um pool não é veredito sobre o backend.** O provedor segue
  elegível pelos outros pools dele.
- **Falha de CLI arma cooldown, nunca vira `enabled: false` na config.** Sondagem
  mede a janela, e escrever o resultado na policy congela um estado temporário.
- **O prompt tem teto em bytes**, medido no log: o maior resultado útil entrou
  com 93.588 bytes, e o teto mora na policy, não no script.
- **Prazo por tipo de task mora na policy**, e nenhum consumidor crava número
  próprio.

### Edge cases

- **Worker que escapou da worktree** aparece no `git status` da árvore principal,
  e é por isso que o protocolo de integração começa por ali, antes de rodar
  teste.
- **Worker ruim mas recuperável** ganha um retry com feedback no prompt; ruim de
  novo, a sessão assume a task.
- **Worktree nasce fora do repositório**, porque o worker recusa escrita dentro
  do diretório de configuração dele, e quando o repositório clonado é esse
  diretório, a árvore interna deixa o degrau sem como rodar.
- **Finding do worker vira issue**, nunca some no report.


## 4. Camada de sessões

### Modelo

Um worker despachado às cegas não tem nome nem estado visível, então worker
parado esperando resposta fica idêntico a worker trabalhando. A diferença só
aparece no prazo estourado, com a cota já gasta.

O modo visível resolve isso colocando o worker numa aba nomeada do multiplexer,
que o dono vê na lateral, e que a sessão consegue dirigir. É **opcional e
pedido**: sem a flag, nenhuma linha de código toca a ferramenta de terminal, e o
despacho é byte a byte o de antes.

### Estrutura

| Verbo | O que faz |
|---|---|
| abrir | cria a aba com o nome do trabalho, sobe o worker interativo, devolve o painel |
| instruir | digita a instrução na sessão viva e espera ela voltar a parar |
| ler | devolve o que está na tela agora |
| assumir | foca o painel, e o dono continua a conversa sem trocar de processo |
| fechar | grava a tela em arquivo e só então fecha a aba |

Os nomes da ferramenta moram num arquivo só, `scripts/herdr-adapter.sh`. Trocar
de multiplexer é reescrever esse arquivo, não caçar o nome espalhado.

### Regras

- A aba nasce com o nome do trabalho, nunca com um contador.
- Quem dirige se distingue na lista por marca no rótulo, e o estado mora no
  rótulo da aba e num registro em disco, não em metadado da ferramenta, porque
  metadado expira sozinho e apagaria justo a linha que precisa aparecer.
- Aba parada além de 30 minutos fecha sozinha, com a tela gravada antes. O prazo
  é dado da policy, em `visivel.ciclo`, e nenhum ponto de chamada escolhe
  duração.
- Quem chama a varredura é o `--gc` do despachante, guardado por existir registro
  de sessão.

### Edge cases

- **Sessão órfã**, cujo despachante morreu, não fecha por prazo nenhum: worker
  vivo sem dono é o caso que precisa aparecer, e o prazo esconderia justo ele.
  Ela fica na lista, marcada, esperando decisão de gente.
- **Máquina sem a ferramenta** completa o despacho comum sem perceber que a
  camada existe. Pedir o modo visível ali falha nomeando o que falta, em vez de
  cair calado no modo antigo.
- **Instrução longa não vai pelo canal de prompt da ferramenta**, que a entrega
  como conteúdo colado e faz o worker recusá-la como injeção. Vai como texto
  digitado.
- **O que a aba devolve é o buffer da tela, não um arquivo**, então fechar sem
  gravar apaga o material que o dono quer ler depois.


## 5. Memória e continuidade

### Modelo

Duas coisas atravessam o fim de uma sessão, e elas não se misturam. **Memória** é
fato durável sobre o dono, sobre como trabalhar e sobre recursos externos.
**Handoff** é estado transiente de trabalho em curso, que morre quando o trabalho
fecha.

Misturar os dois produz memória cheia de status obsoleto, que é pior que memória
vazia, porque o agente age com ela.

### Estrutura

Memória é um arquivo por fato, com frontmatter, indexado num `MEMORY.md` que
carrega uma linha por memória. Quatro tipos: `user`, `feedback`, `project`,
`reference`.

Handoff é um arquivo só, em `_tmp/`, gitignored. Substitui, não acumula: dois
handoffs vivos na mesma pasta é achado.

### Regras

| Artefato | Prazo | O que acontece no fim |
|---|---|---|
| handoff | `Morre em:` em ISO, default 14 dias | absorve o que sobrou e apaga |
| item do `INBOX.md` | 30 dias | promove ou apaga |
| item do `## Pool` | 90 dias | promove ou apaga |
| `FEEDBACK.md` | teto de 10 entradas | o que virou norma promove ao doc permanente |

Transiente sem prazo nunca é apagado, e por isso a data se escreve, não se
presume. A regra de não acumular falhou dezenas de vezes antes de existir data,
porque prosa não se executa.

### Edge cases

- **Memória que conflita com o `AGENTS.md` se corrige na hora.** O arquivo tem
  precedência, e memória velha que sobrevive vira instrução errada.
- **Handoff não escreve em memória, doc, PRD ou backlog.** Fato durável que
  aparece nele vira uma linha de link, e a lição se captura à parte.
- **Memória não versionada**, porque é comportamento de agente, específico da
  máquina.

## 6. Docs vivos

### Modelo

Doc de estado descreve **o presente** ou **o futuro desejado depois das specs em
aberto**. Não existe terceiro tempo. O que foi decidido, tentado e descartado
mora no git e no `CHANGELOG.md`, que é onde histórico tem leitor.

### Estrutura

| Doc | O que carrega |
|---|---|
| `PRD.md` | o que o usuário percebe |
| `CONVENTIONS.md` | o que só quem constrói percebe |
| `ROUTES.md` | fluxo e endereços |
| `DESIGN.md` | padrão visual |
| ADR em `docs/adrs/` | decisão cara de reverter, viva enquanto o `Status:` é vivo |

A fronteira entre os dois primeiros é a que mais escorrega: comportamento
prometido fica no PRD, com link pro CONVENTIONS onde encostar em técnica, e o
detalhamento nunca é duplicado dos dois lados.

### Regras

- **README descreve pra quem chega de fora; AGENTS.md manda em quem já está
  dentro.** A marca é gramatical: README em terceira pessoa, AGENTS.md no
  imperativo. Bloco imperativo dentro do README é sinal de duplicação.
- **Toda linha do `AGENTS.md` é failure-backed:** já vi o agente errar sem ela.
  Linha marginal é líquido negativo, medido: arquivo de contexto escrito por
  humano melhora sucesso em 4% e custa 19% a mais, e gerado por modelo piora 3%
  custando 20% a mais.
- **Decisão superada sai da árvore** pro `archive/` no mesmo commit que aceita a
  substituta, e citação de decisão que não está mais lá bloqueia.
- **Subdoc de PRD carrega as duas direções do grafo:** de quem depende, no topo,
  e quem depende dele, no fim.

### Edge cases

- **Doc de estado que vira decision log** cresce sem fim e ninguém lê até o fim.
  O sinal é estrutural, não lexical: data em heading, não a palavra "histórico"
  no corpo.
- **Texto riscado é o pior dos três hábitos de log**, porque mantém a versão
  velha na frente do leitor com uma marca que só o autor sabe ler.
- **Cortar o decision log não é cortar a regra que ele carregava:** a regra vai
  pro doc que possui o assunto, no imperativo, sem a data e sem as alternativas
  descartadas.

## 7. Enforcement

### Modelo

Toda regra que importa vira hook que bloqueia em runtime, lint que roda antes do
commit, ou assert na suíte. A que depende de o agente lembrar não sobrevive à
primeira sessão com pressa. A mensagem de bloqueio diz o que fazer no lugar, e
todo hook tem kill switch por variável de ambiente, porque enforcement que não se
desliga vira obstáculo quando erra.

### Estrutura

| Trava | O que impede | Kill switch |
|---|---|---|
| `read_size_guard` | leitura grande entrar inteira na janela | `READ_GUARD_DISABLED` |
| `bash_read_guard` | o mesmo despejo, agora via shell | `BASH_READ_GUARD_DISABLED` |
| `noop_flush_guard` | comando no-op usado como descarga de resultado | `NOOP_GUARD_DISABLED` |
| `claude_md_size_guard` | o arquivo de instrução passar do teto | `CLAUDE_MD_GUARD_DISABLED` |
| `memory_log_append` | escrita em memória sem registro | `MEMORY_HOOK_DISABLED` |
| `context7_reminder` | fixar assinatura de lib sem consultar a doc | `CONTEXT7_REMINDER_DISABLED` |

Hook que depende da topologia da máquina, como o que varre repositórios locais
atrás de commit sem push, fica no disco e não entra no template: nome de projeto,
caminho de trabalho e histórico de incidente não são doutrina transferível.

Os lints cobram o que hook nenhum alcança: `check-docs.py` (estado, grafo, ciclo,
decaimento, estágio), `check-spec.py` (spec, tickets, corrente), `check-skill.py`,
`check-writing.py`, e `tests/agnostico.test.sh`, que bloqueia nome de cliente num
repo público.

### Regras

- **Suíte verde é pré-condição de commit**, e a suíte hoje são 11 arquivos de
  teste com 848 asserts, sem rede e sem CLI real.
- **Comportamento novo nasce com teste**, e bug ganha regressão antes da
  correção.
- **Aceite de rodar à mão vira script com assert**, exceto o que só olho humano
  observa, que vira cenário escrito com veredito.

### Edge cases

- **Assert que passa de primeira pode ser vacuoso.** RED se prova por mutação, e
  três asserts desta base nasceram assim: passavam porque o script morria antes,
  ou porque o fixture tornava a condição sempre verdadeira.
- **A suíte encadeada a um filtro de saída informa sucesso mesmo vermelha**,
  porque o rc que chega é o do filtro. Um commit desta base passou assim.
- **Lint novo roda contra o repo antes do commit**, porque fixture e repo real
  divergem calados.


## 8. Restrições invioláveis

- **Chave de API nunca entra em backend nenhum.** O despachante remove a
  variável de toda invocação, e o invariante vale inclusive nos caminhos novos.
- **Push é gate humano.** O agente commita sozinho, e para antes de publicar.
  Aprovação de um caso não se estende ao seguinte.
- **Apagar, publicar, reabrir e mexer em lote são do dono**, e a sessão mede,
  mostra desenho e método, e espera o ok.
- **Log grava caminho, nunca conteúdo** de prompt ou de resposta. A conversa pode
  carregar o repositório inteiro, e despejar isso no log é vazamento, não
  diagnóstico.
- **O repositório é público**, então nome de cliente não entra em lugar nenhum,
  nem em fixture de teste.
- **O que é pessoal vive em `*.local.json`**, gitignored, e funde sobre a base em
  runtime.

## 9. Escrita

Fragmento ganha de frase inteira em instrução densa, e ortografia correta não se
negocia em nenhum dos dois. O linter pega o que é mecânico: travessão, aspa
curva, vocabulário de modelo, frase de enchimento, hedging empilhado, emoji
decorativo em título e densidade de exclamação. O julgamento fica na doutrina da
skill, e no linter só entra regra sem falso positivo.

Texto que outra pessoa vai ler passa pelo `check-writing.py` antes do commit.

## 10. Agnosticismo

O núcleo não depende de modelo nem de harness. O `AGENTS.md` é o arquivo do
padrão, e o ponteiro do harness é uma linha que aponta pra ele, nunca uma cópia.
As skills são doutrina em markdown, então servem de leitura pra qualquer agente;
o despacho por comando é da camada de um harness só.

Ramificação por modelo não entra em doc nenhum, porque apodrece antes da
arquitetura.

## Relacionado

- [`CONVENTIONS.md`](CONVENTIONS.md) consome deste doc o comportamento prometido
  de cada domínio, e carrega o detalhamento técnico que aqui só aparece linkado.
- [`AGENTS.md`](AGENTS.md) consome as restrições e o roteamento, no imperativo,
  pra quem já está dentro executando.
- [`README.md`](README.md) consome a visão geral e os pilares, em terceira
  pessoa, pra quem chega de fora decidir se adota.
