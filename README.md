# way-of-work

Modelo de trabalho com agentes, versionado e público. O núcleo é agnóstico de modelo e de
harness: `AGENTS.md` como instrução única, skills como fase do ciclo, docs de doutrina e
testes que travam o que importa. Codex, Cursor, Copilot e qualquer ferramenta que leia
`AGENTS.md` consomem a mesma fonte, sem tradução.

A aplicação mais completa é em [Claude Code](https://claude.com/claude-code), que executa
skill, hook e statusline direto do `~/.claude`. A tabela abaixo marca o que é dessa camada;
o resto vale em qualquer lugar.

A porta de entrada do método é o `/kickoff-project`: projeto novo nasce de uma entrevista
dirigida que produz PRD, rotas, design, conventions e o AGENTS.md do próprio projeto.
Depois disso, docs vivos como fonte de verdade, TDD sempre, spec só pra feature grande e
memória durável entre sessões.

## O que tem dentro

| Área | O que é |
|------|---------|
| `AGENTS.md` | Instrução viva, agnóstica, lida por Codex, Cursor e qualquer harness que siga o padrão. `CLAUDE.md` é symlink. Terse, sem changelog, cada linha passa no teste "cortar isso faria o agente errar?". |
| `skills/` | Uma skill por fase do ciclo (taxonomia abaixo). O conteúdo é doutrina em markdown, então serve de leitura pra qualquer agente; o dispatch por `/comando` é do Claude Code. |
| `docs/` | Doutrina: `skill-authoring.md` (régua de autoria de skill, aplicada por `scripts/check-skill.py`), `evolve-over-create.md`, `autonomy-loops.md`, `adversarial-evaluator.md` (segunda opinião opcional) e runbooks em `docs/runbooks/`. |
| `scripts/` | Ferramenta em bash, roda em qualquer terminal: `peer-review.sh` (review adversarial), `delegate.sh` (despacho pra worker externo), `statusline.sh`. |
| `tests/` | Oito suítes, 216 asserts, sem rede e sem CLI real: despacho de modelo, review adversarial, os cinco hooks de enforcement, manifesto de plugins, linter de escrita, lint de spec e ticket, lint de skill, agnosticismo do repo e link markdown morto. |
| `specs/_TEMPLATE-spec/` | Formato de spec pra feature grande: contrato, design, slices, gate. |
| `FEEDBACK.example.md` | Formato do buffer de correção do projeto: uma linha por entrada com o gatilho embutido, teto de 10, regra de promoção. O `FEEDBACK.md` real é gitignored. |
| `config/model-policy.json` | Roteamento de modelos por task-type (base pública genérica, override privado via `*.local.json` gitignored). |
| `config/plugins.json` | Manifesto de plugins com o porquê de cada um, aplicado por `scripts/bootstrap-plugins.sh`. Todos opcionais. |
| `hooks/` | **Claude Code.** Cinco hooks de enforcement em runtime: grep-first em read grande, no-op bloqueado, lembrete de doc atualizada, append obrigatório no log de memória e guarda de tamanho do `CLAUDE.md`. A mensagem de bloqueio diz o que fazer no lugar, e cada um tem kill switch (ver Pré-requisitos). |
| `settings.json` | **Claude Code.** Só o mínimo que faz o repo funcionar. Preferência pessoal fica no `settings.example.json`. |

Histórico de release em [`CHANGELOG.md`](CHANGELOG.md).

Convenções estruturais:
- **`AGENTS.md` é a fonte, `CLAUDE.md` symlink.** Editar sempre o `AGENTS.md`.
- **`.gitignore` é allowlist:** ignora tudo (`*`), libera com `!`. O que é pessoal (scope pago, paths, roteamento) vive em `config/*.local.json`, gitignored, deep-merge em runtime.
- **Memória (`memory/`) não é versionada.** É comportamento do agente, específico da máquina.
- **Instrução viva, não changelog.** Docs de start-up não guardam histórico (→ `CHANGELOG.md`, ADR, memória).

### Skills

| Skill | Invocação |
|-------|-----------|
| [`kickoff-project`](skills/kickoff-project) | user-invoked (fundação de projeto novo por entrevista) |
| [`to-spec`](skills/to-spec) | user-invoked (contrato de feature grande) |
| [`to-tickets`](skills/to-tickets) | user-invoked (fatia a spec em tickets executáveis) |
| [`git-workflow-and-versioning`](skills/git-workflow-and-versioning) | model-invoked (inclui o gate de ship) |
| [`delegate`](skills/delegate) | model-invoked |
| [`coaching`](skills/coaching) | user-invoked (dois trilhos: Conversa e One-pager) |
| [`handoff`](skills/handoff) | user-invoked |
| [`capture-lessons`](skills/capture-lessons) | user-invoked |
| [`design-workflow`](skills/design-workflow) | model-invoked (componente ou tela visual nova) |
| [`writing`](skills/writing) | model-invoked (doutrina de escrita, catálogo anti-slop e linter) |

**model-invoked** dispara sozinha quando o fluxo bate o gatilho (fase do ciclo, gate pré-ship). **user-invoked** você aciona por `/comando` num momento deliberado.

## Sete regras

- **Fundação por entrevista.** Projeto novo nasce pelo `/kickoff-project`: entrevista dirigida → PRD, ROUTES, DESIGN, CONVENTIONS, AGENTS.md e FEEDBACK.md. Nada de formulário em branco.
- **Docs vivos são a fonte de verdade.** Decisão de produto edita o PRD; padrão técnico, o CONVENTIONS; correção vira entrada no FEEDBACK.md (buffer com teto e promoção). Spec só pra feature grande, em 1 arquivo descartável. Ao shippar, a verdade migra pro PRD.
- **TDD sempre.** Comportamento novo nasce com teste; bug ganha regressão antes do fix; suite verde é pré-condição de commit.
- **Segunda opinião sob demanda.** O Adversarial Evaluator (`peer-review.sh`) é opcional, recomendado quando o diff toca prod ou é caro de reverter.
- **Evoluir > criar.** Estender artefato existente antes de criar paralelo. `_v2` e "migro depois" nunca migra.
- **Memória durável entre sessões.** Fatos que sobrevivem à sessão viram memória atômica indexada; o resto morre com o contexto.
- **Escrita terse.** Fragmento > frase. Sem verborragia, sem AI slop.

## Como usar

Três modos de consumo, do mais simples ao mais isolado.

### 1. User-level (fonte única)

Clona pra `~/.claude`. Toda sessão de Claude Code na máquina herda skills, docs e hooks. Fonte única: melhorou aqui, melhorou em todo projeto.

```bash
git clone https://github.com/babarbosaf/way-of-work ~/.claude
```

O que é privado (scope pago, paths locais, roteamento de findings pra repos de negócio) vive em `config/*.local.json`, **gitignored, nunca versionado**, e faz merge sobre a base pública em runtime. Copie `config/model-policy.json` pra `config/model-policy.local.json` e preencha com seus valores.

#### `settings.json` é mínimo de propósito

O `settings.json` versionado carrega só o que faz o repo funcionar: os hooks de
enforcement, o statusline e o teto de auto-compact. Preferência pessoal não entra, e
nada que suprima confirmação entra também. Quem clona não herda modelo, idioma, plugin
habilitado nem prompt de permissão desligado.

O `settings.example.json` lista as chaves de preferência mais comuns com valores
neutros. Copie pro seu `settings.json` o que fizer sentido, ou rode com o mínimo.

Plugin é opt-in, então nenhum marketplace vem habilitado no `settings.json`. Os que o
modelo de trabalho usa estão declarados em `config/plugins.json`, com o porquê de cada um,
e nenhum é pré-requisito:

```bash
scripts/bootstrap-plugins.sh            # dry-run: mostra os comandos
scripts/bootstrap-plugins.sh --apply    # instala
```

Plugin de conta (Slack, Linear, Notion) fica de fora da base: o nome do workspace conta
quem você é. Declare esses em `config/plugins.local.json`, que é gitignored e faz merge
sobre a base, mesma convenção do `model-policy`.

#### Pré-requisitos

| ferramenta | pra quê | sem ela |
|---|---|---|
| `python3` | os cinco hooks de enforcement e o linter de escrita | hook e linter não rodam |
| `jq` | merge dos overlays `*.local.json` (`model-policy`, `plugins`) | `model-policy-effective.sh` e `bootstrap-plugins.sh` abortam |
| context7 MCP | a doutrina manda consultar doc de lib atualizada antes de escolher API | a regra existe e não tem como ser cumprida |
| `rtk` | comprime a saída dos comandos antes de entrar no transcript | nada: o hook sai limpo e o comando roda normal |

Só `python3` e `jq` são de fato necessários. O context7 se instala por comando, com a key
grátis de `context7.com/dashboard`:

```bash
claude mcp add --scope user --header "CONTEXT7_API_KEY: SUA_KEY" \
  --transport http context7 https://mcp.context7.com/mcp
```

Detalhes e a alternativa local por `npx` em [`docs/research/context7.md`](docs/research/context7.md).
O `rtk` é opcional e sai por `brew install rtk` (ver [`docs/rtk.md`](docs/rtk.md)).

Cada hook tem kill switch por variável de ambiente, pra quando o enforcement estorvar em
vez de ajudar: `READ_GUARD_DISABLED=1`, `NOOP_GUARD_DISABLED=1`,
`CONTEXT7_REMINDER_DISABLED=1`, `MEMORY_HOOK_DISABLED=1`, `CLAUDE_MD_GUARD_DISABLED=1`.

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

Melhoria nasce no uso real: você trabalha num projeto, sente a dor, ajusta a skill, propõe upstream. Fluxo em [`CONTRIBUTING.md`](CONTRIBUTING.md).

## Licença

MIT, veja [`LICENSE`](LICENSE).
