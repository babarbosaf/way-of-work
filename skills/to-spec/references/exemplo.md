# Exemplo: uma spec inteira

Caso real, encurtado. Repositório de dados; `dim_product.category` chegou NULL em
todos os produtos e a quebra de receita por categoria ficou impossível.

Note o tamanho: 58 linhas para uma feature que toca dois caminhos de ingestão,
um backfill de 4197 linhas e um teste de reconciliação. Não falta nada: o que
não está aqui está no ticket que constrói.

---

```markdown
---
spec: category-derivada
Owner: Benedito
status: aprovado
created: 2026-07-09
prd: docs/prd/medallion-core.md#dimensoes
---

# Category derivada de section

## Problema

`dim_product.category` está NULL nos 4197 produtos. Toda quebra de receita ou
margem por categoria cai num bucket único e inútil. O dado existe: `section` vem
preenchido nos dois caminhos de ingestão, e a relação section → category é
conhecida e estável.

## Como fica

    hoje                depois
    ┌──────────┐        ┌──────────┐
    │ produto  │        │ produto  │
    │ section  │   ──►  │ section  │
    │ category │        │ category │◄─ derivado
    │  = NULL  │        │  = valor │
    └──────────┘        └──────────┘

    ingestão DTR ─┐                  ┌─► category
                  ├─► de-para  ──────┤
    ingestão PDV ─┘                  └─► "OUTROS" + warn

## Decisões

**D-01.** `category` deriva de `section` no momento da ingestão, não vira campo
editável. Duas razões: o de-para é estável e a edição manual criaria uma segunda
fonte de verdade que ninguém reconcilia. Trade-off aceito: section nova exige
tocar o de-para. É raro e o warn no log avisa.

**D-02.** O backfill dos 4197 existentes é operação separada, com revisão humana
da tabela de-para antes de gravar. Escreve em produção e não é reversível por
`git revert`; merece dry-run e um par de olhos.

**D-03.** Section desconhecida cai em `"OUTROS"` com warn, não falha a ingestão.
Perder um lote inteiro de vendas por causa de uma section nova é pior que
classificar errado uma linha até alguém ver o log.

## Critérios de aceite

- SIM: produto novo pelo caminho DTR chega com `category` preenchida
- SIM: produto novo pelo caminho PDV chega com `category` preenchida
- SIM: section desconhecida vira `"OUTROS"` e registra warn
- SIM: quebra de receita por categoria não tem bucket NULL
- NÃO: `category` continua não-editável na interface

## Fora de escopo

- Interface de edição de categoria
- Recategorização histórica além do backfill
- Hierarquia de subcategoria

## Rollback

O backfill (D-02) escreve em produção. Snapshot da coluna antes de gravar;
reversão é `UPDATE ... SET category = NULL` na lista de IDs do snapshot.
Ingestão nova não precisa de rollback: código novo, `git revert` resolve.

## Slices

| NN | Título | Dep |
|---|---|---|
| 01 | category derivada no caminho DTR | — |
| 02 | category derivada no caminho PDV | — |
| 03 | backfill dos 4197 existentes | 01, 02 |
| 04 | scenario de reconciliação falha se NULL voltar | 03 |
```

---

## O que não está aqui, de propósito

| Ausente | Onde mora |
|---|---|
| DDL do de-para, schema da coluna | ticket 01, que cria a migration |
| Nome das funções de ingestão | ticket que as escreve |
| Casos de teste enumerados | aceite do ticket + o teste em si |
| Query do scenario de reconciliação | ticket 04 |
| Tabela de-para completa | dado, não decisão. Vive no repositório |

A spec tem uma seção **Rollback** porque D-02 escreve em produção. Não tem
**Segurança**: nenhum input externo, nenhuma superfície nova. Seção condicional
que não se aplica não aparece vazia.

O mapa de slices é a única ponte pro `to-tickets`: quatro linhas, ordem de
dependência explícita. O ticket rico nasce lá, não aqui.
