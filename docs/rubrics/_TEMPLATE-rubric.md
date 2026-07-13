---
rubric: _template
threshold: 4
---

# Rubric — _TEMPLATE

Copiar este arquivo pra `~/.claude/docs/rubrics/<nome>.md` ou `<repo>/docs/rubrics/<nome>.md`. Substituir critérios + threshold.

## Estrutura

- **4-6 critérios** scored 1-5. Menos que 4 = baixa cobertura; mais que 6 = sinaliza acoplamento (cada critério deveria capturar uma dimensão ortogonal).
- **Cada critério tem definição por nível**, não só o threshold. Modelo precisa do level 1 e 2 pra calibrar onde está.
- **Threshold único** (`≥4 em todos`) é o padrão. Threshold per-critério (`C1≥5, C2-Cn≥4`) é exceção — usar só quando há critério genuinamente mais crítico.

## C1 — <nome curto do critério>

- **5:** <ideal>
- **4:** <aceitável>
- **3:** <abaixo do threshold; iterar>
- **2:** <ruim>
- **1:** <inaceitável>

## C2 — <outro critério ortogonal>

- **5:** ...
- **4:** ...
- **3:** ...
- **2:** ...
- **1:** ...

## Aceite

Score ≥ {threshold} em **todos** os critérios. Qualquer abaixo = `iterate` (próximo pass). Se C com severidade alta (ex.: segurança em handler externo) atinge ≤2, classificar como `block` (não `iterate`) — exige intervenção humana antes de continuar.

## Notas pra autor da spec

- O critério "Evolve > create" é candidato natural pra incluir em quase toda rubric (anti-duplicação é cross-cutting).
- Critérios devem ser **observáveis no diff ou no doc da spec**. Critério que pede subjetividade pura ("o código é elegante?") não funciona — o evaluator não consegue pontuar consistente.
- Linkar memória `concept_evolve_over_create` (e similares) quando o critério referencia regra acumulada.
