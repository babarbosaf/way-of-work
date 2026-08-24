---
name: spec-and-plan
description: |
  Transforma ideia refinada em spec técnica (contrato + plano) com tasks executáveis e build incremental com TDD. Spec só pra feature grande; o resto vai direto pro código.
  Invoque quando a feature atravessa várias sessões, toca muitos arquivos, muda contrato ou toca prod; também quando o usuário disser "vou implementar X"/"preciso construir Y" com esse porte.
  Não invoque para: bug com linha localizada, refactor puro, script one-shot, ajuste de config/docs, mudança que cabe numa sessão, isso vai direto pro código com TDD.
---

> "A spec é a fonte de verdade temporária. O plano é a ponte entre spec e código.
> Ao shippar, a verdade migra pro PRD e a spec vira histórico."
> Nenhuma linha de código antes do §1 aprovado.

---

## O artefato: 1 arquivo, 4 seções

Spec é **um arquivo**: `docs/specs/<slug>.md`. Sem folder, sem rubric, sem
ongoing/done. Ela é descartável por desenho: ao shippar, a verdade funcional
que ela criou atualiza o `PRD.md` (política de docs vivos do projeto) e o
arquivo fica como histórico, nunca é fonte de verdade depois do ship.

- **§1 Contrato.** O que o dono revisa e assina:
  - **Como fica:** fluxo antes → depois em ASCII estreito (≤40 colunas), linguagem de negócio. Se o sistema tem PRD, o contexto **linka** a seção afetada, não a reescreve.
  - **Decisões `D-NN`:** parágrafo curto cada, o quê, por quê, trade-off. Sem template formulaico.
  - **Critérios de aceite:** SIM/NÃO comportamental ("rota desconhecida → aviso", não "WHERE zona IS NULL").
  - **Fora de escopo:** 1 linha por item.
- **§2 Design técnico.** Mudanças em partes; mini-ADR quando há ≥2 caminhos não-óbvios (opções, escolha, porquê, em prosa); **Security e Rollback só quando a mudança toca prod, input externo ou é irreversível**. Aí são obrigatórios (modelo de ameaça vetor × defesa; cenário × procedimento de rollback).
- **§3 Tasks.** Plano da Fase 2.
- **§4 Ao fechar.** Seções do PRD a atualizar (e CONVENTIONS.md/ROUTES.md/DESIGN.md se a feature criou padrão novo).

**Regras de ouro:**
1. §1 não tem detalhe de implementação (sem SQL, sem nome de função). Termo de domínio do dono é ok.
2. Os ramos do "Como fica" são a fonte única dos cenários de teste, cada ramo vira um teste de journey; não descrever jornadas duas vezes.
3. Toda `D-NN` aparece em ≥1 task. Decisão sem task = decisão órfã.

Config do projeto (trunk, `verify_cmd`, `smoke_cmd`, tracker) vem de `.claude/project.yaml`; sem ele, do CLAUDE.md/AGENTS.md do projeto; em último caso, perguntar.

---

## Fase 1: Spec

- [ ] **1. Desambiguar antes de escrever** em 3 lentes: **técnica** (premissa que sustenta uma D-NN se confirma contra a fonte: API, doc via `use context7`, ambiente), **arquitetural** (≥2 caminhos não-óbvios → mini-ADR), **produto** (edge case, formato, política de erro → vira D-NN). Perguntas em batch único, ranqueadas.
- [ ] **2. Escrever §1 e §2** na profundidade que o risco pede (ver Security/Rollback acima).
- [ ] **3. Segunda opinião (opcional):** se a spec toca prod ou é cara de reverter, oferecer `~/.claude/scripts/peer-review.sh spec <path>` antes da aprovação. Não é gate: o dono decide.
- [ ] **4. Aprovação explícita do §1** pelo usuário → `Status: aprovado` no frontmatter.

---

## Fase 2: Tasks

- [ ] **1. Separar faz-agora de bloqueado-em-X-externo** (auth, sign-off, credencial, dado que não chegou), task bloqueada leva `bloqueado: <X>`; o executável vai primeiro.
- [ ] **2. Fatiar verticalmente.** Cada task = caminho completo testável (função + teste + integração), effort `XS/S/M` (nunca L, quebrar), dependências explícitas (`dep:T3`).
- [ ] **3. Classificar delegação:** task autocontida (ACs fechados, arquivos definidos, sem decisão de arquitetura aberta) leva `delega: <task-type>`, vinculante no build (a skill `delegate` despacha; sem marcador = inline, sem reavaliar). Task acoplada à conversa nunca leva.
- [ ] **4. Rastreabilidade D-NN → task** + checkpoint com o usuário a cada 2-3 tasks.
- [ ] **5. Desdobrar em issues no tracker** quando o projeto tem um (`references/refine.md`).

Checklist extra pra pipeline/handler/endpoint (idempotência, TTL, falha encadeada): `references/checklists.md`.

**Paralelismo:** antes do build, confirmar que os arquivos tocados não conflitam com outra spec ativa em `docs/specs/`; conflito → resolver ordem antes.

---

## Fase 3: Build incremental

TDD por task, sem ping fora de checkpoint (obstáculo → nota na spec, segue até o checkpoint):

- [ ] **1. RED.** Teste que falha documenta o comportamento esperado.
- [ ] **2. GREEN.** Mínimo pra passar, sem extras.
- [ ] **3. REFACTOR.** `/simplify` mantendo verde; sem comportamento novo.
- [ ] **4. Diff só com arquivos da task**; checkpoint antes do próximo slice.
- [ ] **5. Segunda opinião no diff (opcional):** mesma regra da spec, toca prod ou é caro de reverter → oferecer `peer-review.sh diff HEAD` com suite verde. Não é gate.

---

## Verification

- [ ] §1 sem jargão, aprovado antes de qualquer código
- [ ] ACs em SIM/NÃO comportamental; toda D-NN mapeada pra task
- [ ] Suite verde após build; diff focado
- [ ] §4 executado no ship: PRD atualizado com a nova verdade

Voz e red flags do doc: `references/style-and-flags.md`.

**Próximo passo:** build completo → ship (`git-workflow-and-versioning`).
