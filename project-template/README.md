# <projeto>

> **Papel:** porta de entrada do repo — o que é, como rodar, como está
> organizado. Instrução viva pra humano; não guarda histórico (→ `CHANGELOG.md`)
> nem decisão (→ `docs/conventions/adrs/`).

<uma linha: o que este projeto faz e pra quem.>

## Rodar

```bash
<comando de setup + comando de dev>
```

## Organização

| Doc | Papel |
|-----|-------|
| [`STRATEGY.md`](STRATEGY.md) | Por que este projeto existe — o norte. |
| [`PRD.md`](PRD.md) | O quê — requisitos por sistema (índice em `docs/prd/`). |
| [`CONVENTIONS.md`](CONVENTIONS.md) | Como — padrões de código e trabalho. |
| [`RESEARCH.md`](RESEARCH.md) | Insumo de pesquisa (índice de `docs/research/`). |
| [`RUNBOOK.md`](RUNBOOK.md) | Operação com humano no loop. |
| [`docs/`](docs/) | ADRs, DDRs, specs, runbooks, recipes, research. |
| [`.claude/project.yaml`](.claude/project.yaml) | Metadata que as skills leem. |

Doutrina do modelo de trabalho: `docs/way-of-working.md` (se você adotou o
way-of-work) explica as cadeias entre estes docs.
