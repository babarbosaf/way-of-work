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

```
PEDIDO ──escolhe o trilho (§2)──▶ TRABALHO ──delega o mecânico (§3)──▶ WORKER   `no ar`
                                     │                                   │
                                     │                      roda em worktree própria
                                     │                                   │
                                     ◀──────── diff, revisado antes de integrar ──┘
                                     │
                                     ├──estado visível na aba (§4)──▶ SESSÃO     `no ar`
                                     │
                                     ├──fato durável──▶ MEMÓRIA (§5)             `no ar`
                                     ├──estado em curso──▶ HANDOFF (§5), datado  `no ar`
                                     ▼
                                  COMMIT ──hook, lint, suíte (§7)──▶ ENTREGUE    `no ar`
                                     │
                                     └──promove──▶ DOCS VIVOS (§6)               `no ar`
```

Os domínios abaixo são numerados na ordem em que aparecem num dia de trabalho.

## 2. Ciclo de trabalho

`no ar`

### Propósito

Dar a cada pedido o trilho mais barato que ainda segura o contrato dele, e manter
cada item do backlog em exatamente um estágio de maturidade.

### Fluxo

Pedido entra, e a primeira decisão é o trilho. Errar o trilho para cima custa
cerimônia sobre trabalho de dez minutos; errar para baixo perde o contrato de
uma feature que vai durar semanas. O default é o trilho mais barato, com
promoção quando o trabalho cresce.

O item nasce como linha crua e sobe de estágio quando alguém decide que ele
importa. O custo de entrada cresce junto: captura é uma linha, dossiê só se
escreve na véspera do build. Fundir os estágios 1 e 2 é o gerador de lixo, porque
produz 25 linhas de análise antes de alguém decidir que o item importa.

### Regras

| Trilho | Quando | O que produz |
|---|---|---|
| Direto, com TDD | todo o resto | commit verde |
| Plan mode | o *quê* está fechado, o *como* tem mais de uma forma defensável | plano com arquivo tocado por passo |
| `/kickoff-project` | projeto novo | PRD, ROUTES, DESIGN, CONVENTIONS, AGENTS, FEEDBACK |
| `/to-spec` → `/to-tickets` → `/execute` | várias sessões, muitos arquivos, toca contrato ou prod | uma PR, um commit verde por ticket |

| Estágio | Onde vive | O que já existe | Morre em |
|---|---|---|---|
| 0 capturado | `INBOX.md` | uma linha crua | 30 dias |
| 1 aceito | `TODOS.md` | uma linha, tipo e tamanho | 90 dias no `## Pool` |
| 2 contratado | `docs/specs/<slug>/spec.md` | contrato e decisões | ao entregar |
| 3 endereçado | `docs/specs/<slug>/tickets/` | arquivos, aceite, verify | ao entregar |
| 4 entregue | some | PRD, código e `CHANGELOG.md` | n/a |

| Quando | O produto garante |
|---|---|
| o trabalho está pronto para sair | push é gate humano: o agente commita sozinho e para antes de publicar, e aprovação de um caso não se estende ao seguinte |
| o item sobe de estágio | ele sai do degrau de baixo; promover é mover, nunca copiar |
| o plano passou de cinco passos, ou o dono quis salvar | ele já é spec, e a promoção é mecânica |
| a spec foi aprovada e o contrato mudou no caminho | ela ganha `## Revisão N` com a decisão nova e o ticket que ela cria, e o texto aprovado fica; sem isso cada review engorda o contrato em vez de gerar trabalho |
| um ticket sai do brief | ele não roda, e escopo cresce por ticket novo, que o dono vê |
| um ticket estourou o prazo ou voltou pro orquestrador no meio | ele era amplo, e essa medição retrospectiva recalibra o corte de tamanho |
| um achado colateral tem a ver com o trabalho em curso, ou bloqueia | resolve na sessão; só o resto desce pro backlog |


## 3. Delegação e orquestração de workers

`no ar`

