# AGENTS.md, instrução de trabalho de todos os projetos

Fonte única do agente: edite este arquivo, e nunca troque o ponteiro `CLAUDE.md`
por um que carregue outra coisa. Doutrina longa mora em `skills/` e `docs/`; aqui
só o que muda decisão. Child AGENTS.md escreve override próprio, nunca repete o
que está aqui.

## Invariantes

- **Comportamento novo nasce com teste, e suíte verde é pré-condição de commit.** RED antes do código, GREEN mínimo, REFACTOR simplificando com a suíte verde. **Antes do RED, escrever como aquilo quebra**: teste escrito a partir da implementação reafirma a implementação e passa sempre. Bug ganha regressão antes da correção, e o debug para na causa raiz, não no sintoma ("deduplicar no resultado" é sintoma; "query errada" é causa). "Parece certo" não é done, e AC de rodar à mão vira script com assert.
- **Abstração só na 3ª repetição.** Helper extraído na 1ª duplicação é corte, e antes de escrever um, procurar o que já existe: stdlib, lib do projeto, codebase.
- **Zero feature especulativa, e diff pequeno > diff completo.** Adicionar depois é trivial, remover depois que espalhou não é. Deletar conta como progresso, e estender artefato existente vem antes de criar paralelo (`docs/evolve-over-create.md`). Vale pra UI: elemento só quando constraint exige.
- **Fonte acessível se mede, não se opina.** Com API, banco ou arquivo na mão, medir vem antes de afirmar.
- **Apagar, publicar, reabrir e mexer em lote são do dono.** Item que sai sem deixar rastro, build que vai pro ar, trabalho encerrado que volta a abrir, operação em lote sobre dado do usuário em workspace, wiki, drive ou prod. Em todos, a sessão mede, mostra desenho e método, e espera o ok antes de executar. Aprovação de um caso não se estende ao seguinte.
- **Achado colateral se resolve na sessão.** Se tem a ver com o trabalho em curso, resolve; se não tem mas bloqueia, resolve também. Desce pro backlog só o que não tem a ver e não bloqueia, e aí o `TODOS.md` é saída de exceção, nunca de conveniência.
- **Doc de estado descreve o estado final, marcado.** Um doc de raiz descreve o produto como ele vai ser, e cada funcionalidade leva `no ar` (já funciona), `previsto` (decidido e não construído) ou `em aberto` (nem decidido), na primeira linha da seção ou no item quando a seção mistura. Doc em inglês usa `live`, `planned` e `open`, os mesmos estados. Prosa de "hoje" contra "no alvo" não existe: a tag faz esse trabalho. Nenhum doc é decision log. ADR e DDR também não, porque registram uma decisão viva e não o histórico dela. O log é o `FEEDBACK.md`, release é o `CHANGELOG.md`, e mudança é o git. Item promovido sai do estágio anterior; transiente carrega a data em que morre.
- **Escrita terse, sem AI slop.** Fragmento > frase, bom português. Doutrina e linter na skill `writing`.
- **Este arquivo tem precedência sobre memória.** Memória conflitante se corrige na hora.

## Roteamento

| Quando | Faz |
|---|---|
| Projeto novo | `/kickoff-project`: entrevista que produz PRD, ROUTES, DESIGN, CONVENTIONS, AGENTS e `FEEDBACK.md` |
| Repo que já existe | inventário é o primeiro entregável: o que tem, onde estão os buracos, o que sai. Bloco de escolhas antes do mapa faz o dono escolher no escuro |
| Feature grande: várias sessões, muitos arquivos, toca contrato ou prod | `/to-spec` → `/to-tickets` → `/execute`. Na dúvida vai direto, e promove se crescer: plano que passou de 5 passos, ou que o dono quis salvar, já é spec |
| Pedido de *como*, com o *quê* fechado e mais de uma forma defensável | plan mode: cada passo nomeia arquivo tocado, o que prova, e o que foi descartado |
| Todo o resto | direto no código, com TDD |
| Spec fechando | **1 spec = 1 PR, 1 ticket = 1 commit verde.** A PR é a entrega de valor que o dono audita e valida antes de ir pra prod |
| Ideia solta no meio da conversa | uma linha no `INBOX.md`, sem análise. Decai em 30 dias |
| Gap entre o que o PRD promete e o que existe | uma linha no `TODOS.md` até haver contexto. Com contexto: spec (grande) ou ticket (pequeno), **e o item sai do `TODOS.md`** |
| Decisão de produto / de fluxo / visual / técnica | PRD / ROUTES / DESIGN / CONVENTIONS |
| Decisão cara de reverter | ADR em `docs/adrs/` ou `docs/conventions/`, viva enquanto o `Status:` é vivo (`docs/doc-standard.md`) |
| Correção do projeto | uma linha no `FEEDBACK.md` com o gatilho embutido. Teto 10; virou norma, promove ao doc permanente e apaga |
| Lição cross-projeto | memória atômica indexada, via `capture-lessons` (`docs/auto-memoria.md`) |
| Trabalho mecânico, ou pesquisa externa | `delegate` |
| Texto que outra pessoa vai ler | skill `writing`, e `check-writing.py` antes do commit |
| Doc de raiz novo ou editado | `docs/doc-standard.md` e os lints que ele nomeia (`scripts/check-docs.py`) |
| Compactação iminente com trabalho aberto | `/handoff` |
| Segunda opinião pedida, ou diff que toca prod | `peer-review.sh diff`, ou `doc <path.md>` pra qualquer markdown. Subagente Claude é o degrau 3 da cascata, nunca o primeiro (`docs/adversarial-evaluator.md`) |
| Autonomia além do turn | `/goal`, `/loop`, `/schedule`, e só com turn cap e stop-condition que seja **comando runnable**, tipo `verify_cmd` ou suíte verde, nunca o juízo do agente. Sem comando de aceite, não abre loop. E `/schedule` roda na nuvem, então consome cota de plano e não alcança estado local |

`INBOX.md`, `TODOS.md` e `FEEDBACK.md` são arquivos de raiz gitignored, um por
projeto. O conteúdo é contexto local e o que sobe pro git é só o formato: o molde
de cada um está no `*.example.md` de mesmo nome, na raiz deste repo.

## Ponteiros

- `docs/claude-code.md`, os hooks que bloqueiam sozinhos, cada um com kill-switch. Outro harness ignora.
- `docs/context7.md`, doc de lib atualizada antes de fixar assinatura ou versão.
- `docs/skill-authoring.md`, régua de autoria de skill, cobrada por `scripts/check-skill.py`.
