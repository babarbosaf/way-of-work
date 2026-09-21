# TODOS.md, template

Copie pra raiz do projeto como `TODOS.md`. O arquivo real fica gitignored, porque
backlog é contexto local: o que sobe é o formato. Cobra: `scripts/check-docs.py
--estagio --decay <raiz>`.

**Pra que serve.** Degrau 1 da escada de backlog, o **aceito**: alguém já decidiu
que o item importa, e ainda não existe contrato. Uma linha por item, com o que é.
A escada inteira está em [`docs/doc-standard.md`](docs/doc-standard.md).

**Dois blocos, e nada mais.** `## Próximos`, ordenado, onde a posição é a
prioridade, teto de 20. `## Pool`, não ordenado, que decai por data. Sem onda, sem
tema, sem campo de prioridade: cada eixo a mais de classificação é mais paralisia
na hora de escolher. Seção fora desses dois nomes é achado do lint.

**Item do Pool carrega data ISO.** Sem data não decai, e o que não decai vira
depósito. Parado tempo demais, promove ou apaga.

**Não é depósito de achado colateral.** Achado que tem a ver com o trabalho em
curso se resolve na sessão; achado que não tem a ver mas bloqueia também. Só o
que não tem a ver e não bloqueia desce pra cá. Se este arquivo cresce a cada
sessão de implementação, a regra está sendo furada.

**Item promovido sai daqui.** Virou spec ou ticket, a linha é apagada, sem
ponteiro e sem linha riscada: promover é mover, nunca copiar. Item vivendo em dois
degraus é achado do `--estagio`.

**Linha `[papercut]` é entrada de constraint, não task.** Incômodo visual
observado e não corrigido entra no Pool como `[papercut] <o que incomoda>
(<tela/componente>)`, com data. Não entra em sprint e não vira task solta: a skill
`design-workflow` lê o bloco na próxima passada de design, e cada linha vira
constraint ou morre ali.

---

## Próximos

- Índice de `pedidos(cliente_id, criado_em)`: a listagem faz table scan em 40k linhas
- `POST /webhooks/pagamento` aceita payload sem assinatura; validar HMAC antes de processar
- Extrair o cálculo de frete duplicado em `checkout.py` e `orcamento.py` (3ª repetição)

## Pool

- 2026-09-14 Migrar os 6 testes que dependem de rede pra fixture gravada
- 2026-09-02 `[papercut]` toast de erro desaparece antes de dar tempo de ler (checkout)
- 2026-08-28 Avaliar se o cron de reconciliação ainda tem dono depois da saída do time de dados
