---
title: <título do estudo>
type: benchmark            # benchmark | paper | article | guide | source-copy | experiment
date: <YYYY-MM-DD>
source: <URL ou citação>   # vazio se for produção interna
canonical: false           # true = esta cópia local é a fonte recuperável (ex.: URL responde 403)
tags: [<tag-1>, <tag-2>]
status: active             # active | superseded | archived
summary: <1 linha — é o que aparece no índice RESEARCH.md>
---

# <Título do estudo>

> Indexado por [../../RESEARCH.md](../../RESEARCH.md). O frontmatter acima é o
> que torna o acervo consultável (grep por `type:`, `tags:`, `status:`).
>
> Instâncias: `<YYYY-MM>-<slug>.md` (caixa baixa). Este arquivo é o molde.

## Propósito

Por que este estudo existe e que decisão ele alimenta. Insumo de debate ou
referência fechada? Deixe claro.

## Conteúdo

O estudo em si: achados, benchmarks, trechos da fonte. Para `source-copy`,
cole o material e marque `canonical: true` se for a única cópia recuperável.

## Conclusões / aplicação

O que tiramos disto pro produto. Se virou decisão, linka o ADR ou a spec.
