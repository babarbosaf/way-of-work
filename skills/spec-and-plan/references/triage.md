# triage — finding/bug → destino + state

**Fronteira MECE:** triage **roteia e seta o state**; não escreve template (isso é `to-tickets.md`), não enriquece corpo (isso é `refine.md`), não recria severidade (isso é ship-review §4 — triage **consome**). Task→worker é `delega:`.

## Quando roda

- Finding do ship-review / findings/pass-N.md que precisa virar trabalho endereçado.
- Bug/pedido que chega solto (sem spec). Issue pode viver sem spec — não force vínculo.

## State machine (1 category + 1 state por issue — invariante)

**Category (exatamente 1):** `bug` (quebrado) · `enhancement` (novo/melhoria).

**State (exatamente 1):**
```
needs-triage ──► needs-info ──► ready-for-agent   (autocontida, delegável → loop/delegate pega)
     │              │      └──► ready-for-human    (precisa decisão/mão humana)
     │              └──(reporter responde)──► needs-triage
     └──────────────────────► wontfix              (rejeitado / já resolvido)
```
`ready-for-agent` = `executable_states` do `project.yaml` que loop/delegate consome. Conflito de state = flag de escalação antes de qualquer ação.

## Passos

1. **Gather** — ler o item inteiro; checar notas de triagem prévias; grep no codebase por redundância; **scan de rejeições prévias** (`findings/` fechados, `.out-of-scope/` se existir) pra não re-triar lixo já morto.
2. **Recommend** — propor category + state + destino, com razão. Aguardar direção se ambíguo.
3. **Verify-claim** — bug: **reproduzir** antes de aceitar. PR/finding: confirmar que o diff/sintoma bate com o alegado. Não-reproduzível → `needs-info`, não `ready-*`. Mata issue-fantasma.
4. **Enrich (se magro)** → handoff pra `refine.md`; volta em `ready-*` quando executável.
5. **Apply** — criar issue via writer de `to-tickets.md` (template + backend do `project.yaml`) + aplicar labels de category/state.

## Destino — `finding_routing` no `model-policy.json`

O tipo do finding roteia pra onde e pra quem:

| dimensão | resolve |
|---|---|
| **repo alvo** | mesmo repo, ou repo independente (ex.: parser/upload → `<repo-de-dados>`, não o repo de app) |
| **tracker** | `tracker.backend`/`tech`/`nontech` do repo alvo |
| **executor** | `delega: <task-type>` → cascata; ou `ready-for-human` se precisa decisão |

Regra: finding não morre em arquivo local. `findings/pass-N.md` é handoff de contexto; o **item acionável** vira issue no tracker do executor certo (via to-tickets), com link cloud pro finding se a spec estiver commitada.

## Consome severidade, não recria

ship-review §4 já classifica **Critical/Important/Suggestion** (block ou não). triage lê essa severidade → vira `priority` (Critical→P0, Important→P1, Suggestion→P2) e decide state. Não reescrever a tabela de severidade.
