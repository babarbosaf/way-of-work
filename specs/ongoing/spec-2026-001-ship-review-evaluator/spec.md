---
spec: 2026-001
title: ship-review evolui pra modo Evaluator (rubric + findings + fresh-context)
rigor: governança
rubric: feature-backend
threshold: 4
status: rascunho
---

# SPEC-2026-001 — ship-review → Evaluator

Primeira spec a nascer no formato folder. Dogfood do contrato definido em T5 da sessão de auditoria.

---

## §1 Contrato

### Como fica

```
ANTES
  spec.md (file solto)
    └─ §5 Evaluator Status Block (texto, sem rubric)
  ship-review
    └─ lê Block, valida 6 eixos por juízo livre
    └─ bloqueia se Critical aberto

DEPOIS
  spec-YYYY-NNN-<slug>/ (folder)
    ├─ spec.md (frontmatter: rubric: <nome> + threshold: <N>)
    ├─ rubric.md (opcional override)
    ├─ findings/pass-1.md, pass-2.md, pass-3.md (cap 3)
    └─ traces/ (smoke/playwright logs)

  ship-review --rubric=<path> [--fresh]
    ├─ resolve rubric (frontmatter → ~/.claude/docs/rubrics/<nome>.md
    │   ou override em spec-folder/rubric.md)
    ├─ aplica score 1-5 por critério
    ├─ --fresh: invoca peer-review.sh como backend (contexto limpo)
    ├─ emite findings/pass-N.md (detalhe estruturado)
    ├─ atualiza §5 da spec.md (Evaluator Status Block, resumo)
    └─ bloqueia ship se score < threshold em qualquer critério
```

### Decisões

**D-01 — Rubric scored 1-5 substitui juízo livre.** O Adversarial Evaluator de hoje classifica Critical/Important/Suggestion em 6 eixos por juízo. Rubric scored consistente entre rounds, comparable entre specs, gradable. Sem rubric explícita, o comportamento default cai pra modo legado (back-compat).

**D-02 — `findings/pass-N.md` materializa o detalhe; `§5 spec.md` continua sendo o status block resumido.** Compaction de contexto não cura coherence drift (Anthropic), structured handoffs sim. Detalhe de findings (evidências, file:line, próximo passo) precisa sobreviver pra próximo pass; §5 segue como interface única que `ship-review` lê (preserva ownership rules existentes).

**D-03 — Cap 3 passes.** Anthropic recomenda 2-3 passes no Evaluator. Acima disso é diminishing returns + custo. `pass-4` retorna `teto_atingido`, exige aprovação humana pra continuar.

**D-04 — `--fresh` opcional invoca `peer-review.sh` como backend.** Today `ship-review` corre no contexto principal. `--fresh` spawna subagente fork com APENAS spec.md + rubric.md + diff (sem carregar conversa). Resolve o problema de "modelo julga benigno seu próprio output" sem reescrever ship-review do zero.

**D-05 — Back-compat default.** Sem `--rubric` ou frontmatter `rubric:`, ship-review opera como hoje (6 eixos, juízo livre, Evaluator Status Block sem score). Migração é opt-in por spec.

### Critérios de aceite

- [ ] `ship-review --rubric=<path>` aceita rubric externa e aplica score 1-5
- [ ] `ship-review --fresh` invoca `peer-review.sh` como backend (cascata codex→gemini→fork preservada)
- [ ] `findings/pass-N.md` é criado dentro da folder da spec em cada round
- [ ] `§5` da `spec.md` recebe Evaluator Status Block resumido (formato canônico preservado)
- [ ] Tentativa de `pass-4` retorna `teto_atingido`; exige flag `--override` pra prosseguir
- [ ] Sem `--rubric` e sem frontmatter `rubric:`, comportamento é idêntico ao atual (back-compat)
- [ ] 4 rubrics seed existem em `~/.claude/docs/rubrics/`: `feature-backend.md`, `feature-ui.md`, `script.md`, `schema-migration.md`
- [ ] `_TEMPLATE-rubric.md` em `~/.claude/docs/rubrics/` documenta o schema canônico
- [ ] Frontmatter `rubric: <nome>` resolve primeiro em `docs/rubrics/<nome>.md` (projeto), depois em `~/.claude/docs/rubrics/<nome>.md` (user-level)
- [ ] Frontmatter `rubric: <nome>` + `spec-folder/rubric.md` no mesmo lugar = override per-spec ganha
- [ ] `capture-lessons` varre `docs/specs/done/*/findings/*.md` e propõe ações quando padrão repetido (critério X falhou em N de M últimas specs)

