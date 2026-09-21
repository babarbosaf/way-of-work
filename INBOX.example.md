# INBOX.md, template

Copie pra raiz do projeto como `INBOX.md`. O arquivo real fica gitignored, e o
motivo é o mesmo do `TODOS.md`: captura é contexto de um projeto só, então o que
sobe pro git é o formato. Quem cobra é `scripts/check-docs.py --estagio --decay`.

Este é o degrau 0 da escada de backlog, o **capturado**. A ideia existe e ninguém
decidiu nada sobre ela, então é uma linha e ponto, sem análise. Escrever dossiê
aqui é o maior gerador de lixo do método, porque gasta 25 linhas antes de alguém
decidir que o item importa. A escada inteira está em
[`docs/doc-standard.md`](docs/doc-standard.md).

**Uma linha por captura, com data em ISO.** Sem data ela não decai. Teto de 30
capturas e 30 dias de prazo, e estourado o prazo você promove pro `TODOS.md` ou
apaga. Inbox que não esvazia virou depósito, e depósito ninguém lê.

O custo de entrada é uma linha. Tipo e tamanho entram no degrau seguinte, e o
dossiê com fato, evidência, causa, consequência e proposta só se escreve no degrau
2, véspera de build.

**Promover é mover.** A captura que virou item do `TODOS.md` some daqui, sem
ponteiro. O mesmo texto nos dois degraus o `--estagio` acusa.

Quando o inbox é compartilhado ajuda marcar tamanho, com `[S]`, `[M]` ou `[L]`, e
dono entre parênteses no fim da linha. Nenhum dos dois é cobrado pelo lint.

---

- [ ] **[M]** 2026-09-18 Publicar o scaffold de projeto novo como template instanciável em um comando. Dep: sanitizar o settings do template pro público (owner: você)
- [ ] **[S]** 2026-09-16 O relatório de fechamento arredonda antes de somar, e o total fecha com 2 centavos de diferença
- [ ] **[L]** 2026-09-11 Avaliar trocar o worker de fila por job agendado: a fila hoje tem 3 mensagens por dia e custa um serviço inteiro
