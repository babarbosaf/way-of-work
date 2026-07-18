---
spec: 2026-003
title: migrar ~/.claude para repo público GitHub "way-of-work"
rigor: governança
rubric: script
threshold: 4
status: aprovado
verify_cmd: "git -C ~/.claude grep -nIE 'exitlag|comercial-estrela|holding-imob|personal-os|/Users/beneditobarbosa' -- $(git -C ~/.claude ls-files | grep -v spec-2026-003) | grep -vE 'seu-projeto|your-project|FAKE_TEST_KEY|example|<external-data-repo>|<your-paid-scope>|<repo-de-dados>|<seu-repo>'"
---

# SPEC-2026-003 — way-of-work (publicar ~/.claude)

Versiona o setup Claude Code (`~/.claude`) como repo público que serve de base clonável pro piloto de `/schedule`+`/loop` e de template pra terceiros. Base pré-spec: `_tmp/plano-migracao-config-github-publico.md`.

---

## §1 Contrato

### Como fica

```
ANTES
  ~/.claude  (git repo, SEM remote)
    ├─ branch feature/issue-desdobramento-trackers
    ├─ config/model-policy.json  → scope exitlag + repo comercial-estrela
    ├─ hooks/emit_trace_guard.py → topologia comercial-estrela
    ├─ história do git contém dado de negócio em blobs antigos
    └─ consumo: nenhum (só a máquina do Benedito)

DEPOIS
  github.com/babarbosaf/way-of-work  (PÚBLICO, história fresca)
    ├─ config/model-policy.json  → genérico; routing de negócio em
    │    config/model-policy.local.json (gitignored)
    ├─ hooks/  → emit_trace_guard fora do template (local-only)
    ├─ README.md · LICENSE(MIT) · RUNBOOK.md(hub) · CONTRIBUTING.md
    ├─ docs/runbooks/adopt-way-of-work.md
    └─ ~/.claude do Benedito = clone deste repo (fonte única)

  Consumo (3 modos, documentados):
    1. user-level  — clone → ~/.claude; todo projeto herda
    2. cloud       — routine /schedule com sources=[repo-alvo, way-of-work]
    3. self-contained — projeto usa way-of-work como git submodule
```

### Decisões

**D-01 — Escopo = publicar (F0-F3).** Esta spec entrega o repo público sanitizado + docs de consumo. A skill `bootstrap-project` (automatiza scaffold de projeto) e o watcher `/schedule`+`/loop` (task 5) são **specs-filhas** (2026-004, 2026-005) que nascem *pelo* fluxo de PR do repo já publicado — dogfooding do modelo. Publicar não depende delas; elas dependem do repo vivo.

**D-02 — Distribuição A canônico + submodule.** `way-of-work` user-level é fonte única; `~/.claude` da máquina É o clone. Casos que pedem skills dentro do repo: multi-source na routine (cloud) e git submodule (self-contained). Nunca vendoring-cópia — mata o treadmill de sync e honra evolve>create.

**D-03 — Sanitização de `model-policy.json` = extração de privacidade via merge loader real.** O routing project-specific (scope `exitlag`, `.env` path, repo `comercial-estrela-data`) sai pra `config/model-policy.local.json` gitignored; os **rankings** (qual backend/modelo por task) ficam intactos e em fonte única no arquivo público. Como não altera ranking, não passa pela governança de proposta da linha 2 — é extração de privacidade. **Requer código:** hoje `delegate.sh:32` carrega só `model-policy.json`; a slice S2a implementa o merge (deep-merge de `.local.json` sobre a base, tolerando ausência em clone limpo). Sem o loader, a promessa "setup local continua roteando exitlag" seria fictícia (finding I1).

**D-04 — `emit_trace_guard.py` sai do tracking, sem sair do disco.** Carrega topologia de repo de negócio na lógica; genericizar arriscaria quebrar o hook. **Não move o arquivo** (mover quebraria o path no `settings.json` pra toda sessão): `git rm --cached` + exceção no whitelist. Arquivo permanece no disco, `settings.json` intocado, hook segue firing localmente — só não vai pro repo público. Untrack é operação de índice: **zero efeito runtime** nas sessões concorrentes.

