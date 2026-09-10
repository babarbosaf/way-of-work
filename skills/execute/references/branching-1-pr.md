# Branch de integração e a PR única

Regra: **1 ticket ou 1 `/execute` = 1 worktree = 1 branch = 1 PR.** No trilho do
`/execute`, a unidade que vira PR é a rodada, não o ticket. Ticket continua tendo
worktree e branch próprias, mas elas morrem na integração.

```
trunk ──────────────────────────────────────────── merge (squash) ◀── PR única
  └── <prefix>/<slug>  ◀── merge serial ◀── delegate/t01   (worktree do worker)
                       ◀── merge serial ◀── delegate/t02
                       ◀── commit inline (ticket delega: não)
```

## Nascimento

```bash
git fetch origin && git switch -c <branch_prefix>/<slug> origin/<trunk>
```

`branch_prefix` e `trunk` vêm do `project.yaml`. Todo worker ramifica **desta
branch**, no SHA em que a leva começa. Leva nova, SHA novo: o worker sempre parte
do estado já integrado.

## Integração de cada ticket

1. `git status` na árvore principal: worker que escapou aparece aqui.
2. `git diff <prefix>/<slug>...delegate/<slug-ticket>`: arquivo fora dos `files:`
   rejeita a branch.
3. `verify:` do ticket verde na worktree do worker.
4. `git merge --no-ff delegate/<slug-ticket>` na branch de integração, depois
   `verify:` de novo. Um por vez. Merge concorrente produz conflito composto.
5. `git worktree remove <path>` e `git branch -d delegate/<slug-ticket>`. Órfãs:
   `delegate.sh --gc <repo>`.

Ticket inline commita direto na branch de integração, um commit por ticket, com o
ID no título.

## Morte

PR única `<prefix>/<slug>` → trunk. Squash merge com `--delete-branch`. O histórico
que sobrevive é um commit por rodada; o detalhe por ticket fica no corpo da PR e
nos comentários dos tickets.

Branch de integração que sobrevive ao merge é órfã. Varredura lê
`gh pr list --state merged`, nunca `git branch --merged` (squash cega).
