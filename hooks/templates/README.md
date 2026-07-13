# Hook templates — instanciar por projeto

Templates de hooks reutilizáveis. Não são ativados globalmente — cada projeto que quiser usar copia pra `.claude/hookify.<nome>.local.md` e ajusta os placeholders.

## Templates disponíveis

### `block-commit-no-tests.template.md`
Avisa (não bloqueia) antes de `git commit` sem rodar testes. Origem: projeto real, generalizado.

**Placeholders:**
- `{{TEST_CMD}}` — comando de teste do projeto (`pytest`, `vitest run`, `go test ./...`, etc.)

**Quando instalar:** projeto code-heavy sem TDD obrigatório por skill. Pular se um agent de execução do projeto já força TDD por conta própria.

## Hooks NÃO generalizados (project-specific demais)

`<seu-projeto>/.claude/hookify.{no-print-parsers,warn-magic-numbers,warn-try-catch-parsers}.local.md` assumem `src/parsers/*.py` + convenções específicas do projeto. Não vale tentar parametrizar — copiar e adaptar se outro projeto tiver a mesma estrutura.