**D-05 — LICENSE MIT.** Objetivo é ajudar terceiros a usar o modelo; MIT é permissiva e reconhecível. Trocável antes do publish.

**D-06 — Repo público, sem segredos (verificado).** Varredura de `sk-`/`ghp_`/`gho_`/`xox`/PEM/AKIA nos 100 tracked = vazio; email não aparece; `settings.json` usa `$HOME` (portável). O risco não é credencial — é topologia de negócio (D-03/D-04) e história (D-07).

**D-08 — Público mantém `specs/` como exemplos, exceto a própria spec-2026-003.** Specs 001/002 (ship-review evaluator, multi-model-dispatch) são doutrina limpa e servem de exemplo real do formato folder — ficam. A spec-2026-003 é meta-work sobre sanitizar config de negócio e cita `exitlag`/`comercial-estrela` por natureza — o scratch de publicação remove só a folder dela. `memory/`, `_tmp/`, transcripts já ficam fora pelo whitelist.

**D-07 — Publicar de checkout limpo em scratch, não de `~/.claude`.** A história atual do git contém dado de negócio em blobs antigos (≥2 revisões do `model-policy.json` com `exitlag`, confirmado). Publicar história completa vazaria mesmo com tree limpo. **Empurrar só uma branch fresca do mesmo `.git` é frágil** (finding C1): o `.git` mantém refs privadas e passa a apontar pra origin público — um `git push --all`, tag, ou branch errada re-vaza. Fix: o repo público nasce de um **`git init` em diretório scratch** populado só com o tree sanitizado (via `git archive` do estado limpo), commit único, push. `~/.claude` **nunca ganha origin público acoplado à história rica** — mantém sua história local intacta e privada.

### Critérios de aceite

- [ ] Nenhum arquivo trackeado cita nome de projeto de negócio (`exitlag`/`comercial-estrela`/`holding-imob`/`personal-os`) exceto placeholder genérico explícito
- [ ] Nenhum arquivo trackeado tem path `/Users/beneditobarbosa` (só `$HOME`/`~`)
- [ ] `delegate.sh` faz merge de `config/model-policy.local.json` sobre a base quando presente, e roda idêntico à base quando ausente (clone limpo)
- [ ] `config/model-policy.local.json` existe local, é ignorado pelo git, e o routing exitlag continua resolvendo via merge
- [ ] `config/model-policy.json` público é JSON válido e preserva os rankings intactos
- [ ] Um clone limpo do repo não contém nenhum dado pessoal (ver Definições) na árvore NEM em `git log --all -p`
- [ ] README documenta os 3 modos de consumo; RUNBOOK.md linka os runbooks específicos; CONTRIBUTING descreve o fluxo de PR upstream
- [ ] Repo `way-of-work` existe no GitHub como **público**; `~/.claude` NÃO tem origin acoplado à sua história rica
- [ ] Scripts de hook parseiam (`bash -n` / `py_compile`) e usam `$HOME` — nenhum path `/Users/beneditobarbosa` em tracked

### Fora de escopo

- Skill `bootstrap-project` (automatiza scaffold novo/adoção) → spec-2026-004
- Watcher GitHub Actions + piloto `/schedule`+`/loop` da task 5 → spec-2026-005
- Compactação do CLAUDE.md (thread separado, já rastreado no handoff)
- **Modo self-contained (submodule)** — documentado como how-to no README/adopt-runbook; **não validado end-to-end nesta spec**. Wiring real quando o 1º projeto self-contained pedir.

### Definições (pra grep-review não virar interpretação)

- **Dado pessoal** (deve sumir dos tracked): nome de projeto de negócio (`exitlag`, `comercial-estrela`, `holding-imob`, `personal-os` e derivados como `comercial-estrela-data`), path absoluto `/Users/beneditobarbosa`, e qualquer chave — mesmo fake — no formato `sk-…`/`ghp_…`.
- **Placeholder genérico** (permitido): `<seu-projeto>`, `<your-project>`, `example`, `FAKE_TEST_KEY`. Um match do grep que seja exatamente placeholder passa; qualquer outro bloqueia.

