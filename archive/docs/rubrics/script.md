---
rubric: script
threshold: 4
---

# Rubric — script

Aplica a: script CLI (one-shot ou recorrente via cron/launchd), automação local, glue entre sistemas. Exclui: lib chamada por outro código (use `feature-backend`).

## C1 — Idempotência

- **5:** rodar 2x produz mesmo estado final; sem duplicação, sem erro; transação ou check de "já feito" explícito
- **4:** rodar 2x não causa estragos (skip silencioso ou no-op); estado final correto
- **3:** rodar 2x pode duplicar dados mas com warning visível
- **2:** rodar 2x causa duplicação silenciosa
- **1:** rodar 2x corrompe estado

## C2 — Logging e observabilidade

- **5:** log estruturado (JSON ou key=value); níveis (info/warn/error); progresso em runs longas (`tqdm` ou batch counter); resumo final com métricas
- **4:** log em texto consistente; resumo final; erros distinguíveis
- **3:** `print` ad hoc; resumo no final; erros vão pro stderr
- **2:** logging só em erros; sem resumo
- **1:** silencioso; sem como debugar quando falha

## C3 — Tratamento de erro e estado parcial

- **5:** falha não-fatal isolada por item (continua próximo); falha fatal limpa estado parcial OU emite checkpoint pra retomar; retry com backoff em chamadas de rede
- **4:** falha por item logada e contada; resumo final mostra sucesso/falha; sem retry mas sem corromper
- **3:** primeira falha aborta; estado parcial possível
- **2:** sem tratamento; exception cai no terminal
- **1:** falha silenciosa (try/except pass)

## C4 — Reversibilidade / dry-run

- **5:** flag `--dry-run` mostra o que seria feito sem mutar; ação destrutiva exige confirmação ou flag explícita
- **4:** dry-run presente; sem confirmação em destrutivo mas com aviso no início
- **3:** sem dry-run mas script é facilmente abortável (Ctrl+C limpa) e leitura/cálculo dominam mutação
- **2:** sem dry-run; mutação destrutiva sem confirmação
- **1:** mutação destrutiva irreversível sem aviso

## C5 — Inputs e configuração

- **5:** inputs validados; CLI flags ou env vars documentados (`--help` funciona); defaults seguros
- **4:** flags presentes; help básico; defaults razoáveis
- **3:** flags/env vars hardcoded ou pouco documentados
- **2:** caminhos hardcoded; precisa editar script pra mudar config
- **1:** config espalhada em múltiplos lugares sem documentação

## Aceite

Score ≥ 4 em **todos** os critérios. Para scripts que **rodam em prod ou contra sistemas vivos** (Supabase, Notion, ERP), C4 ≤ 2 = `block`. Pra script one-shot descartável com escopo pequeno (≤50 linhas) e leitura pura, C2-C4 com threshold ≥ 3 (relaxado) é aceitável — declarar `rigor: leve` no frontmatter da spec/PR.
