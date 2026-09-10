# Atualização de ticket por backend

Ticket é a fonte da verdade da execução. Comentário entra **no momento**, não no
fim: compaction no meio da rodada não pode perder rota.

## Três momentos, mesmo conteúdo em todo backend

| Momento | Conteúdo |
|---|---|
| iniciado | executor (worker ou inline), branch, SHA base |
| desvio | o que mudou de rota e por quê; ticket novo criado, se houve |
| fechado | o que fechou, `verify` rodado e resultado, aceite marcado, commit/merge |

Uma linha por evento, sem prosa. Formato:

```
YYYY-MM-DD <momento>: <conteúdo>
```

## Backend `none` (arquivo em `docs/specs/<slug>/tickets/`)

Header ganha `status:` (`ready | em curso | bloqueado | done`). Eventos vão numa
seção `## Log` no fim do arquivo, append-only. Aceite marcado no próprio checklist.

```
status:     em curso

## Log
2026-09-10 iniciado: worker codex, delegate/t01-category-dtr, base a1b2c3d
2026-09-10 fechado: uv run pytest tests/ingest -q verde (14 passed); merge em feature/category-derivada
```

## Backend `github`

`gh issue comment <n> --body "<linha>"`. Estado por label:
`ready-for-agent → in-progress → done`, e `gh issue close` no fechamento com
referência ao commit de merge. Ticket novo: `gh issue create` com o template do
`to-tickets` e `blocked_by` na relação nativa.

## Backend `linear`

MCP Linear: `save_comment` para o evento, `save_issue` para estado. Ticket novo
herda team, project e labels do ticket que o originou.

## Backend `notion`

MCP Notion: comentário na página (`notion-create-comment`), estado na property
de status (`notion-update-page`). Ticket novo no `tasks_db` com a mesma relação
(repo ou KR) do ticket de origem. Sem jargão de repo no texto: quem lê é humano.

## Spec

Mapa de slices reflete a realidade ao final de cada leva: ticket novo entra como
linha, ticket cancelado sai com motivo em uma linha. `D-NN` novo só quando a
decisão muda desenho, não pra registrar rota de implementação.