### Propósito

Tirar o trabalho mecânico da janela do orquestrador sem que ele perca o controle
do que entra no repositório.

### Fluxo

O orquestrador é a sessão que conversa com o dono, e ela não gasta a própria
janela em trabalho mecânico. Varredura de codebase, boilerplate, teste repetido
e segunda opinião vão pra um worker externo, que roda numa worktree separada e
devolve um diff. Quem integra é sempre o orquestrador, depois de revisar.

O despachante desce uma cascata por tipo de task até achar backend elegível, com
cota e sem castigo. São cinco tipos (`boilerplate`, `implement`, `pesquisa`,
`review`, `scan`) e três backends (`codex`, `agy`, `claude`). O que decide onde a
task roda é dado, nunca julgamento na hora: `config/model-policy.json` é a fonte
única, com override pessoal em `config/model-policy.local.json`, que é gitignored
e funde em runtime.

### Regras

Cota é por **balde**, e balde não é backend: um provedor com dois pools conta
separado.

| Balde | Teto por janela |
|---|---|
| `codex` | 10 chamadas |
| `agy:gemini` | 4 chamadas |
| `agy:claude_gpt` | 2 chamadas |
| `claude` | sem régua, porque o pico medido é piso de uso e não teto de cota |

| Classe do limite | Espera do cooldown |
|---|---|
| `rate_limit` | 1 min |
| `transient` | 10 min |
| `tier_fallback` | 60 min |
| `silent_fail` | 60 min |

| Quando | O produto garante |
|---|---|
| uma task vai pra qualquer backend | a chave de API não vai junto: o despachante remove a variável de toda invocação, e o invariante vale inclusive nos caminhos novos |
| o despachante grava log | ele grava caminho, nunca conteúdo de prompt ou de resposta, porque a conversa pode carregar o repositório inteiro, e despejar isso no log é vazamento, não diagnóstico |
| uma configuração é pessoal | ela vive em `*.local.json`, gitignored, e funde sobre a base em runtime |
| a cota de um pool esgota | o provedor segue elegível pelos outros pools dele; cota gasta não é veredito sobre o backend |
| um CLI falha | arma cooldown, e nunca vira `enabled: false` na config, porque sondagem mede a janela e escrever isso na policy congela um estado temporário |
| um prompt cresce | ele tem teto em bytes, medido no log (o maior resultado útil entrou com 93.588), e o teto mora na policy, não no script |
| um consumidor precisa de prazo | ele lê da policy por tipo de task, e nenhum crava número próprio |
| um worker escapou da worktree | ele aparece no `git status` da árvore principal, e por isso o protocolo de integração começa por ali, antes de rodar teste |
| um worker devolve trabalho ruim mas recuperável | ganha um retry com feedback no prompt; ruim de novo, a sessão assume a task |
| o repositório clonado é o diretório de configuração do worker | a worktree nasce fora do repositório, porque o worker recusa escrita ali dentro e a árvore interna deixaria o degrau sem como rodar |
| um worker levanta um finding | ele vira issue, e nunca some no report |


## 4. Camada de sessões

`no ar`

### Propósito

Tornar visível o worker que hoje trabalha às cegas, para que parado e trabalhando
deixem de ser a mesma coisa aos olhos de quem espera.

### Fluxo

Um worker despachado às cegas não tem nome nem estado visível, então worker
parado esperando resposta fica idêntico a worker trabalhando. A diferença só
aparece no prazo estourado, com a cota já gasta.

O modo visível resolve isso colocando o worker numa aba nomeada do multiplexer,
que o dono vê na lateral, e que a sessão consegue dirigir. É **opcional e
pedido**: sem a flag, nenhuma linha de código toca a ferramenta de terminal, e o
despacho é byte a byte o de antes.

Cinco verbos cobrem o ciclo da aba, e um adaptador único traduz verbo em comando,
de modo que trocar de multiplexer é reescrever o adaptador, não caçar o nome
espalhado.

