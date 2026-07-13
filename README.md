# way-of-work

Configuração curada de [Claude Code](https://claude.com/claude-code) — o `~/.claude` de um dev, versionado e público, pra quem quer adotar o mesmo modelo de trabalho com agentes.

Não é um plugin nem um framework. É um conjunto vivo de **skills**, **docs de doutrina**, **hooks de enforcement** e um **padrão de `AGENTS.md`** que enforça um ciclo de desenvolvimento disciplinado: spec antes de código, gate adversarial antes de merge, memória durável entre sessões.

## O que tem dentro

| Área | O que é |
|------|---------|
| `skills/` | Skills invocáveis — cada uma é uma fase do ciclo (ver taxonomia abaixo). |
| `docs/` | Doutrina: [`way-of-working.md`](docs/way-of-working.md) (as cadeias que ligam os docs), `adversarial-evaluator.md`, `evolve-over-create.md`, `autonomy-loops.md`, `rubrics/` e runbooks em `docs/runbooks/`. |
| `hooks/` | Enforcement em tempo de execução (grep-first em reads grandes, guardas de no-op, lembrete de doc atualizada). A mensagem de bloqueio ensina na hora. |
| `project-template/` | Scaffold clonável do doc-system pra um projeto novo (hub docs, `docs/<área>/`, `.claude/project.yaml`). |
| `AGENTS.md` | Padrão de instrução viva (agnóstico, lido por Codex/Cursor/etc.); `CLAUDE.md` é symlink. Terse, sem changelog, cada linha passa no teste "cortar isso faria o agente errar?". |
| `config/model-policy.json` | Roteamento de modelos por task-type (base pública genérica; override privado via `*.local.json` gitignored). |

Fatos estruturais do repo (layout, peças, convenções) em [`CONTEXT.md`](CONTEXT.md); histórico de release em [`CHANGELOG.md`](CHANGELOG.md).

### Skills — taxonomia

| Skill | Invocação |
|-------|-----------|
| [`spec-and-plan`](skills/spec-and-plan) | model-invoked |
| [`test-and-debug`](skills/test-and-debug) | model-invoked |
| [`ship-review`](skills/ship-review) | model-invoked |
| [`git-workflow-and-versioning`](skills/git-workflow-and-versioning) | model-invoked |
| [`delegate`](skills/delegate) | model-invoked |
| [`coaching`](skills/coaching) | user-invoked |
| [`handoff`](skills/handoff) | user-invoked |
| [`capture-lessons`](skills/capture-lessons) | user-invoked |
| [`skill-creator`](skills/skill-creator) | user-invoked |
| [`refresh-model-rankings`](skills/refresh-model-rankings) | user-invoked |

**model-invoked** dispara sozinha quando o fluxo bate o gatilho (fase do ciclo, gate pré-ship). **user-invoked** você aciona por `/comando` num momento deliberado.

## Filosofia em uma tela

- **Spec é a fonte de verdade.** Nenhuma linha de código antes do contrato aprovado. `/spec-and-plan` materializa spec como folder, decompõe em slices verificáveis.
- **Segunda opinião não é opcional.** Um Adversarial Evaluator (`peer-review.sh`) roda sobre spec e diff, classifica achados Critical/Important/Suggestion. Critical bloqueia.
- **Evoluir > criar.** Estender artefato existente antes de criar paralelo. `_v2` e "migro depois" nunca migra.
- **Memória durável entre sessões.** Fatos que sobrevivem à sessão viram memória atômica indexada; o resto morre com o contexto.
- **Escrita terse.** Fragmento > frase. Sem verborragia, sem AI slop.
- **Doc-system transferível.** `project-template/` é o esqueleto de docs de um projeto; [`docs/way-of-working.md`](docs/way-of-working.md) ensina as cadeias que ligam pesquisa → decisão, spec → PRD → changelog, e a espinha STRATEGY → CONVENTIONS.

## Como usar

Três modos de consumo — do mais simples ao mais isolado. Detalhe operacional em [`docs/runbooks/adopt-way-of-work.md`](docs/runbooks/adopt-way-of-work.md).

### 1. User-level (fonte única)

Clona pra `~/.claude`. Toda sessão de Claude Code na máquina herda skills, docs e hooks. Fonte única — melhorou aqui, melhorou em todo projeto.

```bash
git clone https://github.com/babarbosaf/way-of-work ~/.claude
```

O que é privado (scope pago, paths locais, roteamento de findings pra repos de negócio) vive em `config/*.local.json` — **gitignored, nunca versionado** — e faz merge sobre a base pública em runtime. Copie `config/model-policy.json` pra `config/model-policy.local.json` e preencha com seus valores.

### 2. Cloud multi-source

Rotinas de agente em nuvem (`/schedule`) referenciam este repo como uma das `sources`. O agente clona way-of-work junto com o repo-alvo e herda o mesmo modelo de trabalho num ambiente isolado.

### 3. Submodule (projeto self-contained)

Projeto que precisa carregar sua própria cópia (CI hermético, sem depender do `~/.claude` da máquina) adiciona como submodule:

```bash
git submodule add https://github.com/babarbosaf/way-of-work .claude
```

## Contribuir

Melhoria nasce no uso real — você trabalha num projeto, sente a dor, ajusta a skill, propõe upstream. Fluxo em [`CONTRIBUTING.md`](CONTRIBUTING.md).

## Licença

MIT — veja [`LICENSE`](LICENSE).
