---
spec: SPEC-2026-049
Owners: Benedito (decisões), Claude (drafting)
status: ongoing (post-reconciliation v3 — D-2; pre Codex round 3 confirm)
---

# KPIs Semantic Layer

## Problema

O Rocky não consegue responder pergunta de série temporal.

## Como fica

Fica melhor.

## Decisões

**D-01.** Três tabelas enriched.

## Design

### D2. DDL completo das 3 tabelas

```sql
CREATE TABLE fact_kpi_overtime (
  fact_id TEXT PRIMARY KEY,
  enriched_at TIMESTAMP NOT NULL
);
```

CREATE INDEX idx_kpi_overtime ON fact_kpi_overtime (fact_id);

### D3. Contratos Pydantic

```python
class FactKpiOvertime(BaseModel):
    fact_id: str
```

O enricher vive em `apps/rocky/src/rocky/enricher.py` e lê de `lib/kpi_io.py`.

## Critérios de aceite

- SIM: o enricher deve funcionar corretamente
- SIM: performance deve estar ok

## Codex Gate Status

Round 2: 4 Critical, 5 Important.

## Resposta ao Codex Round 3

Absorvidos os findings C1 a C4.

## Resposta ao Round 4

Ajustado D-T49.

## Anexo B — Lista completa de findings absorvidos

- F-I20, F-C3.b, T-C9.
