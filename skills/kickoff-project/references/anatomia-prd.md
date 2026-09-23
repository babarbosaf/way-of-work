# Anatomia do PRD

Descreve a estrutura e o nível de profundidade do PRD-alvo. O exemplo canônico completo
está em `exemplos/PRD.md` (Chutaí). Consultar o exemplo por seção quando precisar ver o
padrão na prática, em vez de carregar o arquivo inteiro toda vez.

O PRD é o documento-raiz. As rotas, o design e as conventions se derivam dele.

## Regra de fronteira: um assunto, um lugar

**O que é de uma funcionalidade mora na seção dela no PRD, comportamento e contrato
juntos. O CONVENTIONS guarda só a regra universal de construção; o README, só o mapa.**
Separar por público (o que o usuário percebe, o que só o dev percebe) punha o mesmo
assunto em dois arquivos, e os dois divergiam.

- **Comportamento:** o que acontece, com números em tabela (a notificação chega em até
  1h, o corte é 0,8).
- **Contrato:** os nomes e formatos que outra peça depende (a tabela, o evento, o campo, a
  pergunta do classificador), curto.
- **Contrato grande no código.** DDL, JSON schema e exemplo de config moram no arquivo que
  o código lê (`migrations/`, `*.schema.json`), e a seção linka. Copiar código em doc é
  redundância que diverge. Antes do código existir, o contrato grande mora na spec.

## O que faz um PRD deste nível

Não é uma lista de features. Cada feature é arquitetada. O que diferencia:

- **Padrão de seção repetido.** Cada feature segue: modelo conceitual, depois estrutura,
  depois as regras em tabela, depois edge cases explícitos.
- **Edge cases por feature.** Fluxo feliz é o mínimo. O valor está nos casos de borda
  listados: o que anula, o que adia, o que empata, o que acontece no esquecimento.
- **Lacuna declarada onde ela morde.** O que ainda não foi decidido não vira bloco no fim
  da seção, que some da vista e apodrece sem dono nem prazo. Vira `a definir` na célula
  exata da tabela, onde quem for implementar esbarra, ou item no backlog, que decai. O
  `check-docs.py --estado` bloqueia a seção, e o padrão 35 do catálogo de escrita explica
  o porquê.
- **Restrição no imperativo, nunca decisão logada.** A escolha difícil vira uma regra na
  seção que possui o assunto ("o número publicado mora na tabela"), no estado final, com a tag `no ar` ou `previsto`, sem data
  e sem as alternativas descartadas. O racional completo mora no ADR enquanto ele estiver
  vigente, e a deliberação mora no git. PRD que vira decision log cresce sem fim e
  ninguém lê até o fim.
- **Seções transversais.** Ao fim, as camadas que atravessam o produto (notificações,
  sincronização de dados, i18n) descritas em nível de comportamento: o que o usuário vê,
  quais eventos existem, o que é ou não coberto. O detalhamento de arquitetura de cada uma
  vive no CONVENTIONS.md, linkado ao fim da seção (regra de fronteira acima).
- **Nível de leitura duplo.** Um PM que não lê código consegue seguir a prosa; um dev
  consegue executar a partir dela. Descrever arquitetura (tabelas, jobs, rotinas, cadências)
  conceitualmente, nomeando as peças, sem exigir que o leitor leia código.

## Esqueleto

```
# PRD: <Nome do produto>

## 1. Visão geral
   Uma a duas frases do que é e para quem. Depois os 2 a 4 pilares de engajamento
   em lista, cada um com uma frase.

## 2..N. <Uma seção por feature / pilar>
   Padrão interno de cada seção, que abre com a tag `no ar` ou `previsto`:
   ### Comportamento    -> como funciona, com números exatos em tabela
   ### Contrato         -> nomes e formatos de que outra peça depende; o grande, linkado
   ### Edge cases       -> casos fora do fluxo feliz

## <Restrições invioláveis>
   Regras, requisitos e limitações capturados na Fase 0 que não podem ser quebrados
   nem ultrapassados. Uma linha por restrição, com o racional quando houver.

## <Seções transversais>
   Notificações, Dados e sincronização, Internacionalização, Admin. Mesmo padrão:
   comportamento e contrato na seção. Regra que vale para todo código (stack, estilo,
   performance obrigatória) não ganha seção: vive no CONVENTIONS.md.
```

A numeração é contínua. As seções transversais entram como seções numeradas ao fim.

## Convenções

- **Tabelas para toda regra numérica.** Pontuação, multiplicadores, janelas de tempo,
  limites, cadências de sync. Nunca deixar número solto no meio da prosa quando cabe tabela.
- **Referenciar rotas por path** (`/palpites/jogos/:id`), mesmo antes do documento de rotas
  existir. Isso amarra PRD e rotas.
- **O que saiu, saiu.** Feature removida some do PRD, sem nota de escopo e sem data: o
  que aconteceu está no `CHANGELOG.md` e no git. Data em heading é achado do
  `check-docs.py --estado`.
- **Blockquotes para contexto factual** que ajuda a entender uma regra (ex.: por que a Copa
  2026 tem uma fase a mais).

## Quando o PRD vira vários

Um domínio ganha arquivo próprio em `docs/prd/<dominio>.md` quando a seção dele não cabe
mais na cabeça de quem lê. O `PRD.md` continua sendo o índice e a visão de conjunto, com
uma linha por domínio apontando pro subdoc.

Cada subdoc carrega as duas direções do grafo:

- topo, `> **Papel deste doc.**`: o que ele cobre e **de quem ele depende**;
- fim, `## Relacionado`: **quem depende dele**, uma linha por vizinho dizendo o que
  aquele vizinho consome daqui.

É o que prova que dois subdocs não descrevem o mesmo assunto: se falam do mesmo tema e
não se citam, estão duplicando. O `check-docs.py --grafo <raiz>` cobra link que resolve,
âncora viva, subdoc no índice e aresta recíproca.

Revisar um domínio carrega os vizinhos imediatos, e só eles: um salto cabe na janela, o
fecho transitivo é o PRD inteiro de volta.

## Como usar o exemplo

`exemplos/PRD.md` é o padrão-ouro. Ao escrever uma seção nova, abrir a seção equivalente
do exemplo e reproduzir o nível de detalhe, não o conteúdo. O exemplo é de um bolão de
futebol; o produto em mãos pode ser qualquer coisa. O que se copia é a disciplina:
modelo, estrutura, tabela de regras e edge cases.
