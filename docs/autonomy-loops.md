# Autonomia — loops e stop-condition

Doutrina de trabalho autônomo confiável. Ref: Anthropic, "Getting started with loops". Ponteiro vivo em `~/.claude/CLAUDE.md`.

## Escada de autonomia (subir por degrau, nunca pular)

| Degrau | Trigger | Stop | Uso |
|--------|---------|------|-----|
| turn-based | prompt manual | agente julga pronto | exploração curta, direção manual |
| `/goal` | prompt manual | exit determinístico OU max turns | tarefa com critério verificável |
| `/loop` | intervalo agendado | cancelamento OU trabalho done | recorrente, poll de sistema externo |
| `/schedule` (proativo) | evento/cron, sem humano | goal da tarefa; roda até desabilitar | fluxo recorrente bem-definido |

Subir de degrau só quando o de baixo provou confiável no mesmo tipo de tarefa.

**`/schedule` é cloud (CCR), não local.** Roda sessão Claude Code isolada na infra Anthropic: (a) **consome cota de plano** — a mesma que `delegate`/D-01 poupa; (b) **sem acesso a estado local** (`~/.claude/`, CLIs `codex`/`agy`, arquivos da máquina). Task local-bound não vira `/schedule`. "Fora do Mac + $0 Anthropic" = GitHub Actions (cron grátis) ou runner self-hosted com CLIs free, não CCR.

## Stop-condition é máquina, não juízo do agente

Exit de loop = sinal runnable que **já existe** no setup, não "achei que ficou bom":
- **`verify_cmd`** / `## Verify` do slice — fallback chain do `spec-and-plan` (roda o aceite do slice; exit 0 = pronto).
- **suite-verde** — `test-and-debug`, handoff observável `suite=green`.
- **`smoke_cmd`** — `.claude/project.yaml`, obrigatório verde quando o diff toca `pipeline_paths`.

Sem comando runnable de aceite, **não abre loop** — volta pra turn-based. Critério subjetivo (SIM/NÃO comportamental na spec) é pro humano assinar; o loop precisa do comando que checa aquele critério.

## Invariantes de todo loop autônomo

1. **Turn cap explícito** — "para após N tentativas". Sem cap = runaway de token.
2. **Exit quantitativo** — exit 0 / N testes passam / threshold numérico. Nunca depender só do juízo do agente pra sair (nem premature exit, nem loop infinito).
3. **Piloto em 1 slice antes de escalar** — workflow/rotina que fan-out pode spawnar dezenas de agentes; rodar no escuro custa caro. Piloto → medir com `/usage` → escalar.
4. **Cadência casa com frequência de mudança** — poll de sistema externo só na taxa em que o estado muda. Não rodar rotina mais que o necessário.

## Gate de saída = mecanismo existente, não paralelo

Antes de ship unattended, o segundo-par-de-olhos já é do `ship-review`:
- **Evaluator** (`peer-review.sh {spec|diff}`) — contexto fresco, menos viés. Teto 1 round spec + 1 diff.
- **`simplify`** sobre o diff — eixo obrigatório, captura abstração prematura.

**Não spawnar reviewer novo** (ex. `cavecrew-reviewer`) como gate — duplica o Evaluator. Evoluir>criar.

## Custo: corpo mecânico vs julgamento

Modelo + effort são o **maior lever** de custo de loop.
- **Corpo do loop** (iteração, scan, boilerplate, implement mecânico) → `delegate` (free tier: codex/agy/Gemini/GPT-OSS, D-01 do `model-policy`), effort baixo.
- **Julgamento** (design de spec, veredito de ship, decisão de arquitetura) → fica na sessão Claude, effort alto.
- Script determinístico > raciocinar passo repetitivo. Encode o check, não re-derive.

**Gap de config aberto (rotear via `/refresh-model-rankings`, não hand-edit):** `model-policy.json` ainda não expressa dimensão `effort` por task nem um tier nomeado "loop-body". Propor via governança do arquivo (proposta aprovada + histórico), não editar direto.

## Piloto proativo sugerido

`refresh-model-rankings` — já nasceu pra cadência quinzenal, é read-only + proposal-only (risco ~zero unattended), trigger externo (lançamento de modelo), done binário (propôs diff / nada mudou). Primeiro candidato a virar `/schedule` + `/goal` quando a doutrina acima provar valor.
