# AGENTS.md, instrução de trabalho de todos os projetos

Fonte única pro agente (padrão AGENTS.md; `CLAUDE.md` é symlink). **Escrita:** terse, sem
AI slop, fragmento > frase, bom português; doutrina e linter na skill `writing`
(`check-writing.py` antes do commit), voz calibrada só em `references/voz.md`.

## Modelo de trabalho

Projeto novo entra por `/kickoff-project`, que entrevista e produz PRD, ROUTES, DESIGN,
CONVENTIONS, AGENTS e FEEDBACK. Feature grande (várias sessões, muitos arquivos, toca
contrato ou prod) passa por `/to-spec` e `/to-tickets` antes do TDD; na dúvida, vai
direto e promove se crescer. Todo o resto vai direto no código, com TDD. Spec aprovada
sempre vira ticket, e 1 ticket = 1 worktree = 1 branch = 1 PR.

**O gap amadurece no doc e executa no tracker.** Buraco entre o que o PRD promete e o que
existe fica no doc de gaps até haver contexto pra decidir; sem decisão, subir pro board é
ruído. Com contexto, vira spec (grande) ou ticket direto (pequeno), e o progresso passa a
morar no tracker. A spec fica desatualizada de propósito nesse meio-tempo; antes de ser
marcada feita, lista os tickets que a executaram e manda a verdade funcional pro PRD.

**Docs vivos** (política por projeto, no AGENTS.md dele): produto edita PRD; fluxo,
ROUTES; visual, DESIGN; técnico, CONVENTIONS; decisão cara de reverter, ADR em
`docs/adrs/`. Correção do projeto: uma linha no `FEEDBACK.md` com o gatilho embutido
(teto 10; virou norma, promove ao doc permanente e apaga). Lição cross-projeto: memória
(`capture-lessons` roteia). Achado colateral: resolve agora ou vira linha no `TODOS.md`,
nunca solto na conversa.

**Identidade de projeto tem dono.** Mudança no que um projeto **é** (o que faz, stack,
canal, quem mantém, se morreu) atualiza a página dele na base de conhecimento na mesma
rodada. Quem sabe que mudou é quem mudou; varredura sempre chega tarde.

**Cross-cutting:** context7 antes de fixar API, assinatura ou versão de lib
(`docs/research/context7.md`); `delegate` no mecânico; `design-workflow` em todo pedido
visual, roteado em papercut (fix óbvio, ou linha `[papercut]` no `TODOS.md`) ou design
(constraints antes do pixel, variantes fora do repo); `/handoff` antes de compactar com
trabalho aberto; `peer-review.sh {spec|diff}` opcional, recomendado em diff que toca prod
(`docs/adversarial-evaluator.md`); autonomia em escada turn, `/goal`, `/loop`,
`/schedule`, com stop-condition de máquina (`docs/autonomy-loops.md`); skill nova passa em
`scripts/check-skill.py` (`docs/skill-authoring.md`); artefato de fidelidade exige
reconhecimento do ambiente antes, e CI ou prod não são sonda (`docs/infra-migracao.md`).

## Como construir

- **Comportamento novo nasce com teste:** RED antes do código, GREEN mínimo, REFACTOR
  simplificando com a suíte verde. Bug ganha regressão antes da correção.
- **Debug para na causa raiz, não no sintoma:** "deduplicar no resultado" é sintoma;
  "query errada" é causa.
- **Suite verde é pré-condição de commit.** "Parece certo" não é done, e AC de rodar à
  mão vira script com assert.
- **Abstração só na 3ª repetição.** Helper extraído na 1ª duplicação é corte, e antes de
  escrever um, procurar o que já existe (stdlib, lib do projeto, codebase).
- **Zero feature especulativa:** adicionar depois é trivial, remover depois que espalhou
  não é. Vale pra UI: elemento só quando constraint exige.
- **Diff pequeno > diff completo**, e deletar conta como progresso. Estender artefato
  existente antes de criar paralelo (`docs/evolve-over-create.md`).
- **Repo que já existe: o inventário é o primeiro entregável.** O que tem, onde estão os
  buracos, o que sai. Bloco de escolhas antes do mapa faz o dono escolher no escuro.
- **Fonte acessível se mede, não se opina.** Com API, banco ou arquivo na mão, medir vem
  antes de afirmar.
- **Operação em lote sobre dado do usuário** (workspace, wiki, drive, prod) tem gate no
  plano, não só na execução: desenho e método na mesa, e espera o ok.

## Higiene de docs de raiz (AGENTS.md/CLAUDE.md, README.md, PRD…)

Carregam toda sessão; instrução viva, não changelog. Sem histórico (vai pra ADR, spec,
FEEDBACK ou memória), sem status volátil (vai pro TODOS ou tracker). Child AGENTS.md só
escreve override próprio. Teste linha a linha: cortar isto faria o agente errar? Não,
corta. Raiz em CAIXA-ALTA é doc único e estável; instância (`spec-<slug>`, `adr-NNNN`) em
lowercase, e transiente vai pra `_tmp/` (gitignored). Escopo se declara pelo que o projeto
**É**, sem tabela de exclusão: a negativa que importa vive na decisão que a produziu.

## Auto-memória

Append em `memory/log.md` antes de criar ou editar memória. Índice hub-first: atômica nova
entra no hub `concept_*` do tema, e o `MEMORY.md` fica só com hubs, em ~40 linhas.
AGENTS.md tem precedência sobre memória, e a conflitante se corrige na hora. Mecânica:
`docs/auto-memoria.md`.

## Claude Code specifics

Enforcement do Claude Code; outros harnesses ignoram. Hooks bloqueiam sozinhos e a
mensagem ensina na hora, inclusive o kill-switch de cada um. Mapa dos hooks, dos
kill-switches e dos comandos: `docs/claude-code.md`.
