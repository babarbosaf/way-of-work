# INBOX.md, template

Copie pra raiz do projeto como `INBOX.md`. O arquivo real fica gitignored, porque
captura é contexto local: o que sobe é o formato. Cobra: `scripts/check-docs.py
--estagio --decay <raiz>`.

**Pra que serve.** Degrau 0 da escada de backlog, o **capturado**: a ideia existe
e ninguém decidiu nada sobre ela. Uma linha, sem análise. Escrever o dossiê aqui é
o gerador de lixo do método, porque gasta 25 linhas antes de alguém decidir que o
item importa. A escada inteira está em
[`docs/doc-standard.md`](docs/doc-standard.md).

**Uma linha por captura, com data ISO.** Sem data não decai. Teto de 30 capturas,
e 30 dias parado: estourou o prazo, promove pro `TODOS.md` ou apaga. Inbox que não
esvazia virou depósito, e depósito ninguém lê.

**Custo de entrada é uma linha.** Tipo e tamanho entram no degrau seguinte; o
dossiê (fato, evidência, causa, consequência, proposta) só no degrau 2, véspera de
build.

**Promover é mover.** A captura que virou item do `TODOS.md` é apagada daqui, sem
ponteiro. O mesmo texto nos dois degraus é achado do `--estagio`.

**Opcional, e útil quando o inbox é compartilhado:** marcar tamanho (`[S]`, `[M]`,
`[L]`) e dono entre parênteses no fim da linha. O lint não cobra nenhum dos dois.

---

- [ ] **[M]** 2026-09-18 Publicar o scaffold de projeto novo como template instanciável em um comando. Dep: sanitizar o settings do template pro público (owner: você)
- [ ] **[S]** 2026-09-16 O relatório de fechamento arredonda antes de somar, e o total fecha com 2 centavos de diferença
- [ ] **[L]** 2026-09-11 Avaliar trocar o worker de fila por job agendado: a fila hoje tem 3 mensagens por dia e custa um serviço inteiro
