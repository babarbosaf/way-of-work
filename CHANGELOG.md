# Changelog

Formato [Keep a Changelog](https://keepachangelog.com/pt-BR/1.1.0/);
versionamento [SemVer](https://semver.org/lang/pt-BR/).

## [Unreleased]

### Added

- **Skill `kickoff-project`** (fork de [iagodemacedo/kickoff-project](https://github.com/iagodemacedo/kickoff-project),
  adaptado): fundação de projeto novo por entrevista dirigida → `PRD.md`,
  `ROUTES.md`, `DESIGN.md`, `CONVENTIONS.md`, `CLAUDE.md`, `AGENTS.md`,
  `FEEDBACK.md`, `TODOS.md`. Adaptações: fase CONVENTIONS na cascata (cisão
  PRD × conventions com regra de fronteira "usuário percebe → PRD"),
  `FEEDBACK.md` com teto (~30) e regra de promoção, seção Execução (TDD/YAGNI)
  no AGENTS.md gerado, `STRATEGY.md` opt-in, herança de fundação de design,
  stack default da casa (ADR-0001), exemplos Chutaí com `CONVENTIONS.md` novo
  extraído do PRD.

### Changed

- **Modelo de trabalho vira 3 modos** (substitui o ciclo de 5 elos): projeto
  novo → `/kickoff-project`; feature grande → spec de 1 arquivo em
  `docs/specs/<slug>.md`; resto → direto no código com TDD. Docs vivos como
  fonte de verdade; lição roteada pra `FEEDBACK.md` (projeto) ou memória
  (global).
- **Adversarial Evaluator vira opcional** — sem Status Block obrigatório, teto
  de rounds ou estado que bloqueia ship; recomendado quando o diff toca prod ou
  é caro de reverter. `spec-and-plan` (spec 1 arquivo, sem folder/rubric/
  ongoing-done), `git-workflow-and-versioning` (gate: testes + segurança +
  docs vivos; `/simplify` recomendado) e `capture-lessons` (roteador de 2
  destinos) reescritas de acordo.

### Removed (→ `archive/`)

- `docs/way-of-working.md` (7 cadeias), `project-template/` (24 arquivos) e
  `docs/rubrics/` — substituídos pela fundação gerada pelo kickoff + docs
  vivos. References de spec-folder e roteamento modelo-v2 das skills.

- **Simplificação do modelo de trabalho** (~9k linhas cortadas). Ciclo enxuto:
  `coaching → spec-and-plan → build TDD → ship → capture-lessons`.
- `ship-review` fundida em `git-workflow-and-versioning` como checklist único
  de gate de ship; `/simplify` vira passo obrigatório (REFACTOR do TDD e eixo
  do gate).
- `spec-and-plan` lite: sai tiering de cerimônia, detecção de modelo de docs e
  vocabulário Zona 1/2; fica contrato D-NN + ACs SIM/NÃO + tasks + gates do
  Evaluator.
- `test-and-debug` vira 3 regras de teste no `AGENTS.md`.
- Doutrina de escrita consolidada em `docs/research/escrita.md`
  (caveman + anti-slop); `CONTEXT.md` e o runbook de adoção dobram no `README.md`.
- Cadeia de hooks `PreToolUse:Bash` cai de 5 pra 2 (só bloqueantes/proxy);
  nudges de commit removidos.
- Governança do `model-policy.json` removida — edição direta, git é o histórico.

### Removed

- `refresh-model-rankings` (skill + cron), `higiene-repo-runner` (launchd),
  `skill-creator`, symlinks de skills desligadas, testes de hook sem runner.

## [0.1.0] - 2026-07-13

Primeira release pública do way-of-work — o modelo de trabalho com agentes de
um dev, versionado pra quem quer adotar.

### Added

- **Ciclo de desenvolvimento** como skills invocáveis: `spec-and-plan`,
  `test-and-debug`, `ship-review`, `git-workflow-and-versioning`, `delegate`,
  `handoff`, `capture-lessons`, `coaching`, `skill-creator`,
  `refresh-model-rankings`.
- **AGENTS.md como fonte única** (padrão agnóstico, lido por Codex/Cursor/etc.)
  com `CLAUDE.md` como symlink — instrução viva, sem changelog embutido.
- **Adversarial Evaluator** (`scripts/peer-review.sh`) sobre spec e diff,
  classificando achados Critical/Important/Suggestion, com rubrics scored 1-5.
- **Hooks de enforcement** (`hooks/`): grep-first em reads grandes, guarda de
  no-op, lembrete de doc atualizada (context7). A mensagem de bloqueio ensina.
- **Doc-system transferível:** `project-template/` (scaffold clonável com hub
  docs, `docs/<área>/` e `_TEMPLATE-*`) + `docs/way-of-working.md` (as cadeias
  de proveniência) + `.claude/project.yaml` (metadata machine-readable).
- **Template de spec** (`specs/_TEMPLATE-spec/`) no formato §1-§5.
- **Modos de adoção:** user-level (`~/.claude`), cloud multi-source, submodule.
- Convenção público/privado: base versionada + `*.local.json` gitignored que
  faz merge em runtime; `.gitignore` allowlist.
