---
spec: category-derivada
Owner: Ana
status: aprovado
prd: docs/prd/medallion-core.md#dimensões
---

# Category derivada de section

## Problema

`dim_product.category` está NULL nos 4197 produtos.

## Como fica

A categoria passa a ser derivada da seção na ingestão.

## Decisões

**D-01.** `category` deriva de `section` na ingestão, e não vira campo editável.

## Critérios de aceite

- **AC-01** SIM: produto novo pelo caminho DTR chega com category preenchida
- **AC-02** SIM: section desconhecida vira "OUTROS" e registra warn

## Fora de escopo

- Interface de edição de categoria

## Slices

| NN | Título | Dep |
|---|---|---|
| 01 | category derivada no caminho DTR | — |
