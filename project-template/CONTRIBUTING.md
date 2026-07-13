# CONTRIBUTING

> **Papel:** o agnóstico do fluxo de mudança — branch, commit, PR. Setup de stack
> (deps, testes) está em [CONVENTIONS.md](CONVENTIONS.md) §Stack. As regras
> de branch/gate vivem lá e no [.claude/project.yaml](.claude/project.yaml)
> (`repo.trunk`, `repo.branch_prefix`); aqui só o passo-a-passo.

## Branch flow

Trunk-based. Branch a partir de `<trunk>`: `<prefixo>/<slug-kebab>`.

## Convenção de commit e PR

Atomic commits (~100 linhas, máx 300). Mensagem explica o **porquê**, não só o
quê. Sem credencial no diff. Formato: `tipo(escopo): resumo imperativo`.

## Checklist do PR

- [ ] Testes verdes (`verify_cmd` do project.yaml)
- [ ] Diff só do escopo da task
- [ ] Doc de instrução viva atualizado se o comportamento mudou
- [ ] Sem segredo/credencial no diff
