# Recipe · <Título>

- **Executor:** agente (sem humano no loop)
- **Última validação:** <YYYY-MM-DD>

> Recipe = procedimento que o agente executa sozinho, determinístico, sem
> julgamento humano. É o par do runbook: se o passo exige decisão humana, é
> runbook (`docs/runbooks/`), não recipe. Teste do executor-default: "um agente
> roda isto do começo ao fim sem perguntar nada?" Sim → recipe.
>
> Instâncias: `<slug>.md` (caixa baixa). Este arquivo é o molde.

## Quando usar

Gatilho e pré-condições (o que precisa estar verdadeiro antes).

## Passos

1. <comando exato ou ação determinística>
2. …

## Verificação

Asserção de máquina que confirma sucesso (exit 0, arquivo existe, count bate).

## Se falhar

O que o agente faz sozinho; quando escalar pra humano.
