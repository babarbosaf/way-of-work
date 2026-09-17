01 [XS] category derivada de section no caminho DTR

spec:       docs/specs/category-derivada/spec.md
closes:     AC-01, AC-02

Contexto: a categoria alimenta toda quebra de receita, e hoje ela é NULL.

O que construir: produto ingerido pelo caminho DTR chega com category
derivada de section.

files:      src/ingest/dtr.py
blocked_by: nenhum
delega:     implement
verify:     uv run pytest tests/ingest/test_dtr_category.py

Aceite:
- [ ] produto novo via DTR chega com category preenchida
- [ ] section desconhecida vira "OUTROS" e emite warn no log
