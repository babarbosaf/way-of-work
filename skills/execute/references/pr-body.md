# Corpo da PR única

Uma PR por rodada. O corpo é o índice do que o revisor vai encontrar; o detalhe
mora nos tickets e na spec, linkados por URL cloud, nunca por path local.

```
## O quê

<2 a 3 frases: o comportamento novo, na linguagem do PRD>

Spec: <URL>   Brief: <slug>

## Tickets

| # | Título | Executor | verify |
|---|---|---|---|
| t01 | ... | codex | verde |
| t02 | ... | inline | verde |
| t05 | ... (novo na rodada) | agy | verde |

Desvios de rota: <uma linha por desvio, ou "nenhum">

## Docs vivos

- PRD.md: <seção>
- CONVENTIONS.md: <padrão>
- ADR: <arquivo, se houve>
(ou: "nenhum doc de produto mudou")

## Verificação

- verify_cmd: <comando> → <resultado>
- smoke_cmd:  <comando> → <resultado>
- /simplify:  rodado nos paths <...> | recusado pelo dono | não sugerido (<6 tickets)
- peer-review: <findings ou "não rodado">

## QA Manual

<link do ticket>. <N> cenários, <M> pendentes de validação humana.
```

Rodapé de atribuição conforme a `git-workflow-and-versioning`.
