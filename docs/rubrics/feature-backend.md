---
rubric: feature-backend
threshold: 4
---

# Rubric — feature-backend

Aplica a: nova feature de backend (endpoint, handler, pipeline, cron, módulo de domínio). Excluir: scripts one-shot (use `script`), mudanças de schema (use `schema-migration`).

## C1 — Acceptance criteria executável

- **5:** cada AC tem teste automatizado verde no CI; cobertura ≥80% do path crítico
- **4:** AC manuais demonstrados (log, request/response capturado, screenshot de smoke); cobertura ≥80%
- **3:** AC parcialmente cobertos (≥1 AC sem evidência OU cobertura <80%)
- **2:** AC descritos sem evidência de execução
- **1:** AC ausentes, ambíguos ou não-testáveis

## C2 — Evolve > create (anti-duplicação)

- **5:** estendeu artefato existente; zero dívida nova; consumidores não-tocados não veem diferença
- **4:** criou novo com justificativa registrada (Mini-ADR ou parágrafo na spec) cobrindo "boundary semântico distinto" ou "contrato de consumidor incompatível"
- **3:** criou novo sem justificativa explícita; semântica próxima a artefato existente
- **2:** criou paralelo a artefato existente (`_v2`, `_extended`) que cobre ≥70% do mesmo escopo
- **1:** divergência ativa de outro artefato (lógica vai drift)

## C3 — Cobertura do caminho crítico (TDD)

- **5:** red→green→refactor cumprido em cada slice; Prove-It em bugs (regressão antes de fix)
- **4:** testes 3 camadas (unit + integração + smoke) cobrem happy path + ≥1 edge case + ≥1 falha esperada
- **3:** unit + integração; sem smoke OU sem cenários de falha
- **2:** só unit; sem integração
- **1:** sem testes ou testes que não exercem o caminho crítico

## C4 — Tratamento de erro e estado consistente

- **5:** falhas mapeadas (input inválido, dependência fora, race condition); estado nunca fica parcial; transações onde aplicável
- **4:** principais falhas tratadas; estado consistente em casos esperados; logs informativos
- **3:** tratamento básico; alguns casos não-óbvios podem deixar estado inconsistente
- **2:** apenas happy path tratado; falhas exceptam pro caller sem contexto
- **1:** estado parcial possível em falha comum; sem logs úteis

## C5 — Security & input boundary (handlers externos)

Aplica quando feature recebe input externo (webhook, API pública, file drop, fila externa). Sem input externo: marca `n/a` e não conta no aceite.

- **5:** input validado em boundary (schema check); autenticação/autorização explícitas; secrets via vault/env; sem SQL injection / SSRF / path traversal possível
- **4:** validação básica; auth presente; secrets ok; ameaças conhecidas mitigadas
- **3:** validação parcial; auth presente mas papel/escopo não explícito
- **2:** input não validado em boundary; auth incompleta
- **1:** sem validação; secrets em código; vetores OWASP top-10 evidentes

## C6 — Rollback path

- **5:** rollback documentado e testado; feature flag OU revert seguro do commit
- **4:** rollback documentado; revert do commit é suficiente; sem estado corrompido em rollback
- **3:** rollback mencionado mas não testado
- **2:** rollback não documentado; revert tem efeito colateral conhecido
- **1:** mudança irreversível sem plano (ex.: migração de dados sem backup)

## C7 — Warnings de linter/type-checker no diff

Anti-pattern frequente: warning recorrente em arquivo tocado pelo diff que ninguém arruma, sessão após sessão. Vira broken window.

- **5:** zero warnings novos; warnings pré-existentes em arquivos tocados foram tratados (suppress inline com comentário, fix, ou config global) — cada um com decisão registrada
- **4:** zero warnings novos; warnings pré-existentes em arquivos tocados mencionados em FUP com decisão clara
- **3:** zero warnings novos; warnings pré-existentes deixados sem decisão registrada
- **2:** warnings novos introduzidos pelo diff
- **1:** warnings em arquivos do próprio diff deixados sem decisão (sintoma de "empurrar com a barriga")

## Aceite

Score ≥ 4 em **todos** os critérios aplicáveis (`n/a` não conta). C5 com score ≤ 2 em handler de input externo = `block` (não `iterate`); exige intervenção humana antes de continuar. C7 ≤ 2 = `iterate` obrigatório (não fecha sem decisão sobre warnings).
