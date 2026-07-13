# Adversarial Evaluator (detalhe) e Modo Evaluator (--rubric)

## Adversarial Evaluator (via Evaluator Status Block)

**Em modo legado (sem `--rubric` e sem frontmatter `rubric:` na spec): ship-review é leitor puro do Evaluator Status Block.** Nunca escreve Block. Nunca invoca `peer-review.sh`. Zero dual writer — `spec-and-plan` Fase 3 e `test-and-debug` standalone são os únicos writers do Block.

**Em modo Evaluator (`--rubric` ou frontmatter): ship-review é o owner do Block** pra aquele round. Aplica rubric, emite findings, atualiza §5. Detalhe abaixo em §"Modo Evaluator". A regra "nunca dual writer" continua valendo — quando ship-review escreve, ele é o único writer naquela sessão; quando spec-and-plan/test-and-debug escrevem, ship-review só lê.

> **Nota sobre strings literais:** `ship rejected: ...`, `Gate 2: pulado (razão: ...)` etc. são marcadores observáveis pra grep/teste automatizado. Manter a grafia exata em inglês — não traduzir pra PT-BR.
>
> **Formato canônico do Evaluator Status Block:** ver `~/.claude/CLAUDE.md` → seção `### Evaluator Status Block — fonte canônica`.

**Matriz de ação por status do Gate 2 no Block mais recente da sessão com `spec_path`+`phase` matching:**
- `ok` → prossegue com os 6 eixos humanos (corretude, legibilidade, arquitetura, segurança, performance, simplificação & débito) + security checklist
- `pulado` → prossegue com 6 eixos. Output final inclui literalmente `Gate 2: pulado (razão: <texto>)`
- `indisponível` → se o **fallback adversarial** rodou (`reviewer: claude-adversarial` + `Gate 2: ok`), aceita como validação degradada e prossegue. Senão, **rejeita ship** com output `ship rejected: Gate 2 indisponível — voltar pro spec-and-plan Fase 3 re-executar`
- `blocked_precondition` → **rejeita ship** com output `ship rejected: Gate 2 blocked_precondition — resolver suite via test-and-debug`
- `critical_aberto` → **rejeita ship** com output `ship rejected: Gate 2 critical_aberto — voltar pro spec-and-plan Fase 3 até ok`
- `teto_atingido` → **rejeita ship** com output `ship rejected: Gate 2 teto_atingido — decisão do usuário necessária (aceitar / redesenhar / abandonar)`
- `n/a` OU Block ausente → **rejeita ship** com output `ship rejected: sem Evaluator Status Block na sessão — invocar spec-and-plan ou test-and-debug standalone antes`

Em nenhum caso ship-review escreve "sem bloqueantes" se status != `ok` e != `pulado`.

## Modo Evaluator (`--rubric`) — opcional, opt-in

**Quando ativa:** spec.md tem frontmatter `rubric: <nome>` OU invocação explícita `/ship-review --rubric=<path>`. Sem nenhum dos dois, comportamento default (legacy, 6 eixos por juízo livre) preserva back-compat.

**O que muda:**

1. **Substitui o passo "3. Revisar implementação nos 6 eixos"** pela aplicação da rubric scored 1-5. Os 6 eixos legados são absorvidos pelos critérios da rubric (ou explicitamente fora dela, declarado pela própria rubric).
2. **Resolução do rubric** (primeiro que casar):
   - `<spec-folder>/rubric.md` (override per-spec)
   - `<repo>/docs/rubrics/<nome>.md` (projeto)
   - `~/.claude/docs/rubrics/<nome>.md` (user-level)
3. **Emite `findings/pass-N.md`** dentro da folder da spec, formato canônico (ver `~/.claude/specs/ongoing/spec-2026-001-ship-review-evaluator/spec.md` §"Schema canônico — findings/pass-N.md"). Frontmatter inclui `pass`, `reviewer`, `rubric`, `verdict (ok | iterate | block)`.
4. **Atualiza Evaluator Status Block na §5 da spec.md** com `verdict` resumido. Isso **substitui** a regra legada "ship-review é leitor puro" — em modo `--rubric`, ship-review é o **owner do Block**.
5. **Cap de 3 passes.** `pass-4` retorna `teto_atingido`; exige `--override` explícito pra prosseguir.
6. **`--fresh`** (opcional): invoca `peer-review.sh` como backend (subagente fork de contexto limpo). Cascata `codex → gemini → fork` preservada. Sem `--fresh`, evaluator roda no contexto principal.

**Threshold:** declarado no frontmatter da rubric (default `4`). Spec pode override via frontmatter `threshold: N`. Qualquer critério abaixo do threshold = `iterate`. Critérios marcados com severidade alta na rubric (ex.: security ≤ 2) = `block` (não `iterate`).

**Eixos que continuam fora da rubric e seguem como hoje:**
- §"Checklist de segurança" (passo 4 atual)
- §"Doc-completeness — modelo-v2" (passo 3b atual)
- §"Runbook check" (passo 6 atual)

Estes não foram absorvidos pela rubric porque são gates ortogonais (checklist boolean, não score). Continuam como bloqueio independente — passar na rubric mas falhar no security checklist ainda rejeita ship.

**Output em modo Evaluator:**

```
Pass 1 — rubric: feature-backend — verdict: iterate
Scores: C1=4 ✓ | C2=3 ✗ | C3=5 ✓ | C4=4 ✓ | C5=n/a | C6=4 ✓
Findings detalhados: docs/specs/ongoing/<slug>/findings/pass-1.md
Próximo passo: corrigir F1 (C2) e re-rodar /ship-review --rubric
```

**Compatibilidade com modo legado:**
- Sem `--rubric` e sem frontmatter `rubric:` → legacy (leitura do Block, 6 eixos, classificação Critical/Important/Suggestion).
- Modo `--rubric` é opt-in **per-spec**; outras specs na mesma sessão seguem cada uma seu modo.
