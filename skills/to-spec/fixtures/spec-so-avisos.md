---
spec: category-derivada
Owner: Ana
status: aprovado
prd: docs/prd/medallion-core.md#dimensoes
---

# Category derivada de section

## Problema

`dim_product.category` está NULL nos 4197 produtos. Toda quebra de receita por
categoria cai num bucket único e inútil. O dado existe: `section` vem preenchido
nos dois caminhos de ingestão. O script legado `data/scripts/dre_competencia.py`
já faz esse de-para na mão, uma vez por mês.

## Como fica

    hoje                depois
    ┌──────────┐        ┌──────────┐
    │ produto  │        │ produto  │
    │ section  │   ──►  │ section  │
    │ category │        │ category │◄─ derivado
    │  = NULL  │        │  = valor │
    └──────────┘        └──────────┘

## Decisões

**D-01.** `category` deriva de `section` na ingestão, não vira campo editável. O
de-para é estável e a edição manual criaria uma segunda fonte de verdade que
ninguém reconcilia. Trade-off: section nova exige tocar o de-para, e o warn avisa.

**D-02.** O backfill dos existentes é operação separada, com revisão humana antes
de gravar. Escreve em produção e não é reversível por `git revert`.

## Critérios de aceite

- SIM: produto novo pelo caminho DTR chega com category preenchida
- SIM: produto novo pelo caminho PDV chega com category preenchida
- SIM: section desconhecida vira "OUTROS" e registra warn
- NÃO: category continua não-editável na interface

## Fora de escopo

- Interface de edição de categoria
- Recategorização histórica além do backfill

## Rollback

O backfill (D-02) escreve em produção. Snapshot da coluna antes de gravar;
reversão é `UPDATE ... SET category = NULL` na lista de IDs do snapshot.

## Slices

| NN | Título | Dep |
|---|---|---|
| 01 | category derivada no caminho DTR | — |
| 02 | category derivada no caminho PDV | — |
| 03 | backfill dos existentes | 01, 02 |
