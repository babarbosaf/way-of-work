# kickoff-project

Skill de Claude (Claude Code e claude.ai) que cria a fundação documental de um projeto novo de produto ou software. Em vez de escrever documentos de primeira, ela conduz uma entrevista dirigida com o dono do projeto, extrai a profundidade necessária e só então redige, em cadeia, os oito arquivos que fundam o projeto e evitam refação.

Fork do [iagodemacedo/kickoff-project](https://github.com/iagodemacedo/kickoff-project), adaptado ao way-of-work da Maracajá Labs: cascata com CONVENTIONS.md (cisão PRD × conventions), FEEDBACK.md com teto e promoção, seção de execução (TDD/YAGNI) no AGENTS.md gerado, STRATEGY.md opt-in e stack default da casa.

## O que ela entrega

| Arquivo | Papel |
|---|---|
| `PRD.md` | Especificação do produto. Cada feature arquitetada com modelo, estrutura, regras em tabela, edge cases e pontos a definir. Inclui restrições invioláveis e decisões estratégicas registradas com racional. |
| `ROUTES.md` | Mapa completo de telas e navegação, agrupado por estado de acesso, com a lógica condicional de cada rota. |
| `DESIGN.md` | Design system: identidade, tokens exatos, patterns de componente com código e guarda-corpos anti-slop (checklist e lista negra). |
| `CONVENTIONS.md` | Como se constrói: stack, regras do projeto, padrões de arquitetura por camada, processo e índice de ADRs. |
| `CLAUDE.md` | Arquivo mínimo que aponta para o `AGENTS.md`. |
| `AGENTS.md` | Instruções operacionais para os agentes de código que trabalharão no projeto. |
| `FEEDBACK.md` | Scaffold do registro de feedbacks corretivos, importado pelo `AGENTS.md`, com teto e regra de promoção. |
| `TODOS.md` | Fila de achados e pendências do projeto. Nasce vazio. |

(Mais `STRATEGY.md`, se o dono optar na entrevista.)

Os quatro primeiros descrevem o produto e como construí-lo. Os demais formam a camada operacional: garantem que qualquer agente de código que entre no projeto leia a fundação, respeite as restrições, não repita erros já apontados e mantenha os documentos vivos.

## Como funciona

O fluxo é encadeado: cada documento se apoia no anterior.

1. **Entrevista.** O motor da skill. Conduzida em fases (enquadramento e stack, pilares de engajamento, deep-dive por feature, camadas transversais, decisões estratégicas), com no máximo 1 a 3 perguntas por vez. A Fase 0 também captura as restrições invioláveis, as convenções de construção que o dono já pratica, se a estratégia merece doc próprio e se existe fundação de design para herdar. As respostas são persistidas incrementalmente em `_tmp/notas-entrevista.md`, então a entrevista sobrevive a quedas de sessão.
2. **PRD.** Redigido a partir das notas da entrevista, seguindo um padrão de seção repetido: modelo conceitual, estrutura, regras exatas em tabela, edge cases e pontos a definir, feature por feature. Regra de fronteira: o que o usuário percebe é PRD; o que só o dev percebe vai para o CONVENTIONS.md, linkado.
3. **Rotas.** Derivadas do PRD: cada feature implica telas, cada estado implica uma rota. Inclui a lógica condicional de navegação em cada descrição.
4. **Design.** Derivado das telas que as rotas definiram. Se o usuário apontou um design system existente na entrevista, ele vira a base do `DESIGN.md` sem perda de informação.
5. **Conventions.** Consolida a camada técnica: stack confirmada, convenções capturadas na entrevista e o detalhamento de arquitetura das seções transversais do PRD.
6. **Camada operacional.** `CLAUDE.md`, `AGENTS.md`, o scaffold de `FEEDBACK.md` e o `TODOS.md`.
7. **Entrega.** Os arquivos são salvos na raiz do projeto, onde os agentes de código de fato os carregam.

## A camada operacional em detalhe

O `AGENTS.md` tem cinco seções obrigatórias:

1. **Documentos de referência.** Nenhuma feature se implementa sem ler a seção correspondente do PRD; nenhuma tela se cria sem conferir `ROUTES.md` e `DESIGN.md`; nenhum código se escreve fora dos padrões do `CONVENTIONS.md`.
2. **Restrições invioláveis.** Ecoadas da entrevista. Se uma tarefa conflitar com uma restrição, o agente para e aponta o conflito em vez de executar.
3. **Execução.** TDD (3 regras), YAGNI, spec curta para feature grande, design-workflow para componente visual novo.
4. **Registro de feedbacks.** Todo feedback corretivo do usuário entra em `FEEDBACK.md` com data, contexto e instrução acionável. O `AGENTS.md` importa o arquivo via `@FEEDBACK.md`, então os feedbacks entram no contexto de toda sessão automaticamente, e um erro registrado não pode se repetir. O arquivo é buffer com teto: entrada que virou norma é promovida ao doc permanente e apagada.
5. **Documentos vivos.** A cada decisão nova durante o desenvolvimento, o agente pergunta se deve atualizar o documento correspondente: decisão de produto atualiza o `PRD.md`, tela ou fluxo novo atualiza o `ROUTES.md`, mudança de token ou pattern atualiza o `DESIGN.md`, padrão técnico novo atualiza o `CONVENTIONS.md` (e decisão cara de reverter vira ADR).

## Estrutura do repositório

```
kickoff-project/
├── SKILL.md                          # Instruções principais da skill
└── references/
    ├── metodo-entrevista.md          # O protocolo de entrevista, fase a fase
    ├── anatomia-prd.md               # Estrutura e convenções do PRD
    ├── anatomia-rotas.md             # Estrutura do documento de rotas
    ├── anatomia-design.md            # Estrutura do design system
    ├── anatomia-conventions.md       # Estrutura do CONVENTIONS.md e a regra de fronteira
    ├── anatomia-agents.md            # Estrutura do CLAUDE.md, AGENTS.md e FEEDBACK.md
    ├── stack-default.md              # A stack padrão da casa e como adaptar ao trocar
    └── exemplos/
        ├── PRD.md                    # Padrão-ouro de PRD (projeto Chutaí)
        ├── ROUTES.md                 # Padrão-ouro de rotas
        ├── DESIGN.md                 # Padrão-ouro de design system
        └── CONVENTIONS.md            # Padrão-ouro de conventions (cisão do PRD Chutaí)
```

Os exemplos do projeto Chutaí (um bolão de futebol) servem de régua de profundidade: a skill reproduz o nível de detalhe e a disciplina de estrutura deles, nunca o conteúdo.

## Uso

Invocar diretamente:

```
/kickoff-project
```

Ou pedir em linguagem natural: "quero estruturar um projeto novo", "monta o PRD desse produto", "kickoff", "blueprint", "fundação do projeto". Por padrão a skill entrega os oito arquivos; para pular algum, basta pedir.

## Princípios

- **Entrevistar antes de escrever.** A profundidade vem das respostas, não de suposição.
- **Fluxo encadeado.** PRD, depois rotas, depois design, depois conventions, um de cada vez, na ordem.
- **Fronteira PRD × CONVENTIONS.** O que o usuário percebe é PRD; o que só o dev percebe é CONVENTIONS.
- **Nível de leitura duplo.** Um PM que não lê código segue a prosa; um dev executa a partir dela.
- **Português por padrão**, acompanhando o idioma do usuário.
