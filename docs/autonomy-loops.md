# Autonomia, loops e stop-condition

Doutrina de trabalho autônomo confiável. Ref: Anthropic, "Getting started with loops". Ponteiro vivo em `~/.claude/CLAUDE.md`.

## Escada de autonomia (subir por degrau, nunca pular)

| Degrau | Trigger | Stop | Uso |
|--------|---------|------|-----|
| turn-based | prompt manual | agente julga pronto | exploração curta, direção manual |
| `/goal` | prompt manual | exit determinístico OU max turns | tarefa com critério verificável |
| `/loop` | intervalo agendado | cancelamento OU trabalho done | recorrente, poll de sistema externo |
| `/schedule` (proativo) | evento/cron, sem humano | goal da tarefa; roda até desabilitar | fluxo recorrente bem-definido |

Subir de degrau só quando o de baixo provou confiável no mesmo tipo de tarefa.

**`/schedule` é cloud (CCR), não local.** Roda sessão Claude Code isolada na infra Anthropic: (a) **consome cota de plano**, a mesma que `delegate`/D-01 poupa; (b) **sem acesso a estado local** (`~/.claude/`, CLIs `codex`/`agy`, arquivos da máquina). Task local-bound não vira `/schedule`. "Fora da máquina local + $0 Anthropic" = GitHub Actions (cron grátis) ou runner self-hosted com CLIs free, não CCR.

## Stop-condition é máquina, não juízo do agente

Exit de loop = sinal runnable que **já existe** no setup, não "achei que ficou bom":
- **`verify_cmd`** ou `## Verify` do slice. Roda o aceite do slice; exit 0 = pronto.
- **suite-verde.** Suite completa do projeto retorna 0.
- **`smoke_cmd`.** Em `.claude/project.yaml`, obrigatório verde quando o diff toca `pipeline_paths`.

Sem comando runnable de aceite, **não abre loop**, volta pra turn-based. Critério subjetivo (SIM/NÃO comportamental na spec) é pro humano assinar; o loop precisa do comando que checa aquele critério.

## Invariantes de todo loop autônomo

1. **Turn cap explícito.** "para após N tentativas". Sem cap = runaway de token.
2. **Exit quantitativo.** Exit 0, N testes passam, threshold numérico. Nunca depender só do juízo do agente pra sair (nem premature exit, nem loop infinito).
3. **Piloto em 1 slice antes de escalar.** Workflow ou rotina que fan-out pode spawnar dezenas de agentes; rodar no escuro custa caro. Piloto → medir com `/usage` → escalar.
4. **Cadência casa com frequência de mudança.** Poll de sistema externo só na taxa em que o estado muda. Não rodar rotina mais que o necessário.

## Gate de saída = mecanismo existente, não paralelo

Antes de ship unattended: suite verde + `/simplify` sobre o diff; se o diff toca prod ou é caro de reverter, rodar também `peer-review.sh diff` (segunda opinião, `docs/adversarial-evaluator.md`). **Não spawnar reviewer novo** paralelo; duplica o Evaluator. Evoluir>criar.

## Custo: corpo mecânico vs julgamento

Modelo + effort são o **maior lever** de custo de loop.
- **Corpo do loop** (iteração, scan, boilerplate, implement mecânico) → `delegate` (free tier: codex/agy/Gemini/GPT-OSS, D-01 do `model-policy`), effort baixo.
- **Julgamento** (design de spec, veredito de ship, decisão de arquitetura) → fica na sessão Claude, effort alto.
- Script determinístico > raciocinar passo repetitivo. Encode o check, não re-derive.
