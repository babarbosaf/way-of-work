# way-of-working — as cadeias

O `project-template/` é a planta; este doc é a legenda. Um scaffold de docs sem
saber como as peças se conectam vira formulário morto. Aqui estão as cadeias que
tornam o modelo transferível — o "trabalhar como eu trabalho" escrito.

Sete cadeias. Cada uma diz de onde um artefato nasce, pra onde vai, e onde morre.

## 1. Proveniência de pesquisa — research é insumo, não veredito

```
INBOX.md  →  docs/research/<YYYY-MM>-<slug>.md  →  RESEARCH.md  →  ADR / DDR
(nota crua)   (estudo com frontmatter)            (índice+síntese)  (decisão)
```

Nota crua cai no `INBOX.md`. Vira estudo em `docs/research/` (frontmatter deixa o
acervo consultável: `grep type:`, `tags:`, `status:`). O `RESEARCH.md` é o índice
curado + a síntese cross-cutting. Quando um estudo fecha uma decisão, ela migra
pra um **ADR** (técnica) ou **DDR** (design). O research fica como insumo do
debate — nunca é o veredito.

## 2. Ciclo de spec — ongoing → done → PRD + CHANGELOG

```
docs/specs/ongoing/<spec>/  →  docs/specs/done/  →  docs/prd/<sistema>.md  +  CHANGELOG.md
(contrato+plano, em build)      (frozen)             (nova verdade funcional)   (ponteiro, não resumo)
```

Spec nasce como folder em `ongoing/` (contrato §1 + plano §2-3). Ao shippar, vai
pra `done/` (congelada), a **verdade funcional** que ela criou atualiza o
`docs/prd/<sistema>.md`, e o `CHANGELOG.md` ganha uma linha — **ponteiro, não
resumo**: o changelog diz "o quê e quando", o PRD diz "como é agora". Não se
duplica o conteúdo da spec no changelog.

## 3. Espinha de produto — porquê → o quê → pele → navegação → como

```
STRATEGY  →  PRD  →  DESIGN  →  ROUTES  →  CONVENTIONS
(porquê)    (o quê)  (a pele)  (navegação) (o como)
```

A leitura desce do abstrato ao concreto. `STRATEGY` diz por que o produto existe;
`PRD` o que ele faz; `DESIGN` como se parece/comporta na superfície; `ROUTES` como
se navega; `CONVENTIONS` como se constrói. Cada doc referencia o vizinho por link,
não reescreve. Projeto sem front-end apaga `DESIGN`/`ROUTES` (são opcionais do
scaffold).

## 4. Três espécies de decisão — três lugares

| Espécie | O quê | Onde | Vocabulário |
|---------|-------|------|-------------|
| **ADR** | decisão técnica/arquitetural com trade-off | `docs/conventions/adrs/adr-NNNN-<slug>.md` | Architecture Decision Record |
| **DDR** | decisão de superfície/UX (vocabulário, tom, layout) | `docs/design/ddr-NNNN-<slug>.md` | Design Decision Record |
| **ADR-Spec** | decisão local de uma feature (`D-NN` na spec) | `docs/specs/<spec>/spec.md` §1 | contrato da spec |

ADR e DDR são pastas distintas porque o eixo é distinto: técnica vs experiência.
Decisão aceita é **imutável** — não se edita um ADR aceito; cria-se um novo que o
**substitui** (`superseded by adr-NNNN`). O histórico da decisão é a cadeia de
supersessão, não um diff.

**Loop de design verificável (se o projeto mantém DESIGN.md):** regra de design
se separa em camada que código checa (lint/CI) e camada que exige julgamento.
Julgamento roda via plugin `impeccable@impeccable` (`/plugin marketplace add
pbakaus/impeccable`, auto-update) — `critique` com rubric P0-P3. Instalação
entra no bootstrap do projeto (`project-template/scripts/bootstrap-design-skill.sh`),
não fica só documentada; um hook (`design_skill_reminder.py`) lembra de rodar a
skill ao editar arquivo de UI. `ship-review` consome P0/P1 como gate Critical;
achado de craft vira entrada em `docs/design/exemplars.md`, não só memória. Sem
`DESIGN.md`, nada disso se aplica.

## 5. Runbook vs recipe — quem é o executor default

```
tem decisão humana no loop?  ── sim →  runbook  (docs/runbooks/)
                             └─ não →  recipe   (docs/conventions/recipes/)
```

Teste do executor-default: "um agente roda isto do começo ao fim sem perguntar
nada?" Sim → **recipe** (determinístico, agente sozinho). Não (precisa de
julgamento ou aprovação) → **runbook** (humano no loop). Se é só rodar um
comando sem decisão nenhuma, não é nem um nem outro — é linha de README ou `make`.

## 6. Molde e instância — CAIXA-ALTA vs lowercase

Todo diretório de docs tem um molde `_TEMPLATE-*` (copie pra criar uma instância).
A caixa do nome é **funcional**, não estética:

- **CAIXA-ALTA** (`STRATEGY.md`, `PRD.md`, `RESEARCH.md`) = papel de raiz, doc
  único e estável do repo. Um por projeto.
- **lowercase** (`adr-0007-cache.md`, `2026-07-bench.md`, `<sistema>.md`) = slug
  de instância. O lowercase é o que as skills globam (`docs/research/*.md` menos
  `_TEMPLATE-*`). Nome de instância em CAIXA-ALTA quebra o glob.

O prefixo `_TEMPLATE-` mantém o molde fora do glob de instâncias — nunca se
processa o template como se fosse conteúdo.

## 7. Raiz é estado, não decision log

Os docs de raiz (`AGENTS.md`, `PRD.md`, `CONVENTIONS.md`, …) descrevem **como as
coisas são agora** — instrução viva. Não guardam "o que mudou" (→ `CHANGELOG.md`),
nem "por que decidimos" (→ ADR/DDR), nem status volátil (→ tracker). Teste
linha-a-linha: "cortar isso faria o agente/leitor errar sobre o estado atual?"
Não → cortar. Doc de raiz que vira changelog apodrece; a cada sessão custa
contexto e mente sobre o presente.
