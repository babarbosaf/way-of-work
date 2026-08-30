02 [S] [P]  category derivada de section no caminho PDV

O que construir: mesmo comportamento do ticket 01, no caminho PDV. Reusa o
section_map criado lá, importando, sem editar.

files:      src/ingest/pdv.py
            tests/ingest/test_pdv_category.py
blocked_by: nenhum
delega:     implement
verify:     uv run pytest tests/ingest/test_pdv_category.py

Aceite:
- [ ] produto novo via PDV chega com category preenchida
- [ ] section desconhecida vira "OUTROS" e emite warn