### Fora de escopo

- **Ralph loop** — separado, deferido. Esta spec habilita o Evaluator que serve qualquer generator (humano ou loop).
- **Migração de specs antigas** — `done/` fica flat. Convenção folder só pra `ongoing/` daqui pra frente.
- **Playwright/E2E integration** — rubric pode citar `smoke_cmd` como input, mas plumbing Playwright é FUP separado.
- **`state.json` schema** — adicionado como afford opcional na folder, mas schema canônico fica pra quando aparecer uso real (anti-YAGNI).

---

## §2 Design técnico

### Mudanças

| Arquivo | Mudança |
|---|---|
| `~/.claude/skills/ship-review/SKILL.md` | Nova §"Modo Evaluator". Flags `--rubric=<path>` e `--fresh`. Lógica de score + threshold. Cap 3 passes. |
| `~/.claude/docs/rubrics/_TEMPLATE-rubric.md` | Schema canônico (critérios 1-5, threshold, formato YAML/markdown) |
| `~/.claude/docs/rubrics/feature-backend.md` | Seed |
| `~/.claude/docs/rubrics/feature-ui.md` | Seed |
| `~/.claude/docs/rubrics/script.md` | Seed |
| `~/.claude/docs/rubrics/schema-migration.md` | Seed |
| `~/.claude/skills/capture-lessons/SKILL.md` | Nova lente "Trace ingestion" — varre `docs/specs/done/*/findings/`. Compactação geral. |
| `~/.claude/skills/spec-and-plan/SKILL.md` | ✓ feito (T5): spec-as-folder uniforme |

### Mini-ADR

Considerei criar skill nova `/evaluate` em paralelo. Descartei — `ship-review` já é o gate pré-merge (decisão de aceitar trabalho); evoluir é cumprir `evolve-over-create`. Criar paralela duplicaria a semântica e forçaria a pessoa (ou eu) a decidir entre dois gates pra mesma decisão.

Considerei tornar rubric obrigatório em toda spec. Descartei — força migração simultânea de todo backlog ativo + quebra script/script-trivial onde rubric não acrescenta. Back-compat por opt-in segue o princípio de "criar exceção registrada quando boundary semântico é distinto" (rubric é boundary novo, mas legado tem rubric implícito = 6 eixos do ship-review).

### Schema canônico — `findings/pass-N.md`

```markdown
---
spec: 2026-001
pass: 1
emitted_by: ship-review
reviewer: codex | gemini | claude-adversarial
rubric: feature-backend
rubric_path: ~/.claude/docs/rubrics/feature-backend.md
verdict: ok | iterate | block
---

# Pass 1 — feature-backend

## Scores

| Critério | Score | Threshold | Pass? |
|---|---|---|---|
| C1 Acceptance criteria executável | 4 | ≥4 | ✓ |
| C2 Evolve > create | 3 | ≥4 | ✗ |
| C3 Cobertura TDD | 5 | ≥4 | ✓ |
| ... | | | |

**Aceite global:** ✗ (C2 abaixo do threshold)

## Findings

### F1 (C2) — Criação paralela em vez de extensão
**Evidência:** `src/foo.py:42-58` cria `EvaluatorV2` em paralelo a `Evaluator` existente.
**Hipótese:** justificativa "isolar nova lógica" não cobre o caso (interface idêntica em 80%).
**Próximo passo:** consolidar `EvaluatorV2` no `Evaluator` com flag opt-in OU justificar em Mini-ADR.

### F2 ...
```

