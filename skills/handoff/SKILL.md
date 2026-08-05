---
name: handoff
description: >
  Gera documento de handoff: estado transiente da sessão pra retomar trabalho em curso
  sem reabrir a conversa. Invoque quando o usuário disser "gera handoff", "vou compactar",
  "pausar por aqui", "retomo depois", ou quando compaction for iminente no meio de
  trabalho aberto (slice de spec, debug, investigação).
  Não invoque para: lição durável — memória/docs/PRD (capture-lessons), sessão que fechou
  tudo sem trabalho pendente.
---

# handoff

Estado transiente de trabalho em curso, num arquivo só. Fronteira dura com `capture-lessons`: handoff **não escreve em memória, docs, PRD ou TODOS.md**. Fato durável (causa raiz, anti-pattern, decisão técnica) que aparecer aqui → 1 linha de link no handoff + sugerir `/capture-lessons` na sequência. Nunca inlinar a lição.

## Destino (um só)

`_tmp/handoff-sessao-YYYY-MM-DD-<tema>.md` (gitignored). Se o trabalho em curso é
uma spec de `docs/specs/`, o handoff referencia a spec pelo path — não vira seção dela.

**Substitui, não acumula** — regenerar reescreve o arquivo. Morre quando absorvido: o cabeçalho declara a condição de morte ("apagar quando X absorver isto").

## Formato

```markdown
# Handoff — <tema> (YYYY-MM-DD)

> **Propósito:** <1-2 linhas>. **Morte:** <condição pra apagar>.

## Decisões da sessão (com evidência)
- <decisão + evidência: comando+output ou file:line>

## Fatos verificados contra ambiente real (não re-derivar)
## Gotchas que já batemos (+ workaround)
## Onde estamos
- <status atual, arquivos tocados>
## Próximo passo
- <ação concreta + critério de pronto>
## Como retomar
- <comandos/arquivos pra reabrir o contexto>
```

Seção vazia = omitir. Escrever pra um agente frio: sem referência a "acima"/"como discutimos", nomes completos, paths absolutos dentro do repo.
