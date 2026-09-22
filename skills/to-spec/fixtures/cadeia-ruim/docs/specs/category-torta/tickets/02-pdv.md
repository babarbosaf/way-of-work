02 [XS] derivar no PDV

Contexto: o mesmo aceite que o 01 já fecha, de propósito.

spec:       docs/specs/category-torta/spec.md
closes:     AC-01
files:      src/ingest/pdv.py
blocked_by: nenhum
delega:     implement
tier:       padrao
verify:     uv run pytest tests/ingest/test_pdv.py

Aceite:
- [ ] o caminho PDV preenche
