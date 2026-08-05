# AGENTS.md — <projeto>

> **Papel:** instrução viva pro agente neste projeto. Override local: só o que é
> específico daqui. A doutrina geral (ciclo, gates, memória) vem do way-of-work
> user-level; não a repita. `CLAUDE.md` é symlink pra este arquivo.

## Contexto do projeto

<1-2 linhas: o que é, stack principal. Detalhe em CONVENTIONS.md e PRD.md.>

## Mapa de documentos

| Você vai... | Leia antes | Atualize depois |
|---|---|---|
| mexer no escopo/comportamento de um sistema | [PRD.md](PRD.md) + `docs/prd/<sistema>.md` | o `docs/prd/<sistema>.md` afetado |
| mexer no que o usuário consome | [DESIGN.md](DESIGN.md) | DESIGN.md; DDR em `docs/design/` se não-óbvia |
| tomar decisão técnica/estrutural | [CONVENTIONS.md](CONVENTIONS.md) | novo ADR em `docs/conventions/adrs/` |
| rodar ritual operacional | [RUNBOOK.md](RUNBOOK.md) | o runbook se o passo mudou |
| consultar benchmark/referência | [RESEARCH.md](RESEARCH.md) | novo estudo em `docs/research/` |
| definir/priorizar uma frente | [STRATEGY.md](STRATEGY.md) | STRATEGY.md |
| propor mudança de contrato | [docs/specs/](docs/specs/) | spec-folder em `ongoing/`; ao fechar, PRD + CHANGELOG + ADR |

> Metadata de skill (tracker, trunk, verify) em [.claude/project.yaml](.claude/project.yaml).

## Regras específicas deste projeto

<só o que difere do modelo geral. Ex.: "nunca rodar migração sem backup",
"toda rota nova entra em ROUTES.md". Vazio se não há override.>