### Schema canônico — `~/.claude/docs/rubrics/<nome>.md`

```markdown
---
rubric: feature-backend
threshold: 4
---

# Rubric — feature-backend

## C1 — Acceptance criteria executável
- **5:** cada AC tem teste automatizado verde
- **4:** AC manuais demonstrados (log/screenshot) + cobertura ≥80%
- **3:** AC parcialmente cobertos
- **2:** AC só descritos, sem evidência
- **1:** AC ausentes ou ambíguos

## C2 — Evolve > create (anti-duplicação)
- **5:** estendeu artefato existente; zero dívida nova
- **4:** criou novo com justificativa em ADR/Mini-ADR
- **3:** criou novo sem justificativa explícita
- **2:** criou paralelo a artefato com semântica próxima
- **1:** divergência ativa de outro artefato

## ... (4-6 critérios totais)

## Aceite

Score ≥4 em **todos** os critérios. Qualquer <4 = `iterate` (ou `block` se C de severidade alta).
```

### Resolução do rubric

Frontmatter da `spec.md`:
```yaml
rubric: feature-backend
threshold: 4
```

Ordem de resolução (primeira que casar):
1. `<spec-folder>/rubric.md` (override per-spec)
2. `<repo>/docs/rubrics/<nome>.md` (projeto)
3. `~/.claude/docs/rubrics/<nome>.md` (user-level)

### Segurança / Rollback

- **Rollback:** reverter mudança em `ship-review/SKILL.md`; rubrics ficam (não quebram nada).
- **Back-compat:** sem `--rubric` nem frontmatter, comportamento idêntico. Risk = zero pra specs existentes.
- **Risk concreto:** `--fresh` invoca subagente fork; se `peer-review.sh` quebrar, fallback inline já existe (cascata atual).

---

## §3 Slices

Slices abaixo viram tasks na TaskList da sessão (T3, T6, T4):

- **Slice A — Rubrics seed** (T3): escrever 4 rubrics + 1 template em `~/.claude/docs/rubrics/`. Sai standalone, não bloqueia T6 mas T6 referencia.
- **Slice B — ship-review SKILL.md** (T6): adicionar modo Evaluator (`--rubric`, `--fresh`), emissão `findings/pass-N.md`, cap 3 passes. Valida pós-edit com `/skill-creator`.
- **Slice C — capture-lessons evolução** (T4): compactar SKILL.md atual, adicionar lente trace-ingestion. Valida pós-edit.
- **Slice D — Smoke manual:** rodar `ship-review --rubric=feature-backend` num spec real (esta mesma? auto-aplicar como meta-validação).

---

## §4 Ao fechar

- Move folder pra `done/spec-2026-001-ship-review-evaluator/`
- Não há PRD pra atualizar (escopo é skill user-level, não sistema do projeto)
- CHANGELOG: entrada em `~/.claude/CHANGELOG.md` (criar se não existir) com sumário das mudanças
- Memória `feedback_validar_skill_pos_edit` lembra: `/skill-creator` pra cada SKILL.md tocado (ship-review, capture-lessons)

---

## §5 Evaluator Status Block

```
Gate 1 (spec, pass-1): iterate — rubric: feature-backend — reviewer: claude-adversarial (inline, self-applied)
  Scores: C1=3 ✗ | C2=5 ✓ | C3=2 ✗ | C4=4 ✓ | C5=n/a | C6=4 ✓
  Detalhe: findings/pass-1.md
  Razão verdict: feature-backend rubric é mismatch parcial de domínio (esta spec é skill evolution, não backend feature)
Gate 2 (build): pendente — gated por smoke real de ship-review --rubric numa spec não-meta
```

**FUP rastreável:**
- Criar rubric `skill-evolution.md` (5ª seed) com critérios próprios pra mudanças em SKILL.md
- Splittar AC sobre capture-lessons (depende de specs em done/ que não existem hoje)
- Smoke real: aplicar `/ship-review --rubric=feature-backend` em próxima spec não-meta (validação ground-truth)
