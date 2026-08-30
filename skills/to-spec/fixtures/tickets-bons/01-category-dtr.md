01 [XS] [P]  category derivada de section no caminho DTR

O que construir: produto ingerido pelo caminho DTR chega em dim_product com
category preenchida a partir de section. Section fora do de-para vira "OUTROS"
e registra warn.

files:      src/ingest/dtr.py
            src/ingest/section_map.py
            tests/ingest/test_dtr_category.py
blocked_by: nenhum
delega:     implement
verify:     uv run pytest tests/ingest/test_dtr_category.py

Aceite:
- [ ] produto novo via DTR chega com category preenchida
- [ ] section desconhecida vira "OUTROS" e emite warn no log
