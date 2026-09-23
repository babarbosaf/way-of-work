# Padrão de documentos

Vale pra `AGENTS.md`/`CLAUDE.md`, `README.md`, PRD e seus subdocs, ROUTES, DESIGN,
CONVENTIONS, ADR, DDR, backlog e handoff. Carregam toda sessão ou são a primeira coisa
que alguém lê. Instrução viva, não changelog.

**Regra sem quem cobra não entra neste doc.** Prosa não se executa, e toda regra abaixo
nomeia o comando que a aplica:

| Regra | Quem cobra |
|---|---|
| Doc de estado descreve o estado final, com tags | `scripts/check-docs.py --estado <arquivo.md>` |
| Domínio do PRD se cita de volta | `scripts/check-docs.py --grafo <raiz>` |
| Decisão vive enquanto vigente | `scripts/check-docs.py --ciclo <raiz>` |
| Transiente tem prazo de validade | `scripts/check-docs.py --decay <raiz>` |
| Item vive em um estágio só | `scripts/check-docs.py --estagio <raiz>` |
| Corrente PRD, spec, ticket fechada | `scripts/check-spec.py --chain <raiz>` |
| Teto do `AGENTS.md` | `hooks/claude_md_size_guard.py` |
| Escrita sem slop | `skills/writing/scripts/check-writing.py` |

## Um tempo verbal, com duas tags

Doc de estado descreve **o estado final**: o produto como ele vai ser depois das specs
em aberto. Cada seção abre com uma tag, e numa seção mista a tag vai na linha:

- `no ar`: já funciona.
- `previsto`: entra com spec em aberto.

Não existe prosa de "hoje é assim, no alvo será assado". O leitor que quer saber o que
funciona agora filtra por `no ar`; o agente age só pelo que está `no ar`. Quando a spec
fecha, a tag vira `no ar` e nada mais muda no texto.

O que foi decidido, tentado e descartado mora no git e no `CHANGELOG.md`, que é onde
histórico tem leitor. Isso mata três hábitos: seção datada, seção de log e texto
riscado. Riscar é o pior dos três, porque mantém a versão velha na frente do leitor com
uma marca que só o autor sabe ler.

O sinal é **estrutural, não lexical**: data em heading, não a palavra "histórico" no
corpo. Buscar a palavra deu 21 ocorrências e 2 reais num PRD cujo domínio é dado
histórico.

**Deliberação morre no git; restrição sobrevive colhida.** Cortar o decision log não é
cortar a regra que ele carregava: a regra vai pro doc que possui o assunto, no
imperativo, sem a data e sem as alternativas descartadas.

## O grafo de domínios

Subdoc de PRD existe pra caber na cabeça de quem lê, não pra dividir texto. A garantia
de que dois subdocs não descrevem o mesmo assunto é **de grafo, não de rótulo**: duas
páginas que falam do mesmo tema sem se citar estão duplicando; se citam, uma delega
pra outra.

Cada subdoc carrega as duas direções, em lugares diferentes:

- o bloco `> **Papel deste doc.**` no topo lista **de quem ele depende** (upstream);
- a seção `## Relacionado` no fim lista **quem depende dele** (downstream), uma linha
  por vizinho dizendo o que aquele vizinho consome.

Sumidouro do grafo não tem `## Relacionado`, e isso é informação, não falta.

**Protocolo de um salto.** Revisar ou alterar um domínio carrega os vizinhos imediatos,
nunca o fecho transitivo: um salto cabe na janela, o fecho é o PRD inteiro de volta.

## Decisão: ADR e DDR

Decisão **não é log**. Ela vale enquanto o status é vivo (`proposta`, `aceita`,
`vigente`) e sai da árvore pro `archive/` quando é superada. O git guarda a
deliberação; a árvore guarda a regra em vigor.

O que impede o arquivo de crescer sem fim não é disciplina, é a saída: um DDR
substituído por outro some da pasta no mesmo commit que aceita o substituto. E o que
torna a remoção segura é o check do ponteiro: citação de decisão que não está mais lá
bloqueia.

## O backlog, cinco estágios

Um backlog só, organizado por **estágio de maturidade**, nunca por tipo. Melhoria de
código é trabalho igual a feature.

| Estágio | Onde vive | O que já existe |
|---|---|---|
| 0 capturado | `INBOX.md` | nada, é cru |
| 1 aceito | `TODOS.md` | uma linha: o que é |
| 2 contratado | `docs/specs/<slug>/spec.md` | contrato e dossiê |
| 3 endereçado | `docs/specs/<slug>/tickets/` | arquivos, aceite, verify |
| 4 entregue | some | virou PRD, código e `CHANGELOG.md` |

**Invariante de estágio único** (cobra: `scripts/check-docs.py --estagio <raiz>`)**:** todo item aparece em exatamente um estágio. Promover é
mover, nunca copiar, e item que virou spec sai do `TODOS.md` sem deixar ponteiro nem
linha riscada.

**Faixas de custo de entrada.** Captura é uma linha. Entrada no `TODOS.md` é uma linha
mais tipo e tamanho. O dossiê (fato, evidência, causa, consequência, proposta) só se
escreve no estágio 2, véspera de build. Fundir os estágios 1 e 2 é o gerador de lixo:
escrever 25 linhas de análise antes de alguém decidir que o item importa.

**Dentro do `TODOS.md`, dois blocos e nada mais:** `## Próximos`, ordenado, teto de 20,
onde a posição é a prioridade; e `## Pool`, não ordenado, que decai por data. Sem onda,
sem tema, sem campo de prioridade: cada eixo a mais de classificação é mais paralisia
na hora de escolher.

