---
spec: 2026-001
pass: 1
emitted_by: ship-review (self-applied)
reviewer: claude-adversarial (inline)
rubric: feature-backend
rubric_path: ~/.claude/docs/rubrics/feature-backend.md
verdict: iterate
---

# Pass 1 — feature-backend

## Scores

| Critério | Score | Threshold | Pass? |
|---|---|---|---|
| C1 Acceptance criteria executável | 3 | ≥4 | ✗ |
| C2 Evolve > create | 5 | ≥4 | ✓ |
| C3 Cobertura do caminho crítico (TDD) | 2 | ≥4 | ✗ |
| C4 Tratamento de erro e estado consistente | 4 | ≥4 | ✓ |
| C5 Security & input boundary | n/a | — | — |
| C6 Rollback path | 4 | ≥4 | ✓ |

**Aceite global:** ✗ (C1 e C3 abaixo do threshold). Verdict: `iterate`.

## Findings

### F1 (C1) — AC sem evidência de execução
**Evidência:** spec.md §1 lista 11 critérios de aceite. Nenhum foi exercitado: o ship-review `--rubric` ainda não foi invocado contra spec real (esta pass é a primeira tentativa, e está sendo emitida manualmente em vez de via runtime da skill).
**Hipótese:** AC `ship-review --rubric=<path> aceita rubric externa e aplica score 1-5` exige execução pra verificar. Inspeção do SKILL.md mostra que o comportamento está **descrito**, não **executado** — gap esperado pra SKILL.md (são instruções pro modelo, não código).
**Próximo passo:** AC dessa categoria precisariam de smoke manual: invocar `/ship-review --rubric=feature-backend` em segunda spec (não-meta) e validar que findings/ é criado, scores aparecem, etc. Esta meta-pass não substitui smoke real.

### F2 (C3) — Sem suite automatizada
**Evidência:** §"Estratégia de testes" da spec admite "Sem suite automatizada (skill behavior é testado por uso)".
**Hipótese:** mudanças em SKILL.md não têm padrão TDD estabelecido no harness atual. `/skill-creator` provê eval runner, mas é heurístico (grader LLM), não red-green-refactor.
**Próximo passo:** aceitar limitação como conhecida; criar memória `[ANTI-PATTERN] SKILL.md edit sem TDD formal — fluxo é (a) edit, (b) self-lint, (c) smoke por uso real, (d) iteração` pra explicitar como tratamos essa classe. OU classificar esta spec como `rigor: leve` no frontmatter pra relaxar C3 (rubric script tem essa cláusula; feature-backend não).

### F3 (C1) — AC sobre capture-lessons depende de specs em done/
**Evidência:** AC "capture-lessons varre `docs/specs/done/*/findings/*.md` e propõe ações" só pode ser exercido quando ≥3 specs com findings/ existirem em done/. Hoje: zero.
**Hipótese:** AC pré-maduro pra esta spec; melhor mover pra spec separada da capture-lessons quando dados existirem.
**Próximo passo:** considerar splittar AC sobre capture-lessons da spec-2026-001 (deixar só skill behavior mínimo) e abrir nova spec quando trigger natural ocorrer.

## Notas do reviewer

**Rubric não é o melhor fit pra esta spec.** `feature-backend` foi desenhada pra endpoint/handler/pipeline com testes automatizáveis. Esta spec é evolução de skill (instruções pro modelo), onde "teste" não tem semântica clara. C5 marcado n/a porque não há input boundary; C3 cai pra 2 não por descuido mas por mismatch de domínio.

**Proposta de FUP:** criar rubric `skill-evolution.md` com critérios próprios: (a) description casa com conteúdo, (b) novo passo sem conflito, (c) condicional claro, (d) self-lint via grep, (e) smoke por uso real, (f) evolve > create. Esta seria a 5ª rubric seed.

**Esta pass é uma simulação manual.** O ship-review runtime que aplica rubric ainda não foi exercido contra spec real (limitação esperada — skill é instrução, não código executável). Verdict `iterate` reflete os gaps, mas o caminho pra "ok" é smoke por uso, não fix de spec.
