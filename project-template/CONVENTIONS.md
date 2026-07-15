# CONVENTIONS

> **Papel:** como se trabalha aqui — padrões de código, estrutura, nomes,
> testes, commits, review. A cauda da espinha de produto (o "como"). Regra viva;
> decisão pontual com trade-off vai pra `docs/conventions/adrs/`.

## Stack

<linguagens, frameworks, ferramentas. Versões que importam.>

## Arquitetura e estrutura de código

<desenho geral: componentes, fluxo de dados, fronteiras de módulo. ASCII quando
ajuda. Visão macro e estrutura vivem aqui — não há `docs/architecture/` separado.>

## Nomes e estilo

<convenções de nome, formatação, lint. O linter é a fonte, isto é o porquê.>

## Testes

<pirâmide, o que exige teste, comando (espelha `verify_cmd` do project.yaml).>

## Commits e branches

<atomic commits, trunk-based, formato de mensagem. Espelha
`git-workflow-and-versioning` se você adotou o way-of-work.>

## Review

Checklist de gate deste repo: o que **reprova** merge, binário, não conselho.
Destinada ao gate de ship (`ship-review`) como checklist Critical do repo. Corta o
que o CI/lint já pega. Vazio até existir gate real — não encher de aspiração.

- **Severidade:** <o que é Critical *aqui*. Default mira prod; recalibre pra
  docs/protótipo/config.>
- **Sempre checar:** <invariantes duros do domínio. Ex.: rota nova = teste de
  integração; tabela nova = RLS; sem segredo no diff; regra de negócio fora da
  camada errada.>
- **Skip:** <o que outra automação já garante (lint, type, format) — não
  re-reportar.>

## Specs

Trabalho que exige design vira spec-folder em
`docs/specs/ongoing/spec-YYYY-NNN-<slug>/` (copie `docs/specs/_TEMPLATE-spec/`).
Uma spec, uma versão — histórico do gate na própria spec, não em arquivos
`round-N`. Ao fechar: mover pra `done/`, PRD vira a verdade, CHANGELOG registra,
porquê estrutural vira ADR.

## Registro de tarefas

O backend de tracker (`github`/`notion`/`linear`/`none`) é declarado em
`.claude/project.yaml`. As fatias da spec viram tasks lá; o tracker guarda só o
status vivo, docs não re-narram.

## Como estender

Receita reproduzível de "construir mais do mesmo" (adicionar fonte, módulo, tela)
vai pra `docs/conventions/recipes/`. Ritual que exige julgamento humano vai pro
`RUNBOOK.md`. Teste: "o agente faz sozinho?" — sim = recipe, não = runbook.

## Decisões registradas

Padrão novo com trade-off não-óbvio → ADR em `docs/conventions/adrs/`. Esta
página guarda a regra estável; o ADR guarda o porquê da escolha. ADR fechado é
imutável — revogação é ADR novo que referencia o antigo.

| ADR | Decisão | Status |
|---|---|---|
| adr-0001 | … | proposto |
