# Auto-memória

Mecânica do que o `AGENTS.md` resume em quatro regras. A memória vive por projeto, em
`~/.claude-maracaja/projects/<slug>/memory/`.

## O log vem antes

Toda criação ou edição de memória exige append em `memory/log.md`, e o hook
`memory_log_append.py` recusa a escrita sem ele. Header de uma linha:

```
## [YYYY-MM-DD] <op> | <basename> (session=<id>)
```

`<op>` é `create`, `update`, `delete`, `lint` ou `ingest`.

## Uma memória por arquivo

Frontmatter com `name`, `description` e `metadata.type`. O `description` é o que decide
relevância no recall, então descreve o gatilho, não o assunto. Tipos: `user` (quem é a
pessoa), `feedback` (como trabalhar, com o porquê), `project` (trabalho em curso, datas
absolutas), `reference` (ponteiro externo).

O nome carrega prefixo por natureza: `concept_`, `feedback_`, `gotcha_`, `project_`,
`pattern_`, `antipattern_`, `reference_`, `user_`. No corpo, `[[nome]]` liga memórias, e
link pra memória que ainda não existe marca o que vale escrever depois.

## Índice hub-first

`MEMORY.md` é índice, não conteúdo, e carrega só hubs mais o cross-cutting sem hub
natural. Atômica nova é referenciada no hub `concept_*` do tema, nunca numa lista de
órfãs. Atômica coberta por hub não repete linha, porque o recall já a alcança. Três ou
mais atômicas sobre o mesmo tema sem hub pedem um hub.

Teto de ~40 linhas. Estourou, dobra órfã em hub; relaxar o teto devolve o problema
maior um mês depois.

## O que não vira memória

O que o repo já registra (estrutura de código, git, `CLAUDE.md` do projeto) e o que só
importa nesta conversa. Lição de um projeto só vai pro `FEEDBACK.md` dele; memória é pra
lição cross-projeto.

## Precedência

`AGENTS.md` acima de memória. Memória que conflita se corrige ou se arquiva na hora, e
memória que cita arquivo, função ou flag se verifica antes de virar recomendação: ela
reflete o que era verdade quando foi escrita.
