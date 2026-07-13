**Repo modelo-v2** (`docs/prd/` + `CONVENTIONS.md`): além do acima, roteia decisão pro doc certo, não só pra memória.

| Tipo (modelo-v2) | Destino |
|---|---|
| Decisão de produto/escopo | Propor edição no `docs/prd/<sistema>.md` (a nova verdade) |
| Decisão técnica/estrutural | Propor ADR novo em `docs/conventions/adrs/` |
| Decision log indevido num doc pai (PRD/CONVENTIONS/STRATEGY) | Propor mover pro `CHANGELOG.md` |

Repo legado (sem o modelo): roteamento atual, sem esta tabela.

**Projeto com loop de design** (`DESIGN.md` + lint/evals/exemplars; ver DDR do loop de design): roteia o achado de design pro artefato certo, não só pra memória.

| Tipo (loop de design) | Destino |
|---|---|
| Regra de UI determinística violada de novo | Regra nova no lint de design (ESLint/CLI), não só memória |
| Craft de tela notável (bom exemplo a repetir, ou erro a evitar) | Entrada em `docs/design/exemplars.md` |
| Lacuna de capacidade de gerar UI certa (agente erra em tela nova) | Fixture novo na malha de evals de design |
| Regra de design nova e estável | `DESIGN.md` (a regra viva); o porquê vira DDR |

Projeto sem loop de design: sem esta tabela.