| Verbo | O que faz |
|---|---|
| abrir | cria a aba com o nome do trabalho, sobe o worker interativo, devolve o painel |
| instruir | digita a instrução na sessão viva e espera ela voltar a parar |
| ler | devolve o que está na tela agora |
| assumir | foca o painel, e o dono continua a conversa sem trocar de processo |
| fechar | grava a tela em arquivo e só então fecha a aba |

| Arquivo | Papel |
|---|---|
| `scripts/herdr-adapter.sh` | único que nomeia a ferramenta; traduz verbo em comando |
| `scripts/abre-sessao.sh` | cria a aba, sobe o worker, responde as telas de abertura |
| `scripts/dirige-sessao.sh` | instruir, ler, processo, assumir |
| `scripts/fecha-sessao.sh` | fecha uma aba, ou varre as ociosas |
| `skills/delegate/scripts/lib-visivel.sh` | elegibilidade, registro, sincronização, prazo |

### Regras

| Quando | O produto garante |
|---|---|
| a aba nasce | ela leva o nome do trabalho, nunca um contador |
| a sessão está sendo dirigida | ela se distingue na lista por marca no rótulo, e o estado mora no rótulo e num registro em disco, nunca em metadado da ferramenta, que expira sozinho e apagaria justo a linha que precisa aparecer |
| uma aba fica parada além de 30 minutos | ela fecha sozinha, com a tela gravada antes; o prazo é dado da policy, em `visivel.ciclo`, e nenhum ponto de chamada escolhe duração |
| existe registro de sessão | o `--gc` do despachante chama a varredura, e só ele |
| o despachante de uma sessão morreu | a sessão órfã não fecha por prazo nenhum, fica na lista marcada e espera decisão de gente, porque worker vivo sem dono é o caso que precisa aparecer |
| a máquina não tem a ferramenta | o despacho comum completa sem perceber que a camada existe, e pedir o modo visível ali falha nomeando o que falta, em vez de cair calado no modo antigo |
| a instrução é longa | ela vai como texto digitado mais a tecla de envio, nunca pelo canal de prompt da ferramenta, que a entrega como conteúdo colado e faz o worker recusá-la como injeção |
| a sessão espera o worker | ela espera por consulta de estado, com prazo próprio, porque a espera embutida da ferramenta já pendurou além de dois minutos com o worker tendo respondido |
| a interface ainda está desenhando | a instrução que chega ali se perde, e duas leituras de tela iguais seguidas é o sinal de interface pronta |
| um grupo de projeto nasce | ele nasce com uma aba, que se reusa; fechar a última aba de um grupo fecha o grupo junto |
| uma aba fecha | a tela grava em arquivo antes, porque o que a aba devolve é o buffer e não um arquivo |


## 5. Memória e continuidade

`no ar`

### Propósito

Fazer o que importa atravessar o fim de uma sessão sem deixar passar junto o que
devia ter morrido com ela.

### Fluxo

Duas coisas atravessam o fim de uma sessão, e elas não se misturam. **Memória** é
fato durável sobre o dono, sobre como trabalhar e sobre recursos externos.
**Handoff** é estado transiente de trabalho em curso, que morre quando o trabalho
fecha.

Misturar os dois produz memória cheia de status obsoleto, que é pior que memória
vazia, porque o agente age com ela.

Memória é um arquivo por fato, com frontmatter, indexado num `MEMORY.md` que
carrega uma linha por memória, em quatro tipos: `user`, `feedback`, `project` e
`reference`. Handoff é um arquivo só, em `_tmp/`, gitignored.

### Regras

| Artefato | Prazo | O que acontece no fim |
|---|---|---|
| handoff | `Morre em:` em ISO, default 14 dias | absorve o que sobrou e apaga |
| item do `INBOX.md` | 30 dias | promove ou apaga |
| item do `## Pool` | 90 dias | promove ou apaga |
| `FEEDBACK.md` | teto de 10 entradas | o que virou norma promove ao doc permanente |

