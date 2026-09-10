---
name: execute
description: |
  Executa os tickets de uma spec aprovada de ponta a ponta: despacha cada ticket pra worker externo em worktree própria, integra em branch única, mantém ticket e spec atualizados, roda suíte e cenário, atualiza docs vivos, abre ticket de QA Manual e fecha em uma PR só.
  Invoque quando o usuário digitar `/execute`, com slug da spec, IDs de ticket ou referência de roadmap como argumento. Só o usuário dispara.
  Não invoque para: escrever spec (`to-spec`), fatiar em tickets (`to-tickets`), tarefa de uma sessão sem spec (vai direto no código), ou despachar um worker avulso (`delegate`).
disable-model-invocation: true
argument-hint: "<spec-slug> [tickets|refs|instruções livres]"
---

> A spec decide, o ticket rastreia, o `/execute` entrega.
> Um `/execute` = 1 worktree de integração = 1 branch = 1 PR.
> Nenhum ticket começa sem DA nas decisões abertas.

Entrada: `$ARGUMENTS`. Slug da spec, IDs de ticket, ref de roadmap, instrução
livre. Tudo vira brief antes de virar código.

---

## Fase 0, contexto e brief

- [ ] **Brief.** `_tmp/execute/<slug>.md` no projeto. Existe: ler. Não existe:
      copiar `assets/brief-template.md`, preencher com `$ARGUMENTS`, fechar os
      campos vazios com até 4 perguntas via `AskUserQuestion`, gravar. Brief é o
      contrato da rodada, transiente, gitignored.
- [ ] **Resolver.** `python3 scripts/resolve-context.py <slug>` na raiz do repo.
      Devolve JSON: spec, tickets com header parseado, `tracker.backend`, trunk,
      `verify_cmd`, `smoke_cmd`, `ticket_count`, `simplify_suggested`. Exit 1 com
      `errors` quando falta spec ou `verify_cmd` é placeholder: parar e resolver
      antes, nenhum ticket fecha sem verify real.
- [ ] **Backend ≠ none.** Tickets moram no tracker: buscar por spec/label, mesmo
      header. Arquivo local e tracker nunca coexistem (`to-tickets`).
- [ ] **Workers.** `~/.claude/skills/delegate/scripts/smoke_backends.sh --task implement`.
      Registra no brief quem respondeu. Sem worker vivo, todo ticket roda inline
      na sessão. Subagente Claude não entra nesta skill.
- [ ] **Branch de integração.** `git switch -c <branch_prefix>/<slug>` a partir do
      trunk atualizado. Detalhe e limpeza: `references/branching-1-pr.md`.

## Fase 1, plano e DA

- [ ] Ordenar tickets: `blocked_by` primeiro, `[P]` da mesma fase em leva (teto 3
      a 5). Ticket fora do brief não entra.
- [ ] Executor por ticket: `delega: <type>` vai pro worker; `delega: não` roda
      inline. Degradar é permitido, promover não.
- [ ] **Decisão aberta vira `AskUserQuestion`**, com a recomendação como primeira
      opção. Nada implementa antes da resposta. Decisão respondida entra no brief
      e, se muda desenho, vira `D-NN` na spec.
- [ ] Imprimir o plano: ordem, executor, o que roda paralelo, `verify` de cada.

## Fase 2, build por ticket

Loop, um ticket ou uma leva `[P]` por vez:

1. **Abrir.** Comentar "iniciado" no ticket (`references/ticket-updates.md`).
2. **Executar.** Worker: `delegate.sh --task <type> --worktree <repo> -` com o
   ticket inteiro no prompt, mais regras do `AGENTS.md` e `files:` como limite.
   Inline: TDD nos `files:` do ticket, na branch de integração.
3. **Integrar.** Protocolo do `delegate` (status da árvore principal, diff no
   escopo, `verify` verde), depois merge serial na branch de integração e
   `verify` de novo. Worktree e branch do worker morrem aqui.
4. **Atualizar.** Comentar no ticket: o que fechou, `verify` rodado, desvio de
   rota se houve. Aceite marcado. Estado avança.
5. **Task nova no caminho.** Ticket novo com `files:`, `blocked_by`, `delega:`,
   `verify:`, mais linha no mapa de slices da spec. Entra na ordem, ou fica
   `bloqueado:` com motivo. Nunca trabalho solto na conversa.
6. **Handoff** se compaction se aproxima com ticket aberto.

## Fase 3, fechamento

- [ ] **Suíte e cenário.** `verify_cmd` completo e `smoke_cmd` na branch de
      integração. Vermelho não segue.
- [ ] **Simplify.** `simplify_suggested` (6 ou mais tickets): `AskUserQuestion`
      com "rodar `/simplify` nos paths tocados" como recomendação. Usuário pode
      negar. Menos que 6: só se o usuário pedir.
- [ ] **Docs vivos.** Produto mudou, `PRD.md`; fluxo, `ROUTES.md`; visual,
      `DESIGN.md`; padrão técnico, `CONVENTIONS.md`; decisão cara de reverter,
      ADR. Spec: mapa de slices reflete tickets reais e executados.
- [ ] **QA Manual.** Um ticket (criar, ou enriquecer o existente) com cenários
      MECE, passos e resultado esperado, cada um `validado por agente` ou
      `pendente humano`. O que dá pra validar sozinho, valida e marca. Molde:
      `references/qa-manual.md`.
- [ ] **Segunda opinião.** Diff toca prod ou é caro de reverter: oferecer
      `peer-review.sh diff <trunk>`. Dono decide.
- [ ] **Gate de ship** da `git-workflow-and-versioning`, depois PR única
      `<branch_prefix>/<slug>` para o trunk, corpo em `references/pr-body.md`.
      Push é o gate humano: parar e pedir.
- [ ] **Report de fechamento**, 4 linhas: `feito`, `como`, `verify`, `findings`.
      Brief ganha `status: entregue` e o link da PR.

## Invariantes

- Ticket fora do brief não roda. Escopo cresce só por ticket novo, e o usuário vê.
- `files:` é limite duro pra worker e pra sessão. Arquivo fora, para e pergunta.
- Ticket e spec atualizados no momento, não no fim. Compaction no meio não pode
  perder rota.
- Um PR. Branch de ticket morre na integração, nunca sobe sozinha.

## Verification

- [ ] Todo ticket do brief em estado final, com comentário de fechamento
- [ ] `verify_cmd` e `smoke_cmd` verdes na branch de integração
- [ ] Ticket de QA Manual existe, cenários MECE, cada um com veredito
- [ ] Docs vivos tocados listados no corpo da PR
- [ ] Nenhuma worktree ou branch de ticket sobrando (`git worktree list`,
      `delegate.sh --gc`)
- [ ] Uma PR aberta, push autorizado pelo usuário
