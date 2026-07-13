# Sessões paralelas com worktree + comandos de referência

## Sessões paralelas com worktree

Regra de ouro pra rodar **várias sessões no mesmo codebase**: **1 sessão = 1 worktree = 1 branch.** Duas sessões nunca compartilham o mesmo working directory — `git switch` no mesmo dir arruma os arquivos por baixo da outra sessão. `git worktree` dá um `.git` compartilhado com diretórios de trabalho separados, zero colisão.

```
~/Projects/repo              main         ← worktree principal
~/Projects/repo--feat-a      feat-a       ← Sessão A
~/Projects/repo--fix-b       fix-b        ← Sessão B
```

- Criar: `git worktree add ../repo--<slug> -b <branch>`
- Cada sessão roda o ciclo completo (implementa → revisa → commit) no seu worktree, independente
- Ponto de sincronização = **push → merge em `main`**, serializado pelo humano (autoriza uma, depois a outra)
- Se a branch A mergeia primeiro, **rebaseie a B na `main` nova** antes do push da B — resolve conflito cedo
- Higiene: `git worktree remove ../repo--<slug>` ao fechar; evita worktrees órfãos
- Branches curtos + merge frequente (trunk-based) mantêm conflito perto de zero

## Comandos: switch / restore / clone

- **`git switch <branch>`** (trocar branch) e **`git restore <path>`** (descartar mudança em arquivo) no lugar de `git checkout` ambíguo — `checkout` mistura os dois e pode clobbar trabalho não-commitado sem aviso
- **Clone seguro:** clonar em diretório novo (nunca dentro de repo existente); `git clone --depth 1` em repo grande quando não precisa de histórico; conferir o remote (`git remote -v`) antes de operar
