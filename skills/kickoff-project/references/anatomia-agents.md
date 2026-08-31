# Anatomia do CLAUDE.md, do AGENTS.md e do FEEDBACK.md

Esta é a camada operacional da fundação, em três arquivos. Enquanto PRD, rotas, design e
conventions descrevem o produto e como construí-lo, estes instruem os agentes de código
que vão trabalhar no projeto. São escritos por último, depois dos quatro documentos,
porque referenciam todos eles. Os três precisam viver na raiz do projeto, senão os
agentes não os carregam.

## Conteúdo

- CLAUDE.md
- AGENTS.md
- FEEDBACK.md
- AAAA-MM-DD: <resumo curto>
- Convenções

## CLAUDE.md

Mínimo por desenho. Não duplica conteúdo: apenas aponta para o AGENTS.md, que é a fonte
única de instruções operacionais.

Conteúdo:

```
# <Nome do produto>

As instruções deste projeto vivem em AGENTS.md. Leia-o antes de qualquer trabalho.

@AGENTS.md
```

## AGENTS.md

A fonte única de instruções operacionais do projeto. Cinco seções obrigatórias, nesta ordem:

### 1. Documentos de referência

Apresentar os quatro documentos da fundação e o papel de cada um:

- `PRD.md`: fonte de verdade do produto. Features, regras, edge cases e decisões.
  Consultar a seção correspondente antes de implementar qualquer funcionalidade.
- `ROUTES.md`: mapa de telas e navegação condicional. Consultar ao criar ou alterar
  telas e fluxos.
- `DESIGN.md`: design system. Tokens, patterns e guarda-corpos. Consultar antes de
  escrever qualquer UI.
- `CONVENTIONS.md`: como se constrói. Stack, padrões de arquitetura, regras obrigatórias
  de implementação. Consultar antes de escrever qualquer código.

Fechar com a instrução: nenhuma feature se implementa sem ler a seção correspondente do
PRD; nenhuma tela se cria sem conferir ROUTES.md e DESIGN.md; nenhum código se escreve
fora dos padrões do CONVENTIONS.md.

### 2. Restrições invioláveis

Ecoar aqui as restrições capturadas na Fase 0 da entrevista (e registradas no PRD):
regras, requisitos e limitações que não podem ser quebrados ou ultrapassados em nenhuma
circunstância. Uma linha por restrição. Incluir a instrução: se uma tarefa pedida
conflitar com uma restrição desta lista, o agente para e aponta o conflito em vez de
executar.

### 3. Execução

A disciplina de construção que vale em qualquer tarefa do projeto:

- **Testes (3 regras):** comportamento novo nasce com teste (RED antes do código, GREEN
  mínimo, REFACTOR mantendo verde); todo bug ganha teste de regressão antes da correção,
  e o debug para na causa raiz, não no sintoma; suite verde é pré-condição de commit.
- **YAGNI:** abstração só na 3ª repetição; zero feature especulativa; antes de escrever
  helper, procurar função existente; evoluir artefato existente antes de criar paralelo.
- **Feature grande** (várias sessões, muitos arquivos, toca contrato ou prod): escrever
  antes uma spec curta em `docs/specs/<slug>/spec.md` (contrato), e fatiá-la em tickets
  antes do build. Ao shippar, a verdade funcional vai para o PRD; a spec é descartável.
- **Componente ou tela visual novo, ou redesenho:** rodar o `design-workflow` (busca na
  base canônica de design antes de codar). Se a casa não mantém base canônica, consultar
  o DESIGN.md e seguir seus patterns.

### 4. Registro de feedbacks

A regra que evita reincidência:

- Todo feedback corretivo do usuário (algo que o agente fez e não deveria, ou deveria
  ter feito diferente) é registrado em `FEEDBACK.md`, com data, contexto em uma linha e
  a instrução acionável que evita a repetição.
- O AGENTS.md importa o arquivo via `@FEEDBACK.md`, logo abaixo desta seção. Assim os
  feedbacks entram no contexto de toda sessão automaticamente, sem depender de o agente
  lembrar de ler.
- Os itens têm força de regra: um erro registrado não pode se repetir.
- FEEDBACK.md é buffer, não arquivo morto: respeitar o teto e a regra de promoção do
  cabeçalho do próprio arquivo.

### 5. Documentos vivos

Toda vez que uma decisão nova for tomada durante o desenvolvimento, o agente pergunta ao
usuário se deve atualizar o documento correspondente, mantendo a fundação sempre como
fonte de verdade:

- Decisão de produto (uma regra mudou, um escopo entrou ou saiu, um número foi definido,
  um ponto em aberto foi fechado): atualizar o `PRD.md`, com nota de escopo datada quando
  substituir decisão anterior (ver `anatomia-prd.md`).
- Tela ou fluxo de navegação criado, alterado ou removido: atualizar o `ROUTES.md`.
- Token, pattern ou regra visual que mudou no código: atualizar o `DESIGN.md`. É a regra
  "o código vence" do próprio design system: o doc se atualiza no mesmo PR que muda o
  código.
- Padrão de implementação novo, stack alterada ou regra técnica obrigatória: atualizar o
  `CONVENTIONS.md`. Decisão técnica cara de reverter (schema, contrato público, escolha
  de plataforma) merece um ADR em `docs/adrs/`, indexado no CONVENTIONS.md.

## FEEDBACK.md

Entregue já no kickoff, como scaffold, para que o formato fique padronizado desde o
primeiro registro e o import `@FEEDBACK.md` do AGENTS.md nunca aponte para arquivo
inexistente. O molde com entradas de exemplo é o `FEEDBACK.example.md` da raiz do
way-of-work. Conteúdo inicial:

```
# Feedbacks

Registro de feedbacks corretivos do usuário. Cada item tem força de regra: um erro
registrado aqui não pode se repetir.

Este arquivo é buffer, não arquivo morto. Teto: 10 entradas. Entrada que se repetiu ou
virou norma é promovida ao doc permanente (AGENTS.md se é instrução de agente,
CONVENTIONS.md se é regra de código, PRD.md/DESIGN.md se é produto) e apagada daqui.
Entrada obsoleta morre na compactação. Estourou o teto: compactar, não relaxar.

Formato de cada entrada:

## AAAA-MM-DD: <resumo curto>
Contexto: <o que aconteceu, em uma linha>
Instrução: <a regra acionável que evita a repetição>
```

## Convenções

- Português por padrão (acompanhando o idioma do usuário) e nível de leitura duplo,
  como nos demais documentos.
- AGENTS.md é curto e imperativo. Não repetir o conteúdo do PRD, das rotas, do design ou
  das conventions: apontar para eles.
