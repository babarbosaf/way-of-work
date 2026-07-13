# CONTEXT.md — fatos do repo

Orientação factual pra um agente que trabalha neste repo. Não é doutrina (isso
é `AGENTS.md`, carregado toda sessão) nem guia de adoção (isso é `README.md`).

## Layout

| Dir | O que vive |
|-----|-----------|
| `skills/` | Uma pasta por skill, cada uma com `SKILL.md`. São as fases do ciclo de desenvolvimento. |
| `docs/` | Doutrina de raiz (`adversarial-evaluator.md`, `evolve-over-create.md`, `autonomy-loops.md`, `way-of-working.md`), `rubrics/` (scored 1-5 pro Evaluator), `runbooks/` (humano no loop), `research/` (insumo bruto). |
| `hooks/` | Enforcement em runtime + `hooks/templates/` (esqueletos de hook). |
| `config/` | `model-policy.json` (roteamento de modelo por task-type). Override privado = `*.local.json`, gitignored, merge em runtime. |
| `scripts/` | `peer-review.sh` (Adversarial Evaluator), `delegate.sh` (dispatch pra worker barato). |
| `specs/` | `ongoing/`, `done/`, e `_TEMPLATE-spec/` (formato §1-§5). Cada spec é uma folder. |
| `tests/` | Testes do tooling (ex.: `delegate.test.sh`). |
| `project-template/` | Scaffold clonável do doc-system pra um projeto novo (só existe aqui, não se usa in-place). |

## Peças e onde se conectam

- **Delegação:** `scripts/delegate.sh` lê `config/model-policy.json` (task-type → backend/model). `--model` = nome de BACKEND, não string de modelo.
- **Adversarial Evaluator:** `scripts/peer-review.sh {spec|diff} <arg>`, cascata `codex → gemini`. Detalhe: `docs/adversarial-evaluator.md`.
- **Memória durável:** `memory/` (atômicas + `MEMORY.md` índice hub-first). Não versionado — é comportamento do agente, específico da máquina.
- **Público vs privado:** base versionada; o que é pessoal (scope pago, paths, roteamento de findings) vive em `*.local.json` gitignored. O `.gitignore` é allowlist: ignora tudo (`*`), libera com `!`.

## Convenções

- **AGENTS.md é a fonte, CLAUDE.md symlink.** Editar `AGENTS.md`; `CLAUDE.md` resolve pro mesmo conteúdo.
- **Instrução viva, não changelog.** Docs de start-up (`AGENTS.md`, `README.md`) não guardam histórico — isso vai pro `CHANGELOG.md`, ADR, ou memória.
- **Doc-system transferível:** `docs/way-of-working.md` ensina as cadeias (research→decisão, spec→PRD→changelog, etc.). É o "trabalhar como eu trabalho" escrito.
