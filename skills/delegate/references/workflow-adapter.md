# Adapter Workflow → delegate.sh

`Workflow.agent()` (tool nativo do Claude Code) só spawna modelos Claude
(sonnet/opus/haiku/fable) — não conhece `delegate.sh`. Se um stage de
`Workflow.pipeline()`/`Workflow.parallel()` for delegável (task-type já
mapeado em `~/.claude/config/model-policy.json`), deixar o `Workflow`
spawnar Claude direto pra esse stage viola D-01 (custo zero primeiro,
SPEC-2026-002) — o stage roda pago quando um worker grátis resolvia.

## Como rodar um stage delegável dentro de Workflow

Dentro do `agent()` daquele stage, o próprio agente Claude spawnado deve
invocar `delegate.sh` via `Bash` em vez de resolver a tarefa ele mesmo:

```js
const result = await agent(`
Rode exatamente este comando via Bash e retorne o stdout dele, sem reprocessar:

~/.claude/scripts/delegate.sh --task scan - <<'EOF'
<prompt da tarefa deste stage>
EOF

Se o exit code for 2 (cascata esgotada), resolva a tarefa você mesmo inline
e diga isso explicitamente no retorno.
`, { phase: 'Scan', label: 'stage-delegavel' })
```

O agente spawnado pelo `Workflow` age como um wrapper fino: chama o
dispatcher, devolve o resultado. Só assume a tarefa por conta própria se
`delegate.sh` sair com exit 2 (cascata esgotada) — nunca decide "vou fazer
melhor eu mesmo" com a cascata ainda disponível.

## Paralelismo

`Workflow.parallel()`/`pipeline()` pode disparar múltiplos stages
delegáveis ao mesmo tempo, cada um chamando `delegate.sh` numa chamada
`Bash` concorrente — sem cap fixo pra coordenar entre chamadas, isso é
seguro por padrão. Prioridade vem só da ordem da cascata em cada task-type
(a matriz); se um backend rejeitar de verdade (rate limit), ele entra em
cooldown e a cascata daquela chamada específica desce pro próximo — outras
chamadas concorrentes não são afetadas até tentarem o mesmo backend.

## Quando NÃO usar este adapter

- Stage sem task-type mapeado na policy (decisão de arquitetura, síntese
  entre resultados de outros stages, integração de código) — isso é core
  do orquestrador, roda Claude direto, sem passar por `delegate.sh`.
- Stage que precisa de tools/MCP/skills do harness Claude que os CLIs
  externos não têm — ver seção "Delegação interna — subagentes Claude" no
  `SKILL.md` principal.
