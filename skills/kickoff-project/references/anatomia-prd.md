# Anatomia do PRD

Descreve a estrutura e o nível de profundidade do PRD-alvo. Há dois exemplos canônicos:
`exemplos/consumo/PRD.md` (Chutaí, produto de consumo) e `exemplos/operador/PRD.md`
(Prateleira, ferramenta de operador). Consultar por seção quando precisar ver o padrão na
prática, em vez de carregar o arquivo inteiro toda vez.

O PRD é o documento-raiz. As rotas, o design e as conventions se derivam dele.

## Conteúdo

- Regra de fronteira: um assunto, um lugar
- O que faz um PRD deste nível
- Esqueleto
- Convenções
- Quando o PRD vira vários
- Como usar o exemplo

## Regra de fronteira: um assunto, um lugar

**O que é de uma funcionalidade mora na seção dela no PRD, comportamento e contrato
juntos. O CONVENTIONS guarda só a regra universal de construção; o README, só o mapa.**
Separar por público (o que o usuário percebe, o que só o dev percebe) punha o mesmo
assunto em dois arquivos, e os dois divergiam.

- **Propósito:** para que a funcionalidade existe, em uma a três linhas.
- **Fluxo:** a caminhada por ela, com as bifurcações.
- **Regras:** o que o produto garante, em tabela, com o gatilho antes da claim (a
  notificação chega em até 1h, o corte é 0,8). Aqui também entram os nomes e formatos
  de que outra peça depende: a tabela, o evento, o campo, a pergunta do classificador.
- **Contrato grande no código.** DDL, JSON schema e exemplo de config moram no arquivo que
  o código lê (`migrations/`, `*.schema.json`), e a seção linka. Copiar código em doc é
  redundância que diverge. Antes do código existir, o contrato grande mora na spec.

## O que faz um PRD deste nível

Não é uma lista de features. Cada feature é arquitetada. O que diferencia:

- **Padrão de seção repetido.** Cada feature segue os três atos: propósito, fluxo,
  regras.
- **Caso de borda é regra, não apêndice.** Fluxo feliz é o mínimo, e o valor está no que
  anula, no que adia, no que empata e no que acontece no esquecimento. Cada um vira uma
  linha de **Regras** com o gatilho na frente, e não um bloco separado no fim: quem lê
  procura a condição dele, e ela precisa estar na mesma tabela.
- **Lacuna declarada onde ela morde.** O que ainda não foi decidido não vira bloco no fim
  da seção, que some da vista e apodrece sem dono nem prazo. Vira `a definir` na célula
  exata da tabela, onde quem for implementar esbarra, ou item no backlog, que decai. O
  `check-docs.py --estado` bloqueia a seção, e o padrão 35 do catálogo de escrita explica
  o porquê. **Isso vale inteiro para a seção:** funcionalidade cujo estado todo é `em
  aberto` não é seção deste doc. Ela é linha do `TODOS.md`, do `INBOX.md` ou de uma spec,
  e aqui aparece só nominalmente, na célula que ela trava. Seção com os três atos
  preenchidos de `a definir` é item de backlog vestido de PRD: engorda o doc e tira a
  lacuna da única fila que cobra dono e prazo.
- **Restrição no imperativo, nunca decisão logada.** A escolha difícil vira uma regra na
  seção que possui o assunto ("o número publicado mora na tabela"), no estado final, com a tag, sem data
  e sem as alternativas descartadas. O racional completo mora no ADR enquanto ele estiver
  vigente, e a deliberação mora no git. PRD que vira decision log cresce sem fim e
  ninguém lê até o fim.
- **Seções transversais.** Ao fim, as camadas que atravessam o produto (notificações,
  sincronização de dados, i18n), nos mesmos três atos. Só a regra que vale pra todo
  código vai pro CONVENTIONS.md (regra de fronteira acima).
- **Nível de leitura duplo.** Um PM que não lê código consegue seguir a prosa; um dev
  consegue executar a partir dela. Descrever arquitetura (tabelas, jobs, rotinas, cadências)
  conceitualmente, nomeando as peças, sem exigir que o leitor leia código.

## Esqueleto

```
# PRD: <Nome do produto>

> **Papel deste doc.** O que ele cobre, de quem depende, e a legenda das tags,
  uma vez só (a definição mora no `doc-standard.md`).

## 1. Visão geral
   Uma a duas frases do que é e para quem. Depois os 2 a 4 pilares de engajamento
   em lista, cada um com uma frase. Fecha com o diagrama único em ASCII: CAIXA ALTA
   para camada ou peça, minúscula para ação, o § de cada peça e a tag por etapa.

## 2..N. <Uma seção por feature / pilar>
   A tag (`no ar`, `parcialmente no ar`, `previsto`, `em aberto`; em inglês `live`,
   `partially live`, `planned`, `open`) marca a funcionalidade: na primeira
   linha, se a seção inteira está num estado (no título não, que é âncora); em cada
   item, se mistura. `em aberto` só marca item: seção inteira nesse estado não
   nasce aqui, nasce no `TODOS.md`. Padrão interno de cada seção:
   ### Propósito        -> para que a funcionalidade existe, em uma a três linhas
   ### Fluxo            -> a caminhada por ela, com as bifurcações; ciclo de vida em ASCII
   ### Regras           -> o que o produto garante, em tabela: o número exato, o formato
                           de que outra peça depende, o caso fora do fluxo feliz e a
                           restrição inviolável. Cada regra diz o gatilho antes da claim

## <Seções transversais>
   Notificações, Dados e sincronização, Internacionalização, Admin. Mesmo padrão: os
   três atos na seção. Regra que vale para todo código (stack, estilo,
   performance obrigatória) não ganha seção: vive no CONVENTIONS.md.
```

A numeração é contínua. As seções transversais entram como seções numeradas ao fim.

O PRD não tem seção de restrições, backlog, referências, métricas nem riscos: cada uma
tem destino no `doc-standard.md` ("Um assunto, um lugar"), e o `check-docs.py --molde`
acusa. O consumidor do produto (agente, sistema, integração) aparece pelo contrato que
consome, nunca descrito por dentro.

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

Ao escrever uma seção nova, abrir a seção equivalente de um dos exemplos e reproduzir o
nível de detalhe, não o conteúdo. O que se copia é a disciplina: propósito, fluxo, regras
e a tag em cada funcionalidade.

Os dois padrões-ouro cobrem formatos diferentes, e escolher pelo formato é mais útil que
escolher pelo assunto:

| Exemplo | Produto | O que ele ensina melhor |
|---|---|---|
| `exemplos/consumo/PRD.md` | Chutaí, um bolão de futebol | régua numérica em tabela, economia de engajamento, muitas funcionalidades independentes |
| `exemplos/operador/PRD.md` | Prateleira, extensão de comprador dentro do portal de um terceiro | fila sem vigilância, caminho de escrita que espera pessoa, restrição que nasce de credencial de terceiro, lacuna citada na célula em vez de virar seção |

Os dois produtos são inventados. Exemplo é onde nome real de cliente entra sem ninguém
notar, e este repo é público: quando o molde vier de um trabalho real, o domínio se troca
inteiro, não só os nomes. A forma da operação identifica sozinha.
