# Lente D — higiene de docs e CLAUDE.md

Checar sempre, independe de a sessão ter editado os arquivos:

**Tamanho (alvos):**
- `CLAUDE.md` raiz ou `<depto>/CLAUDE.md`: **≤ 80 linhas**
- `AGENT.md` / `AGENTS.md`: **≤ 130 linhas**
- `departments.md`: **≤ 40 linhas**
- `MEMORY.md`: **≤ 200 linhas** (índice; alinhado ao hook `claude_md_size_guard`; override por projeto via env `MEMORY_MD_LINE_LIMIT`). Perto do teto → consolidar clusters em hubs `concept_*`, não relistar individualmente
- `CHANGELOG.md`: **vivo ≤ ~280 linhas** (alinhado ao hook `changelog_guard`). Acima → arquivar as entradas mais antigas pro período em `docs/changelog/`; não re-comprimir as antigas, só mover. Entrada nova deve ser ponteiro (o que mudou + ref de spec), não resumo da spec

Acima → propor `[OTIMIZAÇÃO]` com diff: mover detalhe histórico pra `docs/status-log.md` ou `docs/reference/`, deixar `@link` no lugar.

**INBOX.md:** virou log (seções datadas antigas, itens já resolvidos/no tracker) em vez de fila de achados frescos → `[LIMPEZA]`: deletar resolvido, backlog→item estruturado em TODOS.md/tracker, research→`docs/research/`, achado acionável→tracker.

**Duplicação:** linhas idênticas (>2 seguidas) entre `CLAUDE.md` raiz e `<depto>/CLAUDE.md`, ou entre `CLAUDE.md` e `AGENT.md` → tag `[LIMPEZA]`. Regra: conteúdo universal mora só em `AGENT.md`; depto-específico só no `<depto>/CLAUDE.md`.

**Status estagnado:** `## Status (YYYY-MM-DD)` com data > 30 dias → "Status estagnado, atualizar ou mover pra `docs/status-log.md`".

**TODOS.md hygiene:**
- `## Concluído > 20 items` → arquivar antigos em `docs/archive/TODOS-YYYY-MM.md`, manter os 10 mais recentes.
- Specs em `ongoing/` sem mtime > 60 dias (`find docs/specs/ongoing/ -mtime +60`) → `[LIMPEZA]`.
- One-pager linkado pela sessão entregue → conferir `status: built` + link pra `docs/specs/done/`.
