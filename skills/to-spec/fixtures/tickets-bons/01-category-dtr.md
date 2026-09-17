01 [XS] [P]  category derivada de section no caminho DTR

Contexto: a quebra de receita por categoria cai num bucket NULL porque `dim_product.category` nunca foi preenchida.

O que construir: produto ingerido pelo caminho DTR chega em dim_product com
category preenchida a partir de section. Section fora do de-para vira "OUTROS"
e registra warn.

spec:       docs/specs/category-derivada/spec.md
closes:     AC-01, AC-03
files:      src/ingest/dtr.py
            src/ingest/section_map.py
            tests/ingest/test_dtr_category.py
blocked_by: nenhum
delega:     implement
verify:     uv run pytest tests/ingest/test_dtr_category.py

Aceite:
- [ ] produto novo via DTR chega com category preenchida
- [ ] section desconhecida vira "OUTROS" e emite warn no log
