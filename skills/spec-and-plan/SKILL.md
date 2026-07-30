---
name: spec-and-plan
description: |
  Transforma ideia refinada em spec técnica (contrato + plano) com tasks executáveis e build incremental com TDD. Spec só pra feature M/L; mudança pequena vai direto pro código.
  Invoque SEMPRE que a feature afeta mais de 1 arquivo, leva mais de 30 min, toca prod, ou cria endpoint/handler/cron/pipeline; também quando o usuário disser "vou implementar X"/"preciso construir Y"/"quero automatizar Z".
  Não invoque para: bug com linha localizada, refactor puro, script one-shot, ajuste de config/docs, mudança pequena e reversível.
---

> "A spec é a fonte de verdade. O plano é a ponte entre spec e código."
> Nenhuma linha de código antes do §1 aprovado. Nenhum commit grande sem teste.

---

## O artefato — 1 arquivo, 5 seções

Spec nasce em `docs/specs/ongoing/spec-YYYY-NNN-<slug>/spec.md`. A folder existe pro
sidecar opcional (`findings/pass-N.md` quando um round de review tem handoff denso —
ver `~/.claude/docs/adversarial-evaluator.md`); o documento é um só. Frontmatter declara
`rubric: <nome>` (resolve em `docs/rubrics/`) + `threshold: N`; sem rubric, o Evaluator
usa juízo livre. Ao shippar, a spec congela em `done/`.

- **§1 Contrato** — o que o dono revisa e assina:
  - **Como fica:** fluxo antes → depois em ASCII estreito (≤40 colunas), linguagem de negócio. Se o sistema tem PRD, o contexto **linka** a seção afetada, não a reescreve.
  - **Decisões `D-NN`:** parágrafo curto cada — o quê, por quê, trade-off. Sem template formulaico.
  - **Critérios de aceite:** SIM/NÃO comportamental ("rota desconhecida → aviso", não "WHERE zona IS NULL").
  - **Fora de escopo:** 1 linha por item.
- **§2 Design técnico** — mudanças em partes; mini-ADR quando há ≥2 caminhos não-óbvios (opções, escolha, porquê, em prosa); **Security e Rollback só quando a mudança toca prod, input externo ou é irreversível** — aí são obrigatórios (modelo de ameaça vetor × defesa; cenário × procedimento de rollback).
- **§3 Tasks** — plano da Fase 2.
- **§4 Ao fechar** — PRD do sistema atualizado + linha no CHANGELOG (quando o repo os tem).
- **§5 Gate** — Evaluator Status Block de cada round.

**Regras de ouro:**
1. §1 não tem detalhe de implementação (sem SQL, sem nome de função). Termo de domínio do dono é ok.
2. Os ramos do "Como fica" são a fonte única dos cenários de teste — cada ramo vira um teste de journey; não descrever jornadas duas vezes.
3. Toda `D-NN` aparece em ≥1 task. Decisão sem task = decisão órfã.

Config do projeto (trunk, `verify_cmd`, `smoke_cmd`, tracker) vem de `.claude/project.yaml`; sem ele, do CLAUDE.md do projeto; em último caso, perguntar.

---

## Fase 1 — Spec

- [ ] **1. Desambiguar antes de escrever**, em 3 lentes: **técnica** (premissa que sustenta uma D-NN se confirma contra a fonte — API, doc via `use context7`, ambiente; premissa não-verificada vira Critical no gate), **arquitetural** (≥2 caminhos não-óbvios → mini-ADR), **produto** (edge case, formato, política de erro → vira D-NN). Perguntas em batch único, ranqueadas.
- [ ] **2. Escrever §1 e §2** na profundidade que o risco pede (ver Security/Rollback acima).
- [ ] **3. Gate 1 — Evaluator automático:** `~/.claude/scripts/peer-review.sh spec <path>` sem perguntar. Emitir Evaluator Status Block (formato, estados, fallback e teto de rounds: `~/.claude/docs/adversarial-evaluator.md`). `critical_aberto` → parar, apresentar Criticals + opções; round 2 só com aprovação expressa.
- [ ] **4. Aprovação explícita do §1** pelo usuário → `Status: aprovado` no frontmatter.

---

## Fase 2 — Tasks

- [ ] **1. Separar faz-agora de bloqueado-em-X-externo** (auth, sign-off, credencial, dado que não chegou) — task bloqueada leva `bloqueado: <X>`; o executável vai primeiro.
- [ ] **2. Fatiar verticalmente** — cada task = caminho completo testável (função + teste + integração), effort `XS/S/M` (nunca L — quebrar), dependências explícitas (`dep:T3`).
- [ ] **3. Classificar delegação:** task autocontida (ACs fechados, arquivos definidos, sem decisão de arquitetura aberta) leva `delega: <task-type>` — vinculante no build (a skill `delegate` despacha; sem marcador = inline, sem reavaliar). Task acoplada à conversa nunca leva.
- [ ] **4. Rastreabilidade D-NN → task** + checkpoint com o usuário a cada 2-3 tasks.
- [ ] **5. Desdobrar em issues no tracker** quando o projeto tem um (writer, template e triage: `references/to-tickets.md`, `references/triage.md`, `references/refine.md`). Finding de build/review não morre em findings/ — vira issue.

Checklist extra pra pipeline/handler/endpoint (idempotência, TTL, falha encadeada): `references/checklists.md`.

**Paralelismo:** antes do build, confirmar que os arquivos tocados não conflitam com outra spec `ongoing/` ativa; conflito → resolver ordem antes.

---

## Fase 3 — Build incremental

TDD por task, sem ping fora de checkpoint (obstáculo → nota na spec, segue até o checkpoint):

- [ ] **1. RED** — teste que falha documenta o comportamento esperado.
- [ ] **2. GREEN** — mínimo pra passar, sem extras.
- [ ] **3. REFACTOR** — `/simplify` mantendo verde; sem comportamento novo.
- [ ] **4. Diff só com arquivos da task**; checkpoint antes do próximo slice.
- [ ] **5. Gate 2 — Evaluator no fim do build:** pré-requisito suite verde (senão `blocked_precondition`, voltar pro código). `peer-review.sh diff HEAD` sem perguntar; Block atualizado; `critical_aberto` → parar e pedir decisão; round 2 só com aprovação expressa.

---

## Verification

- [ ] §1 sem jargão, aprovado antes de qualquer código
- [ ] ACs em SIM/NÃO comportamental; toda D-NN mapeada pra task
- [ ] Suite verde após build; diff focado
- [ ] Evaluator Status Block no output (Gate 1 e Gate 2)

Voz e red flags do doc: `references/style-and-flags.md`.

**Próximo passo:** build completo → gate de ship (`git-workflow-and-versioning`).
