# AGENTS.md, instrução de trabalho de todos os projetos

Fonte única do agente: edite este arquivo, e nunca troque o ponteiro `CLAUDE.md`
por um que carregue outra coisa. Doutrina longa mora em `skills/` e `docs/`; aqui
só o que muda decisão. Child AGENTS.md escreve override próprio, nunca repete o
que está aqui.

## Invariantes

- **Comportamento novo nasce com teste, e suite verde é pré-condição de commit.** RED antes do código, GREEN mínimo, REFACTOR simplificando com a suíte verde. Bug ganha regressão antes da correção. "Parece certo" não é done, e AC de rodar à mão vira script com assert.
- **Abstração só na 3ª repetição.** Helper extraído na 1ª duplicação é corte, e antes de escrever um, procurar o que já existe: stdlib, lib do projeto, codebase.
- **Zero feature especulativa, e diff pequeno > diff completo.** Adicionar depois é trivial, remover depois que espalhou não é. Deletar conta como progresso, e estender artefato existente vem antes de criar paralelo (`docs/evolve-over-create.md`). Vale pra UI: elemento só quando constraint exige.
- **Fonte acessível se mede, não se opina.** Com API, banco ou arquivo na mão, medir vem antes de afirmar.
- **Apagar, publicar, reabrir e mexer em lote são do dono.** Item que sai sem deixar rastro, build que vai pro ar, trabalho encerrado que volta a abrir, e operação em lote sobre dado do usuário (workspace, wiki, drive, prod): a sessão mede, propõe e espera o ok, com desenho e método na mesa antes de executar. Aprovação de um caso não se estende ao seguinte.
- **Achado colateral se resolve na sessão.** Tem a ver com o trabalho em curso, resolve. Não tem a ver mas bloqueia, resolve. Só o que não tem a ver e não bloqueia desce pro backlog, e `TODOS.md` é saída de exceção, não de conveniência.
- **Doc de estado fala do presente.** Um doc de raiz é o estado presente do produto **ou** o estado futuro depois das specs em aberto, e não existe terceiro estado. Nenhum deles é decision log, nem ADR: o decision log é o `FEEDBACK.md`, release é o `CHANGELOG.md`, mudança é o git. Item promovido sai do estágio anterior; transiente carrega a data em que morre.
- **Escrita terse, sem AI slop.** Fragmento > frase, bom português. Doutrina e linter na skill `writing`.
- **Este arquivo tem precedência sobre memória.** Memória conflitante se corrige na hora.

## Roteamento

| Quando | Faz |
|---|---|
| Projeto novo | `/kickoff-project`: entrevista que produz PRD, ROUTES, DESIGN, CONVENTIONS, AGENTS e `FEEDBACK.md` |
| Repo que já existe | inventário é o primeiro entregável: o que tem, onde estão os buracos, o que sai. Bloco de escolhas antes do mapa faz o dono escolher no escuro |
| Feature grande: várias sessões, muitos arquivos, toca contrato ou prod | `/to-spec` → `/to-tickets` → `/execute`. Na dúvida vai direto, e promove se crescer: plano que passou de 5 passos, ou que você quis salvar, já é spec |
| Pedido de *como*, com o *quê* fechado e mais de uma forma defensável | plan mode: cada passo nomeia arquivo tocado, o que prova, e o que foi descartado |
| Todo o resto | direto no código, com TDD |
| Spec fechando | **1 spec = 1 PR, 1 ticket = 1 commit verde.** A PR é a entrega de valor que o dono audita e valida antes de ir pra prod |
| Ideia solta no meio da conversa | uma linha no `INBOX.md`, sem análise. Decai em 30 dias |
| Gap entre o que o PRD promete e o que existe | uma linha no `TODOS.md` até haver contexto. Com contexto: spec (grande) ou ticket (pequeno), **e o item sai do `TODOS.md`** |
| Decisão de produto / de fluxo / visual / técnica | PRD / ROUTES / DESIGN / CONVENTIONS |
| Decisão cara de reverter | ADR em `docs/adrs/` ou `docs/conventions/`, viva enquanto o `Status:` é vivo (`docs/doc-standard.md`) |
| Correção do projeto | uma linha no `FEEDBACK.md` com o gatilho embutido. Teto 10; virou norma, promove ao doc permanente e apaga |
| Lição cross-projeto | memória atômica indexada, via `capture-lessons` (`docs/auto-memoria.md`) |
| Trabalho mecânico | `delegate` |
| Texto que outra pessoa vai ler | skill `writing`, e `check-writing.py` antes do commit |
| Doc de raiz novo ou editado | `docs/doc-standard.md` e os lints que ele nomeia (`scripts/check-docs.py`) |
| Compactação iminente com trabalho aberto | `/handoff` |
| Diff que toca prod | `peer-review.sh diff`, opcional e recomendado (`docs/adversarial-evaluator.md`) |

`INBOX.md`, `TODOS.md` e `FEEDBACK.md` são arquivos de raiz gitignored, um por
projeto, porque o conteúdo é contexto local e o que sobe é o formato. O molde de
cada um mora no `*.example.md` de mesmo nome na raiz deste repo.

## Ponteiros

`docs/claude-code.md` (hooks bloqueiam sozinhos, cada um com kill-switch; outros
harnesses ignoram) · `docs/context7.md` (doc de lib atualizada antes de fixar API)
· `docs/skill-authoring.md` · `docs/autonomy-loops.md` · `docs/infra-migracao.md`
