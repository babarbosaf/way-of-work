---
rubric: feature-ui
threshold: 4
---

# Rubric — feature-ui

Aplica a: feature com superfície visível pro usuário (componente web, view, fluxo de telas, dashboard). Inclui PWA / mobile web. Exclui: pure CLI (use `script`).

## C1 — Acceptance criteria comportamentais demonstrados

- **5:** cada AC tem demo (screenshot/screencast) + teste automatizado (Playwright/Cypress/RTL); cobertura ≥80% do fluxo
- **4:** demo manual de cada AC + teste de componente (RTL/Vue Test Utils) do happy path
- **3:** demo do happy path; edge cases descritos sem evidência
- **2:** demo parcial; sem testes
- **1:** sem demo nem teste

## C2 — Cenários cobertos (happy + edge + falha)

- **5:** happy + edge (input vazio, dado faltando, ordem inesperada) + falha (rede, 4xx, 5xx) com UI distinta por estado
- **4:** happy + ≥1 edge + ≥1 falha; estados distintos no DOM
- **3:** happy + 1 dos dois (edge ou falha); estado loading/error parcial
- **2:** só happy path; falha cai no DOM padrão (alert/console)
- **1:** só happy path; falha não tratada

## C3 — Estados de loading, error e empty

- **5:** estado distinto pra cada um; skeleton/spinner em loading; mensagem acionável em error; empty state com call-to-action
- **4:** os 3 estados presentes; mensagens úteis; sem call-to-action em empty
- **3:** loading + error presentes; empty igual ao default
- **2:** só loading OU só error; outros caem em render padrão
- **1:** nenhum estado tratado; race condition visível

## C4 — Acessibilidade básica

- **5:** ARIA roles/labels corretos; navegação por teclado completa; contraste WCAG AA; screen reader testado
- **4:** ARIA presente onde aplicável; navegação por teclado nos elementos interativos; contraste verificado
- **3:** semântica HTML correta (button vs div, label associado); contraste ok
- **2:** semântica parcial; sem label em form fields críticos
- **1:** divs clicáveis; sem labels; contraste insuficiente

## C5 — Evolve > create (componentes)

- **5:** reusou componente existente (estendeu props, slot); zero componente novo desnecessário
- **4:** criou novo com justificativa (semântica distinta, contrato incompatível)
- **3:** criou novo sem justificar; similar a existente
- **2:** copiou+adaptou componente existente (drift garantido)
- **1:** criou divergente que vai precisar consolidar depois

## C6 — Mobile/responsivo (se aplicável)

Aplica quando interface não é desktop-only declarado. Sem requisito mobile: marca `n/a`.

- **5:** testado em 3+ viewports; touch targets ≥44px; overflow horizontal zero
- **4:** testado em 2 viewports (mobile + desktop); touch targets ok
- **3:** mobile funciona mas com glitches menores (texto pequeno, alguma overflow)
- **2:** quebra em mobile mas não-bloqueante
- **1:** quebra em mobile de forma bloqueante

## Aceite

Score ≥ 4 em **todos** os critérios aplicáveis (`n/a` não conta). C4 (acessibilidade) ≤ 2 em produto público = `block`. C2 (cenários) ≤ 2 em feature que recebe input do usuário = `block`.
