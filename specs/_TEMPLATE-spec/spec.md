---
name: spec-YYYY-NNN-<slug>
status: draft            # draft | aprovado | done
rigor: padrão            # leve | padrão | governança
rubric: feature-backend  # resolve em docs/rubrics/<nome>.md
threshold: 4
verify_cmd: "<comando que roda o aceite dos slices>"
---

# spec-YYYY-NNN — <título>

> Uma linha: o problema e a mudança. Se há PRD, linkar a seção
> (`docs/prd/<sistema>.md#...`) em vez de reescrever o contexto.

## 1. Contrato

### Como fica

```
ANTES                      DEPOIS
─────────────              ─────────────
<estado atual>             <estado pós-ship>
```

Fluxo antes → depois em ASCII estreito (≤40 colunas), linguagem de negócio.
Cada ramo do "depois" é a fonte única de um user journey em §2.

### Decisões

**D-01 — <título>.** O que foi decidido, por quê, e o trade-off aceito.
Parágrafo direto, sem template formulaico. Toda `D-NN` aparece em ≥1 slice.

### Critérios de aceite

- SIM: <o que o sistema faz, em comportamento — não SQL nem função>
- NÃO: <o que explicitamente não acontece>

### Fora de escopo

- <o que não entra, 1 linha cada>

## 2. Design técnico

### Mudanças (por slice, ver §3)

<o que será construído. Sub-seção "Contratos com sistemas externos" quando
a mudança emite/consome evento/registro em outro componente; senão N/A.>

### Mini-ADR

<opções · escolha · porquê + alternativas descartadas (tradeoff / quando
seria certa / decisão). Dispara com >1 caminho não-óbvio ou decisão difícil
de reverter.>

### Security / risco   <!-- governança: apague se rigor < governança -->

<modelo de ameaça: vetor × defesa × risco residual. ship-review verifica
contra este modelo, não o redefine.>

### Rollback            <!-- governança: apague se rigor < governança -->

<cenário × procedimento concreto (comando/flag). Intervenção manual exige
runbook linkado.>

### Estratégia de testes

- **Unit/contract:** <funções e estruturas de output>
- **User journeys:** um por ramo do COMO FICA (mecânica em test-and-debug).
- **Scenario (computer-use):** valida como o usuário faria, via `verify` —
  obrigatório se muda superfície user-facing dirigível.
- **Smoke pós-deploy:** script com asserts (não "usuário roda na mão").

## 3. Slices

Ordem respeitando dependências. Cada slice = 1 commit atômico verde.

**S1 — <título>.** <o que faz>. _Pronto:_ <critério verificável>.

## 4. Ao fechar

- <invariante de fechamento: PRD atualizado, CHANGELOG, tasks done>

## 5. Gate — Evaluator Status Block

```
Gate 1 (spec): <ok | critical_aberto | pulado>
round 1: <reviewer> — critical N / important N / suggestion N
teto: 1/2
```
