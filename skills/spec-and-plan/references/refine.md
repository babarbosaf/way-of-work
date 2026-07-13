# refine — item magro → executável

**Fronteira MECE:** refine **enriquece o corpo** até dar pra executar sem contexto. Não roteia (triage), não escreve o template de tracker (to-tickets), não classifica severidade (ship-review). É a **ação** que avança o state `needs-info → ready-for-agent` da máquina de estados do `triage.md`.

## Alvo: executabilidade, NÃO spec-linkage

Objetivo único: alguém (agente ou humano) sem o contexto da conversa **consegue implementar** só lendo a issue. Vincular a uma spec **ajuda investigação, mas é bônus opcional** — issue sem spec não é problema, não gaste esforço forçando o vínculo.

## Quando roda

Issue em `needs-info` / backlog magro: título + sintoma, mas sem contrato fechado. Bug que chegou solto, ideia jogada, task cortada grossa demais.

## O que preencher (a barra do `ready-for-agent`)

- **O que construir/consertar** — comportamento observável end-to-end, não palpite de implementação.
- **Aceite SIM/NÃO** — 2-3 checkpoints verificáveis. Sem isso não é executável.
- **Arquivos-hint** por URL cloud (onde mexer, pista).
- **verify** — como provar que fechou (`verify_cmd`, repro do bug).
- **Repro** (se bug) — passos mínimos que disparam. Sem repro → fica em `needs-info`, não sobe.
- **Escopo/fora-de-escopo** — o que NÃO é pra tocar, pra não vazar.

## Grill quando ambíguo

Termo de domínio vago ou requisito dúbio → perguntar dirigido (1 rodada), afiar, então subir pra `ready-for-agent`. Não subir item com ambiguidade que faria o executor errar — o custo de um `needs-info` a mais é baixo; o de um executor perdido é alto.

## Pronto quando

Passa o teste: "um executor frio implementaria isso certo só com a issue?". Sim → `ready-for-agent` (ou `ready-for-human` se exige decisão). Não → continua em `needs-info`.