| Quando | O produto garante |
|---|---|
| um transiente nasce | ele carrega a data em que morre, escrita e não presumida; sem data nunca é apagado, e a regra de não acumular falhou dezenas de vezes antes de existir data, porque prosa não se executa |
| existe mais de um handoff vivo na mesma pasta | é achado: handoff substitui, não acumula |
| uma memória conflita com o `AGENTS.md` | corrige na hora, porque o arquivo tem precedência e memória velha que sobrevive vira instrução errada |
| um fato durável aparece num handoff | o handoff não escreve em memória, doc, PRD nem backlog: vira uma linha de link, e a lição se captura à parte |
| a memória cresce | ela não é versionada, porque é comportamento de agente, específico da máquina |


## 6. Docs vivos

`no ar`

### Propósito

Manter cada doc falando do presente e de um assunto só, para que ler um deles
baste e reler os outros não contradiga.

### Fluxo

Doc de estado descreve **o estado final**, o produto depois das specs em aberto,
e cada funcionalidade leva `no ar`, `previsto` ou `em aberto`, nesses termos ou nos
gêmeos em inglês (`live`, `planned`, `open`). Não existe prosa de "hoje"
contra "no alvo". O que foi decidido, tentado e descartado mora no git e no
`CHANGELOG.md`, que é onde histórico tem leitor. Cada assunto mora num doc só; a
régua completa é o [`docs/doc-standard.md`](docs/doc-standard.md).

A fronteira que mais escorrega é PRD contra CONVENTIONS, e se resolve pelo
assunto, não pelo público: a garantia de uma funcionalidade fica na seção dela, e
o CONVENTIONS guarda só o que vale pra qualquer tarefa.

| Doc | O que carrega |
|---|---|
| `README.md` | o que é, fluxo com tags, o único mapa de pastas e de docs |
| `PRD.md` | uma seção por funcionalidade, nos três atos: propósito, fluxo e regras |
| `CONVENTIONS.md` | só a regra universal de construção, até 150 linhas |
| `ROUTES.md` | fluxo e endereços |
| `DESIGN.md` | padrão visual |
| ADR em `docs/adrs/` | decisão cara de reverter, viva enquanto o `Status:` é vivo |

### Regras

| Quando | O produto garante |
|---|---|
| o texto é do README | ele descreve pra quem chega de fora, em terceira pessoa; o `AGENTS.md` manda em quem já está dentro, no imperativo, e bloco imperativo dentro do README é sinal de duplicação |
| uma linha entra no `AGENTS.md` | ela é failure-backed, porque linha marginal é líquido negativo medido: contexto escrito por humano melhora sucesso em 4% e custa 19% a mais, e gerado por modelo piora 3% custando 20% a mais |
| uma decisão é superada | ela sai da árvore pro `archive/` no mesmo commit que aceita a substituta, e citação de decisão que não está mais lá bloqueia |
| o PRD se parte em subdocs | cada subdoc carrega as duas direções do grafo: de quem depende, no topo, e quem depende dele, no fim |
| um doc de estado vira decision log | ele cresce sem fim e ninguém lê até o fim; o sinal é estrutural, não lexical, e é data em heading, não a palavra "histórico" no corpo |
| alguém risca um texto | é o pior dos três hábitos de log, porque mantém a versão velha na frente do leitor com uma marca que só o autor sabe ler |
| um decision log é cortado | a regra que ele carregava não some junto: vai pro doc que possui o assunto, no imperativo, sem a data e sem as alternativas descartadas |
| o gate roda | `check-docs.py --estado` cobra a tag por funcionalidade, e `--molde` cobra os três atos, o mapa, a árvore e o teto |


## 7. Enforcement

`no ar`

### Propósito

Tirar do agente a responsabilidade de lembrar: regra que importa vira máquina que
bloqueia, porque a que depende de memória não sobrevive à primeira sessão com
pressa.

### Fluxo

