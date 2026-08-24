# FEEDBACK.md, template

Copie pra raiz do projeto como `FEEDBACK.md`. O arquivo real fica gitignored no repo
público, porque correção de projeto é contexto local: o que sobe é o formato.

**Pra que serve.** Buffer de correção e lição do projeto, lido toda sessão. O agente
errou, você corrigiu, a correção entra aqui e vale amanhã. Sem isso a mesma correção
volta toda semana.

**Uma linha por entrada, com o gatilho embutido.** O gatilho é a condição que faz a linha
ser lembrada na hora certa. Sem ele a entrada é conselho solto, e conselho solto ninguém
aplica. A narrativa do incidente não vem pra cá: ela fica na decisão que o produziu, seja
commit, ADR ou spec.

**Teto de 10 entradas.** Estourou, compacta em vez de relaxar o teto: entrada que virou
norma é promovida ao doc permanente (PRD, CONVENTIONS, ROUTES ou DESIGN, conforme o
assunto) e apagada daqui; entrada obsoleta é apagada sem cerimônia. Arquivo de 40 linhas
para de ser lido, e um buffer que ninguém lê é pior que buffer vazio, porque dá a
impressão de que a lição está guardada.

**Lição que vale pra qualquer projeto não é daqui.** Vai pra memória do agente. A skill
`capture-lessons` roteia entre os dois destinos.

---

## Entradas

- **Migration com nome fora da ordem do histórico remoto quebra o push.** Ao criar
  migration, conferir a última versão registrada no remoto antes de nomear o arquivo.
- **Teste que passa sem asserção não é teste.** Antes de fechar uma task, rodar a suíte
  com a implementação revertida e confirmar que fica vermelha.