---

## §2 Design técnico

### Mudanças

1. **F0 baseline** — commitar edições uncommitted (`CLAUDE.md`, `docs/autonomy-loops.md`, `settings.json`, `.gitignore`); criar branch de publicação.
2. **F1a loader** — `delegate.sh`: deep-merge de `config/model-policy.local.json` sobre `model-policy.json` quando presente; ausência = comporta como hoje. Espelhar na policy default embutida se necessário.
3. **F1b sanitização** — a **fonte é o `verify_cmd`** (o grep), não hand-list; ele acha ~10 arquivos:
   - `config/model-policy.json`: extrair routing exitlag/comercial pra `config/model-policy.local.json`; genérico no público; **`config/*.local.json` no `.gitignore`** (senão o whitelist `!config/**` trackearia o override = vazamento).
   - `hooks/emit_trace_guard.py`: mover pra local-only; remover do whitelist; confirmar fora do `git ls-files`.
   - `tests/delegate.test.sh`: genericizar cenário exitlag; literal `sk-test-123` → `FAKE_TEST_KEY`.
   - Menções ilustrativas → placeholder: `skills/delegate/SKILL.md`, `skills/spec-and-plan/SKILL.md`, `references/{to-tickets,triage}.md`, `docs/adversarial-evaluator.md`, `docs/runbooks/multi-model-dispatch.md`, `hooks/templates/README.md`.
   - Path residual `/Users/beneditobarbosa` → `$HOME`: `scripts/higiene-repo-runner.sh`, `config/model-policy.json`.
4. **F2 docs de consumo** — `README.md` (3 modos), `LICENSE` (MIT), `RUNBOOK.md` (hub raiz linkando runbooks), `docs/runbooks/adopt-way-of-work.md`, `CONTRIBUTING.md`.
5. **F3 publish** — checkout scratch (`git init` + tree sanitizado, commit único); `gh repo create way-of-work --public`; push.

### Contratos com sistemas externos

- **GitHub via `gh`** — `gh repo create way-of-work --public --source ~/.claude --remote origin`. Autenticado como `babarbosaf` (verificado). Cria remote + push.
- **`config/model-policy.local.json`** — contrato de merge com o dispatcher (`delegate.sh`): deep-merge de local sobre a base, ausência tolerada. Implementado em S2a (não existia — `delegate.sh:32` só lia a base), provado por teste em S2a/S2b.

### Security — modelo de ameaça (vetor × defesa × risco residual)

| Vetor de vazamento | Defesa | Risco residual |
|---|---|---|
| Credencial/segredo em tracked | whitelist `.gitignore` + scan `sk-/ghp_/gho_/xox/PEM/AKIA` | **nenhum** (scan vazio) |
| Topologia de negócio (repo names, arquitetura) | D-03 extrai routing p/ local; D-04 remove emit_trace_guard; genericiza menções | menções ilustrativas → placeholder; verify grep = vazio |
| Username/path de máquina | `settings.json` já usa `$HOME`; 2 paths residuais → `$HOME` | username `babarbosaf` aparece no nome do repo/URL (aceito — é a conta pública) |
| **Dado de negócio na história do git** | D-07 publica de checkout scratch (`git init` novo, sem a história rica); `~/.claude` nunca ganha origin público | **nenhum acoplamento** — o `.git` público não deriva do `.git` privado; não há branch antiga alcançável por `push --all`/tag (finding C1 fechado) |
| Segredo em `settings.json` env/headers | leitura key-scoped; `env` = só toggles não-secretos (verificado) | nenhum |

### Rollback

