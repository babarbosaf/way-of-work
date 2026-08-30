# Worktree, paralelismo e comandos de referência

## A regra

**1 ticket = 1 worktree = 1 branch = 1 PR.**

Duas sessões nunca compartilham working directory: `git switch` no mesmo dir
arruma os arquivos por baixo da outra. `git worktree` dá um `.git` compartilhado
com diretórios de trabalho separados, zero colisão.

Fora do trilho de spec (bug, ajuste, tarefa de uma sessão), a unidade é a tarefa
em vez do ticket, e worktree só quando há mais de uma sessão viva.

## Worktree nativo do Claude Code

```bash
claude -w t01-category-dtr     # .claude/worktrees/t01-category-dtr/
                               # branch worktree-t01-category-dtr
```

O CLI cria, isola e limpa. Bloqueia por conta própria Edit, Write e `cd` que
tentem escapar pro checkout principal. O prefixo `worktree-` é dele e não se
escolhe; o sufixo é o ticket, e é o que importa na hora de saber quem é quem.

- `.claude/worktrees/` no `.gitignore`. Sem isso o worktree entra no git e
  duplica arquivos do repo (aconteceu: dois diretórios `_wt-*` versionados,
  arrastando cópias inteiras de `docs/specs/`).
- `.worktreeinclude` (sintaxe de `.gitignore`) copia arquivos ignorados que o
  worktree precisa, tipicamente `.env`. Worktree é checkout limpo: dependências
  se instalam de novo lá dentro.
- Worker externo tem o seu: `delegate.sh --worktree` usa `delegate/<slug>`.
  Prefixo diferente marca quem executou; sufixo igual marca o ticket.

Worktree isola **tickets de uma mesma leva**. Duas frentes independentes no mesmo
checkout principal continuam disputando: para isso, clone separado.

## Leva paralela

- **SHA congelado.** Todos os worktrees da leva ramificam do mesmo commit de
  `main`. Cada um puxando `HEAD` num momento diferente produz conflito que
  ninguém previu.
- **Teto de 3 a 5.** Acima disso a revisão vira gargalo e o ganho evapora.
  Referência de campo: um revisor humano para cada três ou quatro builders.
- **`files:` do ticket manda.** Editar arquivo fora dos `files:` é ownership de
  outro ticket, não zelo. Para e pergunta.
- **Merge serializado**, um por vez, verify entre cada. Merge concorrente produz
  conflito composto que custa horas de debug.
- Conflito entre agentes diferentes é o dobro do conflito dentro de um mesmo
  agente. Particionar por arquivo é o que segura.

## A branch morre no merge

```bash
git worktree remove .claude/worktrees/t01-category-dtr
gh pr merge --squash --delete-branch
```

Nessa ordem: worktree suja aborta o delete da branch.

`--delete-branch` é default, não opção. Branch que sobrevive ao merge vira órfã, e
órfã acumula sem ninguém notar.

**Squash-merge cega o `git branch --merged`.** O commit squashado ganha SHA novo,
então a branch nunca aparece como mergeada e a varredura de órfãs mente. Para
achar o que dá pra deletar:

```bash
gh pr list --state merged --limit 100 --json headRefName -q '.[].headRefName' |
  while read b; do git show-ref -q --verify "refs/heads/$b" && echo "$b"; done
```

Worktrees órfãos: `git worktree list`, depois `git worktree prune` para os que já
sumiram do disco. Do delegate: `delegate.sh --gc <repo-dir>`.

## Worktree manual, quando o nativo não serve

```
~/Projects/repo              main      ← worktree principal
~/Projects/repo--feat-a      feat-a
```

`git worktree add ../repo--<slug> -b <branch>`, fora do repo, nunca dentro.
Remover com `git worktree remove ../repo--<slug>`.

Atenção: worktree tem `.claude/` próprio. Skill ou hook criado no principal fica
invisível lá dentro, e vice-versa.

## Comandos: switch / restore / clone

- **`git switch <branch>`** (trocar branch) e **`git restore <path>`** (descartar
  mudança em arquivo) no lugar de `git checkout` ambíguo, que mistura os dois e
  pode clobbar trabalho não-commitado sem aviso
- **Clone seguro:** clonar em diretório novo (nunca dentro de repo existente);
  `git clone --depth 1` em repo grande quando não precisa de histórico; conferir
  o remote (`git remote -v`) antes de operar