Toda regra que importa vira hook que bloqueia em runtime, lint que roda antes do
commit, ou assert na suíte. A mensagem de bloqueio diz o que fazer no lugar, e
todo hook tem kill switch por variável de ambiente, porque enforcement que não se
desliga vira obstáculo quando erra.

| Trava | O que impede | Kill switch |
|---|---|---|
| `read_size_guard` | leitura grande entrar inteira na janela | `READ_GUARD_DISABLED` |
| `bash_read_guard` | o mesmo despejo, agora via shell | `BASH_READ_GUARD_DISABLED` |
| `noop_flush_guard` | comando no-op usado como descarga de resultado | `NOOP_GUARD_DISABLED` |
| `claude_md_size_guard` | o arquivo de instrução passar do teto | `CLAUDE_MD_GUARD_DISABLED` |
| `memory_log_append` | escrita em memória sem registro | `MEMORY_HOOK_DISABLED` |
| `context7_reminder` | fixar assinatura de lib sem consultar a doc | `CONTEXT7_REMINDER_DISABLED` |

Os lints cobram o que hook nenhum alcança: `check-docs.py` (estado, molde, grafo,
ciclo, decaimento, estágio), `check-spec.py` (spec, tickets, corrente),
`check-skill.py`, `check-writing.py`, e `tests/agnostico.test.sh`, que bloqueia
nome de cliente num repo público.

### Regras

| Quando | O produto garante |
|---|---|
| um nome de cliente aparece em qualquer arquivo | ele não entra, nem em fixture de teste, porque o repositório é público; quem bloqueia é o `tests/agnostico.test.sh` |
| alguém vai commitar | a suíte verde é pré-condição, e ela hoje são 11 arquivos de teste com 848 asserts, sem rede e sem CLI real |
| nasce comportamento novo | ele nasce com teste, e bug ganha regressão antes da correção |
| um aceite pede para rodar à mão | vira script com assert, exceto o que só olho humano observa, que vira cenário escrito com veredito |
| um assert passa de primeira | ele pode ser vacuoso, e o RED se prova por mutação: três asserts desta base passavam porque o script morria antes, ou porque o fixture tornava a condição sempre verdadeira |
| a suíte é encadeada a um filtro de saída | ela informa sucesso mesmo vermelha, porque o rc que chega é o do filtro, e um commit desta base passou assim |
| um lint novo entra | ele roda contra o repo antes do commit, porque fixture e repo real divergem calados |
| um hook depende da topologia da máquina | ele fica no disco e não entra no template, porque nome de projeto, caminho de trabalho e histórico de incidente não são doutrina transferível |


## 8. Escrita

Fragmento ganha de frase inteira em instrução densa, e ortografia correta não se
negocia em nenhum dos dois. O linter pega o que é mecânico: travessão, aspa
curva, vocabulário de modelo, frase de enchimento, hedging empilhado, emoji
decorativo em título e densidade de exclamação. O julgamento fica na doutrina da
skill, e no linter só entra regra sem falso positivo.

Texto que outra pessoa vai ler passa pelo `check-writing.py` antes do commit.

## 9. Agnosticismo

O núcleo não depende de modelo nem de harness. O `AGENTS.md` é o arquivo do
padrão, e o ponteiro do harness é uma linha que aponta pra ele, nunca uma cópia.
As skills são doutrina em markdown, então servem de leitura pra qualquer agente;
o despacho por comando é da camada de um harness só.

Ramificação por modelo não entra em doc nenhum, porque apodrece antes da
arquitetura.

## Relacionado

- [`CONVENTIONS.md`](CONVENTIONS.md) consome deste doc a stack e as restrições,
  e carrega a regra universal de construção; o contrato de cada domínio fica aqui.
- [`AGENTS.md`](AGENTS.md) consome as restrições e o roteamento, no imperativo,
  pra quem já está dentro executando.
- [`README.md`](README.md) consome a visão geral e os pilares, em terceira
  pessoa, pra quem chega de fora decidir se adota.