| Cenário | Procedimento |
|---|---|
| Vazamento descoberto pós-publish | `gh repo edit babarbosaf/way-of-work --visibility private` imediato; se segredo, rotacionar; `gh repo delete` se necessário. **Aviso: público+indexado pode ficar em cache — unpublish não é garantido.** Por isso S5 (scan de clone limpo) é gate bloqueante ANTES de S6. |
| Sanitização quebrou o setup local | `model-policy.local.json` restaura routing; `git checkout` reverte tree. Edições são working-tree, revisáveis em `git diff` antes de commit. |
| Push empurrou história errada | Branch de publicação é órfã e isolada; `git push` explícito só dela. Se história rica vazar: força-reset da branch pública + re-scan. |

### Concorrência — `~/.claude` é config viva e compartilhada

Toda sessão Claude Code na máquina lê o mesmo `~/.claude` em runtime (hooks por invocação, skills/config por uso). Sessões concorrentes conhecidas: `ector`, `exitlag-operations-sp-platform`, `exitlag-operations-rocky` (as duas últimas casam com o scope_pattern `exitlag`). O build roda **single-shot** com mecânica atômica que zera o risco — sem esperar checkpoint, sem faseamento:

- **S1 commita só arquivos nomeados, nunca `git add -A`** — outra sessão pode ter edições em `~/.claude`; `-A` varreria pra branch errada. Checar `git status` antes; arquivo não-esperado → parar e coordenar.
- **S2b sem janela pra exitlag** — ordem: S2a (loader, backward-compat, não muda comportamento sozinho) → cria `model-policy.local.json` com o routing enquanto a base ainda tem (routing duplo, resolve) → strip da base por `mv` atômico (write-temp-rename). Routing exitlag nunca ausente; nenhuma sessão lê arquivo parcial.
- **S3 emit_trace_guard = zero runtime** — `git rm --cached` + gitignore, arquivo fica no disco, `settings.json` intocado (D-04). Além disso o hook só atua em `comercial-estrela`, que nenhuma das 3 sessões toca.
- **Toda edição de config compartilhada é escrita atômica** (temp + `mv` no mesmo filesystem) — leitura concorrente pega versão antiga OU nova, nunca meia.
- **Repos em curso não exigem migração** — herdam de `~/.claude` como hoje; o wiring local (S2b/S3) preserva exitlag/comercial idênticos. Adoção do modelo completo é opt-in (spec-004), não efeito colateral desta.

### Estratégia de testes

Spec de infra/publicação — "testes" são checks executáveis (verify_cmd por slice), não unit suite:
- **Contract:** `jq empty config/model-policy.json` (JSON válido pós-extração); `git check-ignore config/model-policy.local.json` (override ignorado).
- **Leak scan (o teste-mãe):** `git grep -nIE '<dados-pessoais>' -- $(git ls-files)` = vazio, rodado no tree E num clone limpo.
- **Smoke de clone:** clonar pra tmp, rodar o leak scan + `bash -n` nos scripts de hook (resolvem via `$HOME`).
- **History scan:** `git log -p -S'exitlag'` no repo publicado = vazio (história fresca).

---

## §3 Slices

Cada slice tem verify_cmd; para verde antes do próximo. `~` = `/Users/beneditobarbosa/.claude`.

**S1 — Baseline** `[XS]`
Commitar uncommitted (`CLAUDE.md`, `docs/autonomy-loops.md`, `settings.json`, `.gitignore`) na branch atual.
- _verify:_ `git status --porcelain` vazio.

**S2a — Loader de merge `.local.json`** `[S]` dep:S1 · **código, TDD**
`delegate.sh`: deep-merge de `config/model-policy.local.json` sobre a base; ausência = idêntico à base.
- _verify:_ teste em `tests/`: (a) com local presente, routing exitlag resolve; (b) sem local, saída idêntica à base; ambos verdes.

**S2b — Sanitizar model-policy (sem janela)** `[S]` dep:S2a
Ordem atômica: cria `config/model-policy.local.json` com o routing exitlag/comercial (base ainda tem) → `config/*.local.json` no `.gitignore` → strip da base por `mv` atômico → genérico público.
- _verify:_ `git grep -nE 'exitlag|comercial-estrela|/Users/beneditobarbosa' config/model-policy.json` vazio **E** `jq empty config/model-policy.json` **E** `git check-ignore config/model-policy.local.json` retorna o path **E** teste S2a verde (routing exitlag resolve via merge).

