03 [S]  backfill de category nos produtos existentes

Contexto: os 4197 produtos que já estão no banco não passam pela ingestão de novo.

O que construir: script de backfill com dry-run obrigatório. Imprime o de-para
completo e a contagem por categoria antes de gravar; grava só com --apply.

spec:       docs/specs/category-derivada/spec.md
closes:     AC-04
files:      scripts/backfill_category.py
            tests/scripts/test_backfill_category.py
blocked_by: #1, #2
delega:     não
verify:     uv run pytest tests/scripts/test_backfill_category.py

Aceite:
- [ ] dry-run mostra de-para completo e contagem, sem gravar
- [ ] --apply grava e salva snapshot dos IDs tocados
