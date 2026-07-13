# Checklists — spec-and-plan

## Checklist obrigatório para pipelines / handlers / endpoints

Se a feature envolve endpoint, cron, handler de input externo ou state pending, exigir resposta explícita (cada uma vira premissa na spec **antes** de virar código):

- [ ] **Idempotência** — invocável N vezes com o mesmo payload sem efeito duplicado? Se não, qual a chave de dedupe e onde persiste?
- [ ] **TTL e scope do state pending** — quanto tempo vale? Quem limpa (TTL, ack, GC)? Scope por-usuário/thread/global?
- [ ] **Persistência do state pending** — sobrevive a restart? Onde mora? Carrega no startup? (Estado em memória do processo se perde em restart.)
- [ ] **Política de falha encadeada** — se a etapa N falha, o que acontece com 1..N-1? Rollback, retry com backoff, ou parcialmente concluído?
- [ ] **Ambiente de execução vs origem do gatilho** — onde o código roda (local, CI, serverless) e de onde vem o gatilho (cron, evento, webhook)? Confirmar que o ambiente consegue receber o gatilho (ex.: job em nuvem não dispara processo local; processo local não reage a evento de cloud).