**S3 — Sanitizar restante** `[M]` dep:S1
Fonte = o grep. `emit_trace_guard.py` → `git rm --cached` + gitignore (fica no disco, D-04); `tests/delegate.test.sh` genérico + `FAKE_TEST_KEY`; menções → placeholder; path residual → `$HOME`. Edições de arquivo compartilhado por `mv` atômico.
- _verify:_ `git grep -nIE 'exitlag|comercial-estrela|holding-imob|personal-os|/Users/beneditobarbosa' -- $(git ls-files) | grep -vE 'seu-projeto|your-project|FAKE_TEST_KEY|example'` vazio **E** `git ls-files | grep emit_trace_guard` vazio **E** `test -f hooks/emit_trace_guard.py` (arquivo ainda no disco).

**S4 — Docs de consumo** `[M]` dep:S2b,S3
`README.md` (3 modos) · `LICENSE` MIT · `RUNBOOK.md` hub · `docs/runbooks/adopt-way-of-work.md` · `CONTRIBUTING.md`.
- _verify:_ os 5 arquivos existem; links relativos do `RUNBOOK.md` resolvem (`test -f` em cada alvo); leak scan (S3) segue vazio.

**S5 — Sanity de checkout scratch (GATE bloqueante)** `[S]` dep:S4
`git archive HEAD` do tree → extrai em tmp → **remove `specs/ongoing/spec-2026-003-*`** (D-08) → `git init` + commit único. Leak scan completo na árvore + `git log --all -p`; `bash -n` + `py_compile` nos hooks.
- _verify:_ no scratch — `git grep -nIE '<pattern completo>' -- $(git ls-files) | grep -vE '<placeholders>'` vazio **E** `git log --all -p | grep -E '<pattern completo>'` vazio **E** `bash -n` nos `.sh` + `python3 -m py_compile` nos `.py` sem erro.

**S6 — Publicar** `[XS]` dep:S5 · **irreversível, atrás de "go" explícito**
Do checkout scratch: `gh repo create way-of-work --public --source <scratch> --remote origin`; push único de `main` (sem `--all`, sem tags). `~/.claude` NÃO recebe origin.
- _verify:_ `gh repo view babarbosaf/way-of-work --json visibility -q .visibility` = `PUBLIC` **E** `git -C ~/.claude remote get-url origin` **falha** (sem origin acoplado).

Rastreabilidade: D-01→escopo/§4 · D-02→S4(docs) · D-03→S2a+S2b · D-04→S3 · D-05→S4 · D-06→S5 · D-07→S5(scratch+history scan)/S6.

---

## §4 Ao fechar

- Mover spec pra `specs/done/`.
- Atualizar handoff `_tmp/` (declara morte) ou apagar se absorvido.
- Abrir specs-filhas 2026-004 (`bootstrap-project`) e 2026-005 (watcher/piloto task 5) como próximos passos.
- Lição durável candidata → `/capture-lessons`: "história do git é vetor de vazamento em publicação de repo curado"; "whitelist gitignore re-morde overrides `*.local`".

---

## §5 Gate — Evaluator Status Block

```
Gate 1 (spec): critical_resolvido
reviewer: codex (peer-review.sh spec, --model auto)
round: 1 (sem round 2 — patch in-place, decisão típica; usuário revisa)

Critical:   C1 história acoplada ao .git público
            → RESOLVIDO: D-07 publica de checkout scratch (S5/S6)
Important:  I1 merge loader inexistente → S2a implementa+prova
            I2 history gate 1-token → S5 pattern completo em --all
            I3 "hooks resolvem" só sintaxe → AC rebaixado + py_compile
Suggestion: self-contained não-validado → §1 Fora de escopo
            definir dado pessoal/placeholder → §2 Definições
            S6 ref exata → absorvido por C1 (scratch, só main)

Detalhe: findings/pass-1.md
Status: aprovado (concorrência exitlag/comercial fechada por mecânica atômica — sem faseamento)
```
