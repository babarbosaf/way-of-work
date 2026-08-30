---
name: to-spec
description: |
  Sintetiza decisão já tomada em spec técnica: problema, contrato, decisões e mapa de slices. Um arquivo, sem design detalhado.
  Invoque quando o usuário pedir `/to-spec` ou disser "escreve a spec" para feature que atravessa várias sessões, toca muitos arquivos, muda contrato ou toca prod.
  Não invoque para: bug localizado, refactor puro, script one-shot, ajuste de config ou docs, mudança que cabe numa sessão. Nem para decidir: spec registra decisão tomada, não decide (isso é `coaching`).
---

> A spec é o contrato que sobrevive à conversa que a gerou.
> Não é o plano de implementação (isso é `to-tickets`), nem o lugar onde se decide.
> Nenhuma linha de código antes da aprovação.

Síntese, não entrevista. Quando você chega aqui, o decidir já aconteceu. Se ainda
há pergunta de escopo aberta, o trilho é `coaching`, não este.

---

## O artefato: um arquivo

`docs/specs/<slug>/spec.md`. Sem `plan.md`, sem `design.md`, sem pasta de rounds.

| Seção | O que é |
|---|---|
| **Problema** | prosa curta. O que dói hoje, na linguagem do dono |
| **Como fica** | ASCII ≤40 colunas, antes → depois. Linguagem de negócio |
| **Decisões `D-NN`** | parágrafo curto: o quê, por quê, trade-off. Sem template |
| **Critérios de aceite** | SIM/NÃO comportamental |
| **Fora de escopo** | uma linha por item |
| **Slices** | mapa: `NN` · título · uma linha · dependência |

Se o sistema tem PRD, a spec **linka** a seção afetada. Não reescreve.

Duas seções condicionais, obrigatórias quando a mudança toca prod, recebe input
externo ou é irreversível: **Segurança** (modelo de ameaça, vetor × defesa) e
**Rollback** (cenário × procedimento). Fora desses casos, não existem.

## O que não entra

Nada disso pertence à spec, e é o que a fez inchar até 1733 linhas no passado:

- DDL, schema, contrato de tipo, assinatura de função
- blocos de teste enumerados, fixtures, propriedades
- tabela de métricas e alertas
- ADR inline (vai pra `docs/adrs/`)
- caminho de arquivo e trecho de código: envelhecem antes do ship
- meta-comentário de processo: `## Resposta ao Round N`, `## Anexo`,
  `status: post-reconciliation`, `Owners: Claude (drafting)`

Design detalhado mora no ticket que o constrói. O ticket que cria a migration é
dono do DDL; os outros referenciam esse ticket.

**Exceção única de snippet:** quando um trecho codifica a decisão com mais
precisão que a prosa (state machine, shape de schema). Só a parte que decide,
nunca a demo.

## Sem teto de linhas

O que separa uma spec de 270 linhas de uma de 1700 não é contagem, são as seções
que não deviam estar lá. O lint checa sintoma, não tamanho:

```bash
~/.claude/scripts/check-spec.py --spec <path>
```

Achado bloqueia; `aviso:` só informa (caminho de arquivo pode ser contexto
legítimo, tipo nomear script que já existe). Aviso não trava o gate.

## Fases

- [ ] **1. Desambiguar antes de escrever**, três lentes: **técnica** (a premissa
      que sustenta uma `D-NN` se confirma contra a fonte, API, doc via
      `use context7`, ambiente), **arquitetural** (≥2 caminhos não-óbvios → ADR,
      não seção na spec), **produto** (edge case, formato, política de erro →
      vira `D-NN`). Perguntas em batch único, ranqueadas.
- [ ] **2. Escrever**, na profundidade que o risco pede.
- [ ] **3. Fatiar o mapa de slices.** Cada slice é vertical e demoável sozinha.
      Teste: *"o que eu demonstro quando isto fecha?"* Sem resposta, é fatia
      horizontal, refatiar. Aqui é só o mapa; o ticket rico é `to-tickets`.
- [ ] **4. Segunda opinião (opcional).** Toca prod ou é caro de reverter →
      oferecer `scripts/peer-review.sh spec <path>`. Não é gate, o dono decide.
      Finding vira ticket, nunca seção nova na spec.
- [ ] **5. Aprovação explícita** do dono → `status: aprovado` no frontmatter.

## Depois de aprovada: append-only

Spec assinada não se reescreve. Mudou o contrato no caminho? Apenda
`## Revisão N` com a decisão nova e o ticket que ela cria. O texto aprovado fica.

Isso mata o ciclo que produzia `spec.md` + cinco arquivos `.round-N.md` do mesmo
material: cada rodada de review engordava o contrato em vez de gerar trabalho.

## Verification

- [ ] Sem jargão técnico nas seções de contrato; sem path, sem código
- [ ] Toda `D-NN` aparece no mapa de slices
- [ ] Aceite em SIM/NÃO comportamental, não "funcionar corretamente"
- [ ] "Fora de escopo" preenchido
- [ ] `~/.claude/scripts/check-spec.py --spec` verde
- [ ] Aprovação registrada antes de qualquer código

Voz e red flags: `references/style-and-flags.md`. Checklist obrigatório de
pipeline, handler e endpoint: `references/checklists.md`. Exemplo completo:
`references/exemplo.md`.

**Próximo passo:** `to-tickets`. Spec aprovada que não vira ticket é plano
soterrado, não plano.
