# Changelog

Formato [Keep a Changelog](https://keepachangelog.com/pt-BR/1.1.0/);
versionamento [SemVer](https://semver.org/lang/pt-BR/).

## [Unreleased]

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
