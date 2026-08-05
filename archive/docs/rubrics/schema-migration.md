---
rubric: schema-migration
threshold: 4
---

# Rubric — schema-migration

Aplica a: mudança de schema em DB (Supabase/Postgres principalmente), migração de tabela, alteração de tipo, rename, drop. Inclui mudança de view/matview que rompe contrato. Exclui: criar tabela nova vazia consumida só por código que nasce junto (use `feature-backend`).

## C1 — Backward compat (read-old + write-new)

- **5:** migração em fases: write-both → backfill → read-new → drop-old. Cada fase shippa independente; rollback possível em qualquer ponto
- **4:** write-new compatível com leitores antigos por janela transitória (default value, nullable, view de espelhamento)
- **3:** write-new exige update simultâneo dos consumidores; janela curta de incompat
- **2:** breaking change sem janela; consumidores quebram até atualizarem
- **1:** breaking change sem comunicação aos consumidores existentes

## C2 — Performance da migração (lock time)

- **5:** medido tempo de migração em volume prod-like; lock <1s OU usado approach lock-free (CREATE INDEX CONCURRENTLY, batch updates)
- **4:** tempo medido em staging com volume comparável; lock aceitável pra janela de manutenção planejada
- **3:** tempo medido em dev; assumido extrapolável; sem janela explícita
- **2:** sem medida de tempo; assumido "rápido"
- **1:** known long-running em volume prod sem mitigação

## C3 — Rollback path testado

- **5:** rollback é uma migration reversa (down) que foi executada e validada; estado idêntico ao pré-migração
- **4:** rollback documentado em SQL/script; testado em staging
- **3:** rollback descrito em prosa; sem teste
- **2:** rollback implícito ("revert + restore backup"); sem plan concreto
- **1:** sem rollback; "se quebrar, restaurar backup" sem testar

## C4 — Test contra prod-like data

- **5:** dry-run em snapshot recente de prod; resultado validado por query de sanity (contagens, agregados antes/depois)
- **4:** dry-run em staging com volume e distribuição comparável; sanity checks ok
- **3:** dry-run em dev com seed limitado; sanity manual
- **2:** sem dry-run; depende de unit test do migration runner
- **1:** primeira execução = prod

## C5 — Comunicação e descoberta

- **5:** RFC ou ADR antes; descrição do PR inclui impacto em consumidores conhecidos + diff de schema; PR linka issues afetados
- **4:** descrição do PR cobre impacto e diff; sem RFC mas decisão registrada na spec
- **3:** descrição do PR genérica; impacto não mapeado
- **2:** PR só com código; sem contexto
- **1:** mudança merged sem PR review

## C6 — Reconhecimento dinâmico (anti-hardcode)

Anti-pattern frequente em migrações: assumir lista de objetos hardcoded em vez de enumerar via `information_schema`. Crítico em scripts de baseline/equivalência.

- **5:** enumeração dinâmica de objetos (tabelas, views, matviews, índices); sem lista hardcoded; versão real do servidor lida em runtime
- **4:** enumeração dinâmica em maioria; lista hardcoded só pra objetos congelados (frozen contract)
- **3:** mistura de dinâmico e hardcoded; risco de drift
- **2:** lista hardcoded predominante; novo objeto não entra
- **1:** lista hardcoded + assume versão do servidor da config local

## Aceite

Score ≥ 4 em **todos** os critérios. C1 ou C3 ≤ 2 = `block` (não shippa sem backward compat + rollback). C2 ≤ 2 em DB com volume >1M linhas = `block`.

## Notas

- Memória `infra/migração de schema` no `~/.claude/CLAUDE.md` cobre o princípio de "reconhecimento dinâmico do ambiente antes" — C6 codifica isso.
- Esta rubric é tipicamente o gate mais duro do harness. Se a spec é trivial (renomeio de coluna não-usada), declarar `rigor: leve` e relaxar threshold pra ≥3.
