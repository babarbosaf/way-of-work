---
name: kickoff-project
description: Cria a fundação documental de um projeto novo de produto ou software por meio de uma entrevista dirigida, produzindo quatro documentos encadeados no padrão-ouro. PRD (especificação com features arquitetadas, regras em tabela, edge cases, pontos a definir e decisões estratégicas registradas), documento de rotas (mapa completo de telas e navegação condicional), design system (identidade, tokens exatos, patterns de componente e guarda-corpos anti-slop) e conventions (stack, padrões de arquitetura e de código, regras obrigatórias de implementação). Fecha com CLAUDE.md e AGENTS.md, que amarram os documentos às regras operacionais dos agentes: feedbacks registrados em FEEDBACK.md, PRD sempre atualizado a cada decisão de produto e restrições invioláveis. Usar quando o usuário quer começar ou estruturar um projeto novo, montar o PRD, as rotas, o design ou as convenções de um produto, ou pedir "kickoff", "blueprint", "fundação do projeto", "planta do projeto", "documentação base" ou "especificação de produto". Por padrão entrega os oito arquivos; pula algum só se for pedido.
---

# Kickoff de Projeto

## Visão geral

Esta skill transforma uma ideia de produto na sua planta baixa: quatro documentos que
fundam o projeto e evitam refação. Ela não escreve os documentos de cachaço. Ela primeiro
entrevista o dono do projeto com perguntas dirigidas, extrai a profundidade necessária, e
só então redige, em cadeia: o PRD nasce da entrevista, as rotas caem do PRD, o design se
apoia nas telas que as rotas definiram, e as conventions consolidam a camada técnica que a
entrevista e o PRD revelaram. Por fim, fecha a camada operacional: um CLAUDE.md que aponta
para o AGENTS.md, e um AGENTS.md que amarra os quatro documentos às regras de trabalho dos
agentes (restrições invioláveis, registro de feedbacks, documentos sempre atualizados).

A régua de profundidade é o projeto Chutaí, cujos documentos completos vivem em
`references/exemplos/`. O que se reproduz é o nível de detalhe e a disciplina de estrutura,
nunca o conteúdo (o produto em mãos pode ser qualquer coisa).

## Princípios inegociáveis

- **Entrevistar antes de escrever.** Nunca produzir um documento sem antes conduzir a
  entrevista. A profundidade vem das respostas, não de suposição.
- **Fluxo encadeado:** PRD, depois rotas, depois design, depois conventions. Cada documento
  se apoia no anterior. Produzir um de cada vez, na ordem. Não é preciso um portão formal de
  aprovação entre eles, mas cada documento é entregue antes de começar o próximo, o que abre
  espaço natural para correção.
- **Fronteira PRD × CONVENTIONS:** o que o usuário percebe é PRD; o que só o dev percebe é
  CONVENTIONS. Onde o PRD encostar em técnica, vira link para a seção correspondente do
  CONVENTIONS.md, nunca duplicação.
- **Entrega padrão são os quatro documentos mais CLAUDE.md, AGENTS.md, o scaffold de
  FEEDBACK.md e um TODOS.md vazio.** Só pular algum se o usuário pedir explicitamente.
- **Português por padrão**, acompanhando o idioma do usuário.
- **Docs de raiz em CAIXA-ALTA.** `PRD.md`, `ROUTES.md`, `DESIGN.md`, `CONVENTIONS.md`,
  `FEEDBACK.md`, `TODOS.md` (exceções: `AGENTS.md`/`CLAUDE.md` já são convenção de
  ferramenta). Caixa alta sinaliza papel de raiz: doc único e estável do repo.
- **Nível de leitura duplo.** Escrever de modo que um PM que não lê código siga a prosa e um
  dev execute a partir dela. Descrever arquitetura nomeando as peças, conceitualmente.

## Fluxo de trabalho

### Passo 1: Entrevista

Ler `references/metodo-entrevista.md` e conduzir a entrevista. Ela cobre, em fases:
enquadramento e stack, pilares de engajamento, deep-dive por feature (modelo, estrutura,
regras exatas, edge cases, pontos a definir), camadas transversais (dados e sync,
notificações, performance, i18n, admin) e decisões estratégicas.

Disciplina: um bloco de tema por mensagem, no máximo 1 a 3 perguntas por vez, forçar
especificidade (números, tabelas, cadências), devolver um mini-resumo ao fechar cada bloco.
Não despejar todas as perguntas de uma vez.

Persistir o material: ao fechar cada bloco, gravar o mini-resumo e as respostas em
`_tmp/notas-entrevista.md` (diretório gitignored de trabalho; criar se não existir). Se a
sessão cair ou o contexto se perder, a entrevista retoma do arquivo, e o PRD se redige a
partir dele, não da memória.

Na Fase 0, confirmar a stack: manter o default declarado (`references/stack-default.md`) ou
trocar. A escolha muda o conteúdo das seções transversais de arquitetura, não a profundidade.
Ainda na Fase 0:

- Capturar as restrições invioláveis do projeto (regras, requisitos ou limitações que não
  podem ser quebrados).
- Perguntar se a visão/direção do negócio merece documento próprio. Se sim, gerar um
  `STRATEGY.md` curto (por que o produto existe, apostas, norte) antes do PRD; se não, o
  racional estratégico vive na seção de decisões do PRD. STRATEGY é opt-in, não default.
