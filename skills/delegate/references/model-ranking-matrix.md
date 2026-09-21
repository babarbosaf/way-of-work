# Prateleira de modelos e escolha manual

Complemento do `config/model-policy.json`, não cópia dele. A cascata por
task-type (`review`, `implement`, `scan`, `boilerplate`) mora **só** na policy,
porque duas listas da mesma cascata divergem. Aqui fica o que a policy não
carrega: a prateleira, a escolha manual e o fallback de sessão.

## A prateleira

Modelo bom implementa, mas **implementar bem não qualifica pra revisar**.

| prateleira | modelos | pode revisar |
|---|---|---|
| review e orquestração | `gpt-5.6-sol` high, `gpt-6-astra` low, Fable 5.1 low, Opus 5 high | sim |
| implement | `gpt-5.6-terra`, Sonnet 5, Claude Sonnet 4.6, Opus 4.6, Gemini 3.1 Pro | **nunca** |
| volume | Gemini Flash, GPT-OSS 120B, `gpt-5.6-luna` | **nunca** |

A lista de review é fechada e vive em `review_shelf.models` na policy, cobrada
por `tests/delegate.test.sh`. **Review não rebaixa:** esgotou a prateleira, a
cascata sai em exit 2 e o master revisa, nunca cai pro pool de implement.

Os modelos Claude entram na prateleira pelo backend `claude`, que é o `claude -p`
headless rodando na mesma assinatura da sessão. Ele é o último degrau de toda
cascata, e quem escolhe qual deles é o `review_pairing`: sessão em Fable revisa
com Fable, sessão em Opus revisa com Opus, sempre na classe do master. Esse
degrau compra contexto isolado, não resiliência de cota, porque quando o balde
seca a sessão e o headless falham juntos.

### Equivalência e esforço sugerido

Cada modelo roda no esforço sugerido dele, não no máximo que aceita.

| classe | Claude | codex | esforço |
|---|---|---|---|
| topo | Fable 5.1 | `gpt-6-astra` | low, e medium no teto |
| forte | Opus 5 | `gpt-5.6-sol` | high |
| média | Sonnet 5, Sonnet 4.6 | `gpt-5.6-terra` | medium |
| volume | Haiku | `gpt-5.6-luna` | low |

O benchmark de set/2026 sustenta o par sol e Opus 5 com uma ressalva que vale
guardar: eles empatam em Terminal-Bench 2.1, 88,8 contra 89,1, e o Opus 5 abre
79,2 contra 64,6 em SWE-bench Pro. Como SWE-bench Pro é justamente coisa de
repositório e vários arquivos, a equivalência vale no nível do modelo, e em
review multi-arquivo o Opus ainda leva.

Dois modelos ficam de fora da fila. O `gpt-5.5` é legado e o luna cobre o tier
dele por menos. O terra é dominado em Pareto pelo par luna e sol, porque pra
qualquer esforço do terra existe um esforço de luna ou de sol mais inteligente
pelo mesmo custo, ou igual por menos, então ele só aparece onde a classe Sonnet é
o alvo e nunca como degrau de volume.

## Atividade sem task-type na policy

Roteia direto por aqui. Regra: descer na linha da atividade, nunca pular pro
modelo melhor de outra linha, porque capacidade sobrando é quota desperdiçada.

| atividade | 1º | 2º | 3º |
|---|---|---|---|
| docs e redação técnica | agy Gemini 3.8 Flash (High) | agy Claude Sonnet 4.6 (Thinking) | agy Gemini 3.1 Pro (High) |
| infra mecânica (plist, shell simples, config) | agy Gemini 3.8 Flash (Medium) | agy GPT-OSS 120B (Medium) | codex `gpt-5.6-terra` (low) |

## Notas de operação

- **Bolsões do agy têm cota independente:** `gemini` (modelos da própria Google)
  e `claude_gpt` (Opus, Sonnet, GPT-OSS). O `claude_gpt` enche rápido e o
  `gemini` costuma ter folga, então em empate de capacidade prefira Gemini.
- **A janela do codex é de 5 horas**, e é ela que estoura, não o teto semanal.
  Custo marginal em dinheiro é zero no plano; o que se economiza é janela.
- **Fallback de sessão** só quando a task exige o harness Claude (tools, MCP,
  skills) ou a cascata externa esgotou. Nunca como primeira opção pra task que
  worker grátis resolve.
- **Não existe task-type de segunda opinião.** O advisor cobre o caso de
  conselho, o `review` cobre spec e código, e review delegada a modelo abaixo da
  classe do master é rebaixamento, não segunda opinião.
- **Claude Opus 4.6 (Thinking) está fora das cascatas do agy:** medido em
  07/set/2026, leva 902s e ainda volta rc=2 em headless, contra 26s do Sonnet 4.6
  e 30s do Gemini 3.1 Pro.
- **Sondagem vale pra data em que rodou.** Modelo que devolveu 404 ou 400 volta
  pra linha depois de `codex exec --model <m> "diga ok"` passar, e falha
  observada nunca vira `enabled: false` na policy.
- Mudança daqui pra cascata = editar `config/model-policy.json` direto. Git é o
  histórico.