## O que morre, e quando

Transiente sem prazo nunca é apagado. A data se escreve, não se presume:

| Artefato | Prazo | O que acontece no fim |
|---|---|---|
| handoff em `_tmp/` | `Morre em:` em ISO, default 14 dias | absorve o que sobrou e apaga |
| item do `INBOX.md` | 30 dias | promove ou apaga |
| item do `## Pool` | 90 dias | promove ou apaga |
| `FEEDBACK.md` | teto de 10 entradas | o que virou norma promove ao doc permanente |

Handoff **substitui, não acumula**: dois vivos na mesma pasta é achado.

## Frontmatter

Carrega só o que a prosa não consegue dizer sobre si mesma, quer dizer, estado de ciclo
de vida e linhagem: `status:`, `prd:`, `harvest:`, `Morre em:`. Nunca um resumo do
próprio conteúdo, porque o resumo já está na primeira linha do corpo e a segunda cópia
diverge na primeira edição.

## A fronteira

**README descreve pra quem chega de fora. AGENTS.md manda em quem já está dentro.**

Teste por linha:
- *Isto muda o que o agente faz?* → AGENTS.md
- *Isto ajuda alguém a decidir se adota, ou a instalar e rodar?* → README

Marca gramatical, que é como se fiscaliza sem discutir caso a caso: README em terceira
pessoa ("o serviço expõe X"); AGENTS.md no imperativo ("rode X antes de commitar"). Bloco
imperativo dentro do README é sinal de duplicação.

## Teste de admissão do AGENTS.md

Toda linha precisa ser **failure-backed**: já vi o agente errar sem ela. Se não vi, não
entra. Se hook, lint ou CI já força, não entra: cita-se o comando de enforcement.

O estudo AGENTbench (ETH, fev/2026, 138 tarefas, 4 modelos) mediu arquivo de contexto
escrito por humano melhorando sucesso em 4% e custando 19% a mais; gerado por LLM, piora
de 3% custando 20% a mais. Só instrução de tooling não-óbvio teve efeito grande. Linha
marginal é líquido negativo, então o default é cortar.

## Cortar

| Categoria | Exemplo |
|---|---|
| Conselho genérico de engenharia | "escreva código limpo", "trate erros", "vá na causa raiz" |
| Coaching procedural | "pense passo a passo", "seja meticuloso" |
| Inventário de diretório | árvore de pastas que `ls` mostra |
| Stack e dependência | o que `package.json` ou `pyproject.toml` já diz |
| Comando padrão da ferramenta | `pytest` sem flag especial |
| Regra já enforçada por hook, lint ou CI | cita o comando de enforcement no lugar |
| Duplicata do README | overview de arquitetura, tour do repo, instalação |
| Assinatura de API e schema copiados do código | |
| Histórico | vai pra ADR, spec, `CHANGELOG.md`, FEEDBACK ou memória |
| Status volátil | vai pro `TODOS.md` ou pro tracker |
| Justificativa que não muda decisão | mantém a regra, corta a racionalização |
| Workaround já corrigido | senão o agente contorna problema que não existe mais |
| Ramificação por modelo | "se Opus faça X, se GPT faça Y" apodrece antes da arquitetura |

## Manter

Gotcha e failure mode; escolha local que **diverge** do default da linguagem ou
ferramenta; comando não-adivinhável (script próprio, flag obrigatória, setup de
ambiente); gate com consequência real; proibição crítica; etiqueta de repo (branch,
commit, PR); glossário de domínio; ponteiro pra doc que carrega o detalhe.

Na dúvida, mantém.

## Estrutura

1. **Cabeçalho:** 2 linhas: o que é, onde a doutrina longa mora.
2. **Invariantes:** sempre verdadeiro, sem gatilho. Fica no topo porque modelo atende
   pior ao meio do contexto longo.
3. **Roteamento:** tabela `gatilho → ação`. Um item por linha. Parágrafo corrido com
   várias regras separadas por ponto-e-vírgula é o pior formato: o modelo perde o item
   do meio.
4. **Ponteiros:** docs e skills.

Teto de 130 linhas, enforçado por `hooks/claude_md_size_guard.py`. Densidade importa mais
que a contagem.

## O ponteiro do CLAUDE.md

`AGENTS.md` é a fonte. Em projeto, o `CLAUDE.md` é um arquivo de uma linha só,
`@AGENTS.md`, nunca symlink nem cópia. Symlink não atravessa Windows, zip e
export, e no diff de PR aparece como blob de caminho. Cópia diverge no primeiro
commit que esquecer o par.

Custo: `@` é mecanismo do Claude Code. Harness que leia o `CLAUDE.md` literal vê
uma linha e nenhuma doutrina; quem precisa de portabilidade total edita o
`AGENTS.md`, que é o arquivo do padrão.

## Herança

Child AGENTS.md só escreve override próprio ou fato que só existe naquele projeto.
Repetir doutrina do `~/.claude/AGENTS.md` carrega duas vezes em toda sessão.

## Nomenclatura

Raiz em CAIXA-ALTA é doc único e estável. Instância (`spec-<slug>`, `adr-NNNN`) em
lowercase. Transiente vai pra `_tmp/`, gitignored.

Escopo se declara pelo que o projeto **É**, sem tabela de exclusão: a negativa que
importa vive na decisão que a produziu.
