# Exemplo: quatro tickets de uma spec

Continuação do exemplo de `to-spec/references/exemplo.md`. O mapa de slices tinha
quatro linhas; aqui viram quatro tickets executáveis.

Projeto sem tracker (`backend: none`), então cada um é um arquivo em
`docs/specs/category-derivada/tickets/`.

---

## Conteúdo

- `01-category-dtr.md`
- `02-category-pdv.md`
- `03-backfill.md`
- `04-scenario-reconciliacao.md`
- Por que assim
- Rastreabilidade

## `01-category-dtr.md`

```markdown
01 [XS] [P]  category derivada de section no caminho DTR

O que construir: produto ingerido pelo caminho DTR chega em dim_product com
category preenchida a partir de section. Section fora do de-para vira "OUTROS"
e registra warn.

files:      src/ingest/dtr.py
            src/ingest/section_map.py
            migrations/012_section_category_map.sql
            tests/ingest/test_dtr_category.py
blocked_by: nenhum
delega:     implement
verify:     uv run pytest tests/ingest/test_dtr_category.py

Aceite:
- [ ] produto novo via DTR chega com category preenchida
- [ ] section desconhecida vira "OUTROS" e emite warn no log
- [ ] section_map é a única fonte do de-para (D-01)

spec: docs/specs/category-derivada/spec.md
```

## `02-category-pdv.md`

```markdown
02 [S] [P]  category derivada de section no caminho PDV

O que construir: mesmo comportamento do ticket 01, no caminho PDV. Reusa o
section_map criado lá.

files:      src/ingest/pdv.py
            tests/ingest/test_pdv_category.py
blocked_by: nenhum
delega:     implement
verify:     uv run pytest tests/ingest/test_pdv_category.py

Aceite:
- [ ] produto novo via PDV chega com category preenchida
- [ ] section desconhecida vira "OUTROS" e emite warn

spec: docs/specs/category-derivada/spec.md
```

## `03-backfill.md`

```markdown
03 [S]  backfill de category nos 4197 produtos existentes

O que construir: script de backfill com dry-run obrigatório. Imprime o de-para
completo e a contagem por categoria antes de gravar; grava só com --apply.

files:      scripts/backfill_category.py
            tests/scripts/test_backfill_category.py
blocked_by: #01, #02
delega:     não
verify:     uv run pytest tests/scripts/test_backfill_category.py

Aceite:
- [ ] dry-run mostra de-para completo e contagem, sem gravar
- [ ] --apply grava e salva snapshot dos IDs tocados
- [ ] rollback documentado no README do script

spec: docs/specs/category-derivada/spec.md  (D-02)
```

## `04-scenario-reconciliacao.md`

```markdown
04 [XS]  scenario de reconciliação falha se bucket NULL voltar

O que construir: o scenario de receita passa a falhar quando aparece linha com
category NULL, em vez de somar num bucket silencioso.

files:      tests/scenarios/revenue_reconcilia.py
blocked_by: #03
delega:     implement
verify:     uv run pytest tests/scenarios/revenue_reconcilia.py

Aceite:
- [ ] scenario falha com category NULL presente
- [ ] mensagem de erro nomeia os SKUs afetados

spec: docs/specs/category-derivada/spec.md
```

---

## Por que assim

**`01` e `02` são `[P]`.** Nenhum bloqueador e os `files:` não se cruzam: um mexe
em `dtr.py`, o outro em `pdv.py`. Duas sessões, dois worktrees, mesmo SHA base:

```bash
claude -w t01-category-dtr
claude -w t02-category-pdv
```

**`section_map.py` pertence ao `01`, e só a ele.** O `02` reusa importando, não
editando. Se o `02` precisasse mudar o de-para, os dois deixariam de ser `[P]`:
seria `blocked_by: #01`.

**`03` não é `[P]` e não delega.** `blocked_by: #01, #02` porque depende do
de-para pronto, e `delega: não` porque escreve em produção: `ready-for-human`.

**`04` fecha a malha.** Depende do `03` e existe para o bug não voltar calado.

**Nenhum ticket de integração aqui.** Nenhuma mudança cross-cutting: ninguém toca
config central nem tabela de rotas. Se `01` e `02` precisassem os dois registrar
o novo campo num `schema.yaml` compartilhado, esse arquivo viraria ticket `05` na
Fase 3, sequencial, depois dos dois.

## Rastreabilidade

| Decisão | Ticket |
|---|---|
| D-01 category deriva, não é editável | 01, 02 |
| D-02 backfill separado com revisão | 03 |
| D-03 section desconhecida vira OUTROS | 01, 02 |

Toda `D-NN` aparece em pelo menos um ticket. Decisão sem ticket é decisão órfã: a
spec decidiu e ninguém vai construir.
