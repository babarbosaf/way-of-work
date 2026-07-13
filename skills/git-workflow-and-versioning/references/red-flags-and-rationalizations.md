# Red Flags e Rationalizations — git-workflow-and-versioning

## Red Flags

- 🚩 Commit com `git add .` sem revisar o diff → pode incluir `.env` ou arquivos não intencionais
- 🚩 Mensagem de commit vaga ("fix", "update", "changes") → reescreva
- 🚩 Commit misturando feature + refatoração → separe
- 🚩 Branch com mais de 3 dias sem merge → o trabalho está mal dimensionado
- 🚩 `git commit --amend` em commit já pushado → cria conflito para outros
- 🚩 `git push --force` em `main` ou branch com PR aberto/compartilhada → reescreve histórico alheio. Se inevitável em branch **própria**, só `--force-with-lease`, nunca em `main`
- 🚩 `git commit --no-verify` / pular pre-commit hooks → o gate existe por um motivo; corrija a causa, não silencie o hook
- 🚩 Duas sessões no mesmo working directory → use worktree (ver § Sessões paralelas)

## Rationalizations

| Desculpa | Por que não aceitar |
|---|---|
| "Vou commitar quando terminar tudo" | Commits grandes são impossíveis de reverter parcialmente |
| "A mensagem do commit não importa" | Daqui a 2 meses você vai querer entender o histórico |
| "É só um projeto pessoal, não precisa de branch" | Branches protegem o main de trabalho incompleto |
