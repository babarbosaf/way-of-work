# Pass 2 — Gate 2 sobre o diff do build (2026-07-05)

Reviewer: codex real, via `peer-review.sh diff 1a744ab` → `delegate.sh --task review` (dogfooding).

## Blockers

Nenhum.

## Important (todos corrigidos)

1. `--model gemini` forçado caía em exit 2 mudo (backend fora da cascata) → agora erro claro apontando a policy. Teste novo.
2. Modo degradado (policy inválida) quebrava o `--worktree` (sem `worktree_invoke`) → defaults com sandbox pra codex/agy no modo degradado.
3. `--timeout` sem validação de boundary → exige inteiro, falha cedo. Teste novo.

## Suggestions

1. Mensagem de fallback do peer-review citava "codex+gemini" (stale) → corrigida pra apontar a policy. ✔
2. Append do inbox não-idempotente em policy inválida → dedupe por grep. ✔
3. Cooldown/log sem lock em execução concorrente → **risco aceito** (uso solo, single-session; revisitar se delegações paralelas virarem rotina).
