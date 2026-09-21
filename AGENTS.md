# AGENTS.md, instrução de trabalho de todos os projetos

Fonte única do agente. `CLAUDE.md` é symlink pra cá, em todo projeto: edite
este arquivo, e nunca troque o symlink por arquivo que só carrega `@AGENTS.md`.
Doutrina longa mora em `skills/` e `docs/`; aqui só o que muda decisão.
Child AGENTS.md escreve override próprio, nunca repete o que está aqui.

## Invariantes

- **Comportamento novo nasce com teste.** RED antes do código, GREEN mínimo, REFACTOR simplificando com a suíte verde. Bug ganha regressão antes da correção.
- **Suite verde é pré-condição de commit.** "Parece certo" não é done, e AC de rodar à mão vira script com assert.
- **Abstração só na 3ª repetição.** Helper extraído na 1ª duplicação é corte, e antes de escrever um, procurar o que já existe: stdlib, lib do projeto, codebase.
- **Zero feature especulativa.** Adicionar depois é trivial, remover depois que espalhou não é. Vale pra UI: elemento só quando constraint exige.
- **Diff pequeno > diff completo**, e deletar conta como progresso. Estender artefato existente antes de criar paralelo.
- **Repo que já existe: o inventário é o primeiro entregável.** O que tem, onde estão os buracos, o que sai. Bloco de escolhas antes do mapa faz o dono escolher no escuro.
- **Fonte acessível se mede, não se opina.** Com API, banco ou arquivo na mão, medir vem antes de afirmar.
- **Operação em lote sobre dado do usuário** (workspace, wiki, drive, prod) tem gate no plano, não só na execução: desenho e método na mesa, e espera o ok.
- **Apagar, publicar e reabrir são do dono.** Item que sai sem deixar rastro, build que vai pro ar, e trabalho já encerrado que volta a abrir: a sessão mede, propõe e espera o ok. Aprovação de um caso não se estende ao seguinte.
- **Achado colateral não fica solto na conversa:** resolve agora ou vira linha no `TODOS.md`.
- **Doc de estado fala do presente.** Histórico mora no git e no `CHANGELOG.md`; item promovido sai do estágio anterior; transiente carrega a data em que morre.
- **Escrita terse, sem AI slop.** Fragmento > frase, bom português. Doutrina e linter na skill `writing`.
- **Este arquivo tem precedência sobre memória.** Memória conflitante se corrige na hora.

## Roteamento

| Quando | Faz |
|---|---|
| Projeto novo | `/kickoff-project`: entrevista que produz PRD, ROUTES, DESIGN, CONVENTIONS, AGENTS e FEEDBACK |
| Feature grande: várias sessões, muitos arquivos, toca contrato ou prod | `/to-spec` → `/to-tickets` → `/execute`. Na dúvida vai direto, e promove se crescer: plano que passou de 5 passos, ou que você quis salvar, já é spec |
| Pedido de *como*, com o *quê* já fechado, mais de uma forma defensável e código que já existe | plan mode. Cada passo nomeia arquivo tocado, o que prova, e o que foi descartado |
| Todo o resto | direto no código, com TDD |
| Ticket ou `/execute` fechando | 1 worktree = 1 branch = 1 PR |
| Ideia solta no meio da conversa | uma linha no `INBOX.md`, sem análise. Decai em 30 dias |
| Gap entre o que o PRD promete e o que existe | uma linha no `TODOS.md` até haver contexto. Com contexto: spec (grande) ou ticket (pequeno), **e o item sai do `TODOS.md`** |
| Spec antes de ser marcada feita | lista os tickets que a executaram e manda a verdade funcional pro PRD |
| Decisão de produto / de fluxo / visual / técnica | PRD / ROUTES / DESIGN / CONVENTIONS |
| Decisão cara de reverter | ADR em `docs/adrs/` (ou `docs/conventions/`). Vive enquanto `Status:` é vivo; superada vai pro `archive/` no mesmo commit |
| Correção do projeto | uma linha no `FEEDBACK.md` com o gatilho embutido. Teto 10; virou norma, promove ao doc permanente e apaga |
| Lição cross-projeto | memória, via `capture-lessons` |
| O que um projeto **é** mudou: stack, canal, quem mantém, se morreu | atualiza a página dele na base de conhecimento na mesma rodada |
| Fixar API, assinatura ou versão de lib | context7 antes (`docs/context7.md`) |
| Trabalho mecânico | `delegate` |
| Comentário que só repete o código | `remove-dumb-comments`, que propõe e espera o ok |
| Pedido visual | `design-workflow`, roteado em papercut ou design |
| Texto que outra pessoa vai ler | skill `writing`; `check-writing.py` antes do commit |
| Doc de raiz novo ou editado | `docs/doc-standard.md`, e o lint que ele nomeia: `scripts/check-docs.py --estado\|--grafo\|--ciclo\|--decay\|--estagio` |
| Compactação iminente com trabalho aberto | `/handoff` |
| Diff que toca prod | `peer-review.sh diff`, opcional e recomendado (`docs/adversarial-evaluator.md`) |
| Skill nova | `scripts/check-skill.py` (`docs/skill-authoring.md`) |
| Autonomia além do turn | `/goal`, `/loop`, `/schedule`, com stop-condition de máquina (`docs/autonomy-loops.md`) |
| Artefato de fidelidade | reconhecer o ambiente antes; CI e prod não são sonda (`docs/infra-migracao.md`) |

## Ponteiros

- **Memória:** índice hub-first, `MEMORY.md` só com hubs. Mecânica em `docs/auto-memoria.md`.
- **Evoluir > criar:** `docs/evolve-over-create.md`.
- **Claude Code:** hooks bloqueiam sozinhos e a mensagem ensina na hora, com kill-switch em cada um. Mapa em `docs/claude-code.md`. Outros harnesses ignoram.
