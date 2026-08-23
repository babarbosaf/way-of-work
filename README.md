# way-of-work

Configuração curada de [Claude Code](https://claude.com/claude-code) — o `~/.claude` de um dev, versionado e público, pra quem quer adotar o mesmo modelo de trabalho com agentes.

Não é um plugin nem um framework. É um conjunto vivo de **skills**, **docs de doutrina**, **hooks de enforcement** e um **padrão de `AGENTS.md`** que sustenta um modelo de trabalho simples: fundação de projeto por entrevista (kickoff), docs vivos como fonte de verdade, TDD sempre, spec só pra feature grande, memória durável entre sessões.

## O que tem dentro

| Área | O que é |
|------|---------|
| `skills/` | Skills invocáveis — cada uma é uma fase do ciclo (ver taxonomia abaixo). |
| `docs/` | Doutrina: `evolve-over-create.md`, `autonomy-loops.md`, `adversarial-evaluator.md` (segunda opinião opcional) e runbooks em `docs/runbooks/`. |
| `hooks/` | Enforcement em tempo de execução (grep-first em reads grandes, guardas de no-op, lembrete de doc atualizada). A mensagem de bloqueio ensina na hora. |
| `AGENTS.md` | Padrão de instrução viva (agnóstico, lido por Codex/Cursor/etc.); `CLAUDE.md` é symlink. Terse, sem changelog, cada linha passa no teste "cortar isso faria o agente errar?". |
| `config/model-policy.json` | Roteamento de modelos por task-type (base pública genérica; override privado via `*.local.json` gitignored). |

Histórico de release em [`CHANGELOG.md`](CHANGELOG.md).

Convenções estruturais:
- **`AGENTS.md` é a fonte, `CLAUDE.md` symlink.** Editar sempre o `AGENTS.md`.
- **`.gitignore` é allowlist:** ignora tudo (`*`), libera com `!`. O que é pessoal (scope pago, paths, roteamento) vive em `config/*.local.json`, gitignored, deep-merge em runtime.
- **Memória (`memory/`) não é versionada** — comportamento do agente, específico da máquina.
- **Instrução viva, não changelog.** Docs de start-up não guardam histórico (→ `CHANGELOG.md`, ADR, memória).

### Skills — taxonomia

| Skill | Invocação |
|-------|-----------|
| [`kickoff-project`](skills/kickoff-project) | user-invoked (fundação de projeto novo por entrevista) |
| [`spec-and-plan`](skills/spec-and-plan) | model-invoked (só feature grande) |
| [`git-workflow-and-versioning`](skills/git-workflow-and-versioning) | model-invoked (inclui o gate de ship) |
| [`delegate`](skills/delegate) | model-invoked |
| [`coaching`](skills/coaching) | user-invoked |
| [`handoff`](skills/handoff) | user-invoked |
| [`capture-lessons`](skills/capture-lessons) | user-invoked |

**model-invoked** dispara sozinha quando o fluxo bate o gatilho (fase do ciclo, gate pré-ship). **user-invoked** você aciona por `/comando` num momento deliberado.

## Filosofia em uma tela

- **Fundação por entrevista.** Projeto novo nasce pelo `/kickoff-project`: entrevista dirigida → PRD, ROUTES, DESIGN, CONVENTIONS, AGENTS.md e FEEDBACK.md. Nada de formulário em branco.
- **Docs vivos são a fonte de verdade.** Decisão de produto edita o PRD; padrão técnico, o CONVENTIONS; correção vira entrada no FEEDBACK.md (buffer com teto e promoção). Spec só pra feature grande, em 1 arquivo descartável — ao shippar, a verdade migra pro PRD.
- **TDD sempre.** Comportamento novo nasce com teste; bug ganha regressão antes do fix; suite verde é pré-condição de commit.
- **Segunda opinião sob demanda.** O Adversarial Evaluator (`peer-review.sh`) é opcional — recomendado quando o diff toca prod ou é caro de reverter.
- **Evoluir > criar.** Estender artefato existente antes de criar paralelo. `_v2` e "migro depois" nunca migra.
- **Memória durável entre sessões.** Fatos que sobrevivem à sessão viram memória atômica indexada; o resto morre com o contexto.
- **Escrita terse.** Fragmento > frase. Sem verborragia, sem AI slop.

## Como usar

Três modos de consumo — do mais simples ao mais isolado.

### 1. User-level (fonte única)

Clona pra `~/.claude`. Toda sessão de Claude Code na máquina herda skills, docs e hooks. Fonte única — melhorou aqui, melhorou em todo projeto.

```bash
git clone https://github.com/babarbosaf/way-of-work ~/.claude
```

O que é privado (scope pago, paths locais, roteamento de findings pra repos de negócio) vive em `config/*.local.json` — **gitignored, nunca versionado** — e faz merge sobre a base pública em runtime. Copie `config/model-policy.json` pra `config/model-policy.local.json` e preencha com seus valores.

#### `settings.json` é mínimo de propósito

O `settings.json` versionado carrega só o que faz o repo funcionar: os hooks de
enforcement, o statusline e o teto de auto-compact. Preferência pessoal não entra, e
nada que suprima confirmação entra também. Quem clona não herda modelo, idioma, plugin
habilitado nem prompt de permissão desligado.

O `settings.example.json` lista as chaves de preferência mais comuns com valores
neutros. Copie pro seu `settings.json` o que fizer sentido, ou rode com o mínimo.

Plugin é opt-in de quem adota, então nenhum marketplace vem habilitado:

```bash
claude plugin marketplace add <owner>/<repo>
claude plugin install <plugin>@<marketplace>
```

Verificação pós-instalação:

```bash
ls ~/.claude/skills                                            # skills presentes
git -C ~/.claude check-ignore config/model-policy.local.json   # override é ignorado
scripts/model-policy-effective.sh config/model-policy.json | jq .backends
```

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