- Perguntar se já existe um design system ou fundação de design já existente para herdar (design
  system de umbrella, kit de componentes, DESIGN.md de outro produto). Se existir, o usuário
  aponta o arquivo, que vira a base do DESIGN.md sem perda de informação: o documento gerado
  declara a fonte e registra só os desvios.
- Na confirmação de stack, capturar também as convenções de construção: estrutura de pastas,
  padrões de nomenclatura, regras de teste, padrões de erro e o que mais o dono já pratica.
  Esse material alimenta o CONVENTIONS.md no Passo 5.

### Passo 2: PRD

Ler `references/anatomia-prd.md` e escrever o PRD a partir do material da entrevista.
Consultar a seção equivalente de `references/exemplos/PRD.md` para calibrar o nível de
detalhe de cada seção (abrir por seção, não carregar o arquivo inteiro de uma vez).

Garantir os diferenciais: padrão de seção repetido (modelo, estrutura, regras em tabela,
edge cases, pontos a definir), a seção de decisões estratégicas registradas com racional, e
as seções transversais em nível de comportamento. O detalhamento técnico delas nasce aqui
na conversa, mas o texto final aponta para o CONVENTIONS.md (regra de fronteira na
anatomia). Guardar o material técnico levantado para o Passo 5.

### Passo 3: Rotas

Ler `references/anatomia-rotas.md`. Derivar o mapa de telas do PRD, feature por feature,
agrupando por estado de acesso (pré-auth, pós-auth com navegação principal, públicas, camada
global) e escrevendo a lógica condicional de navegação em cada descrição. Calibrar por
`references/exemplos/ROUTES.md`.

### Passo 4: Design

Ler `references/anatomia-design.md`. Rodar a entrevista de design curta (vibe references,
dial values, modo de cor, stack visual), identificar os patterns de componente que as telas
exigem, e escrever o design system: identidade, tokens exatos, patterns com código, e as
duas listas de guarda-corpo (anti-slop checklist e lista negra). Calibrar por
`references/exemplos/DESIGN.md`. Para a stack visual default, ver `references/stack-default.md`.

Se o usuário apontou um design system existente na Fase 0, lê-lo por inteiro antes de
escrever: ele é a base do DESIGN.md e nenhuma informação dele pode ser perdida (ver a seção
"Quando já existe um design system" em `references/anatomia-design.md`). A entrevista de
design curta se reduz ao que o arquivo não cobre.

### Passo 5: Conventions

Ler `references/anatomia-conventions.md` e escrever o CONVENTIONS.md consolidando a camada
técnica: a stack confirmada na Fase 0, as convenções de construção capturadas na entrevista
e o detalhamento de arquitetura das seções transversais do PRD (dados e sync, notificações,
i18n, performance). Calibrar por `references/exemplos/CONVENTIONS.md`.

Se o projeto vive num umbrella com um CONVENTIONS.md compartilhado (modelo de trabalho da
casa), o documento gerado abre declarando que o estende, e registra só o que é específico
do projeto: stack, padrões e regras locais.

### Passo 6: CLAUDE.md e AGENTS.md

Ler `references/anatomia-agents.md` e escrever os três arquivos: o CLAUDE.md mínimo, que
só aponta para o AGENTS.md; o AGENTS.md com as cinco seções obrigatórias (documentos de
referência PRD.md, ROUTES.md, DESIGN.md e CONVENTIONS.md; restrições invioláveis; execução;
registro de feedbacks; documentos vivos, com o agente perguntando antes de atualizar PRD,
rotas, design ou conventions); e o scaffold de `FEEDBACK.md`, que o AGENTS.md importa via
`@FEEDBACK.md` e que carrega no cabeçalho a regra de teto e promoção.

### Passo 7: Entrega

Salvar os arquivos na raiz do projeto atual: `PRD.md`, `ROUTES.md`, `DESIGN.md`,
`CONVENTIONS.md`, `CLAUDE.md`, `AGENTS.md`, `FEEDBACK.md` e `TODOS.md` (mais `STRATEGY.md`
se foi opt-in na Fase 0). CLAUDE.md, AGENTS.md e FEEDBACK.md precisam estar na raiz, senão
os agentes não os carregam. Se não houver um diretório de projeto claro, perguntar o destino
antes de salvar. Quando a skill rodar no claude.ai (sem projeto local), salvar em
`/mnt/user-data/outputs/`.

`_tmp/notas-entrevista.md` é material de trabalho, não entregável: fica no `_tmp/`
(gitignored), fora do repo. Se o usuário pediu para pular algum documento, não gerar aquele.

## Recursos

- `references/metodo-entrevista.md`: o protocolo de entrevista, fase a fase.
- `references/anatomia-prd.md`: estrutura e convenções do PRD.
- `references/anatomia-rotas.md`: estrutura do documento de rotas e como derivá-lo do PRD.
- `references/anatomia-design.md`: estrutura do design system e como derivá-lo das rotas.
- `references/anatomia-conventions.md`: estrutura do CONVENTIONS.md e a regra de fronteira
  com o PRD.
- `references/anatomia-agents.md`: estrutura do CLAUDE.md, do AGENTS.md e do FEEDBACK.md,
  e as regras operacionais que eles carregam.
- `references/stack-default.md`: o molde da stack default e como adaptar ao trocar.
- `references/exemplos/{PRD,ROUTES,DESIGN,CONVENTIONS}.md`: o padrão-ouro do Chutaí, a
  régua de profundidade. Consultar por seção.
