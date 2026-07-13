# PRD

> **Papel:** fonte da verdade funcional do produto (índice dos sistemas). O
> por quê está em [STRATEGY.md](STRATEGY.md); o front-end em [DESIGN.md](DESIGN.md)
> e a navegação em [ROUTES.md](ROUTES.md); o como técnico em
> [CONVENTIONS.md](CONVENTIONS.md). Não é decision log — história no
> [CHANGELOG.md](CHANGELOG.md); mudança de contrato passa por spec em `docs/specs/`.

## Visão geral

<o produto em 1 parágrafo funcional.>

## Modelo de domínio

<entidades cross-sistema e como se relacionam.>

## Mapa de sistemas

Cada sistema tem seu PRD em `docs/prd/<sistema>.md` (copie `_TEMPLATE-SISTEMA.md`).

| Sistema | Papel | PRD |
|---------|-------|-----|
| <sistema> | <uma linha> | [docs/prd/<sistema>.md](docs/prd/<sistema>.md) |

## Contratos não-funcionais cross-cutting

<performance, freshness, segurança que valem pra todos os sistemas.>

## Norte de evolução (não-MVP)

<pra onde caminha depois do escopo atual.>

## Open questions

<o que ainda está em aberto no produto.>
