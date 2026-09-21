# TODOS.md, template

Copie pra raiz do projeto como `TODOS.md`. O arquivo real fica gitignored, e o
motivo é simples: backlog é contexto de um projeto só, então o que sobe pro git é
o formato. Quem cobra o formato é `scripts/check-docs.py --estagio --decay`.

Este é o degrau 1 da escada de backlog, o **aceito**. Alguém já decidiu que o
item importa e ainda não existe contrato nenhum sobre ele, então basta uma linha
dizendo o que é. A escada inteira está em
[`docs/doc-standard.md`](docs/doc-standard.md).

**Dois blocos, e nada mais.** `## Próximos` é ordenado, a posição é a prioridade,
teto de 20 itens. `## Pool` não tem ordem e decai por data. Sem onda, sem tema e
sem campo de prioridade, porque cada eixo a mais de classificação é mais
paralisia na hora de escolher. Seção fora desses dois nomes o lint acusa.

Todo item do Pool carrega data em ISO. Sem data ele não decai, e o que não decai
vira depósito. Parado tempo demais, você promove ou apaga.

**Isto não é depósito de achado colateral.** Achado que tem a ver com o trabalho
em curso se resolve na sessão, e achado que não tem a ver mas bloqueia também.
Desce pra cá só o que não tem a ver e não bloqueia. Se o arquivo cresce a cada
sessão de implementação, alguém está furando a regra.

**Item promovido sai daqui.** Virou spec ou ticket, apaga a linha, sem ponteiro e
sem linha riscada, porque promover é mover e nunca copiar. Item vivendo em dois
degraus o `--estagio` acusa.

Incômodo visual observado e não corrigido entra no Pool como linha
`[papercut] <o que incomoda> (<tela/componente>)`, com data, e **é entrada de
constraint, não task.** Não entra em sprint e não vira task solta. A skill
`design-workflow` lê essas linhas na próxima passada de design, e cada uma vira
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
