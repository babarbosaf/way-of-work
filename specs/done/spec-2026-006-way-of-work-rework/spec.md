---
name: spec-2026-006-way-of-work-rework
status: done
rigor: governança
rubric: script
threshold: 4
verify_cmd: "bash /Users/beneditobarbosa/.claude/tests/delegate.test.sh"
---

# spec-2026-006 — way-of-work: rework + agent-agnostic + i18n

> Sequela da spec-2026-003 (migração, já publicada). Aqui: limpar slop,
> tornar agent-agnostic (AGENTS.md), organizar como as refs públicas
> (superpowers, mattpocock/skills), e traduzir pra EN por último.

## 1. Contrato

### Como fica

```
ANTES (publicado hoje = errado)   DEPOIS (v0)
─────────────────────            ─────────────────────
CLAUDE.md "user-level",          AGENTS.md canônico (agnóstico)
 slop histórica, RTK              CLAUDE.md → symlink
sem AGENTS.md                    CONTEXT.md (fatos do repo)
sem CHANGELOG                    CHANGELOG.md (release inicial único)
specs reais (001/002)           specs/_TEMPLATE-spec (só formato)
templates/ não-usado            (removido)
RTK + keybindings pessoais      (só no live; fora do público)
sem scaffold de projeto          project-template/ (doc-system clonável)
sem doutrina do modelo           docs/way-of-working.md (as cadeias)
sem project.yaml de exemplo      project-template/.claude/project.yaml
história com o push errado       história limpa (repo re-nasce = v0)
tudo em PT                      EN (gate final)
```

O que subiu hoje (saída da 003) é tratado como **descartável**: o público
re-nasce como **v0**, história limpa, sem rastro da versão errada (D-12).

Live `~/.claude` e público divergem por desenho (D-04): estrutura entra
nos dois em PT; só tradução EN e corte-pessoal são exclusivos do público.

### Decisões

**D-01 — AGENTS.md canônico, CLAUDE.md vira symlink.** `AGENTS.md` (padrão
Agentic AI Foundation, lido por Codex/Cursor/Copilot/etc.) passa a ser a
fonte única; `CLAUDE.md` = symlink pra ele (git rastreia symlink; Claude Code
resolve no session-start). Trade-off aceito: mecânica Claude-específica (hooks,
kill-switches, dispatch de Skill) fica visível no arquivo dito portável — vive
numa seção marcada "Claude Code specifics", não espalhada.

**D-02 — skills ficam flat, taxonomia documentada.** Poucas skills (ordem de
dezena) não justificam
nesting (superpowers=flat até dezenas). Pastas não movem (não quebra paths no
CLAUDE.md nem cross-refs). README ganha tabela user-invoked vs model-invoked —
o valor do split do Pocock sem o custo de mover arquivo.

**D-03 — RTK e bits pessoais saem do público.** Removidos do público: seção
RTK, `docs/rtk.md`, `scripts/rtk-hook-wrapper.sh`, `keybindings.json`. Motivo:
exigem binário externo `rtk` que ninguém tem, são específicos do Benedito, e
carregam a slop histórica. Live `~/.claude` mantém tudo.

**D-04 — divergência híbrida live↔público, fluxo `live → sanitize → público`.**
Fonte operacional única = live `~/.claude` (PT). O público é **derivado** por um
passo de transformação (remove D-03 + traduz EN); nunca se edita o público como
origem. Mudança estrutural (AGENTS/CLAUDE split, CONTEXT, CHANGELOG, cleanup,
specs-template) nasce no live e desce pro público pelo sanitize. Isso mata o
dual-writer: um escritor (live), um derivador (sanitize). O passo de sanitize é
manual nesta spec (script reprodutível = candidato spec-005); a garantia contra
drift é o leak scan por-slice, não a reconciliação a olho.

**D-05 — CHANGELOG.md Keep-a-Changelog v1.1.0.** Seções Added/Changed/Fixed/
Removed/Security + Unreleased, topo mais recente, pareado com SemVer. Histórico
sai do arquivo sempre-carregado pra cá — bate com a regra "instrução viva, não
changelog". **Primeira entrada = release inicial único (`[0.1.0]`), o "primeiro
trabalho que fizemos".** Não cita a publicação anterior (003) como release prévio
nem a descreve — sob o framing v0 (D-12), aquela versão não existe na história.

**D-06 — specs viram template no público.** Público remove `specs/done/002` e
`specs/ongoing/001` (planos reais, não exemplo) e ganha `specs/_TEMPLATE-spec/`
(spec.md placeholder + rubric.md + findings/.gitkeep). Live mantém specs reais.

**D-07 — corte de lixo seletivo.** `templates/action-plan/` (não-usado) e
`keybindings.json` (pessoal) removidos. `hooks/templates/` FICA — é referenciado
no CLAUDE.md e serve de exemplo genérico de hook.

**D-08 — tradução EN é gate terminal.** Traduzir só depois dos slices de
conteúdo aprovados e feitos. Re-passar anti-slop no texto EN (slop tem assinatura
diferente em inglês). Nada de traduzir no meio do caminho.

**D-09 — `project-template/` estático (scaffold do doc-system).** Os 3 repos de
negócio (ector, marketing, sp-platform) convergem no mesmo esqueleto de docs; o
público hoje shippa só a config do agente (skills/hooks), não a planta. O template
entrega o **núcleo** clonável: hub docs raiz em CAIXA ALTA com blockquote "papel
deste doc" (`README, AGENTS+CLAUDE symlink, STRATEGY, PRD, CONVENTIONS, RESEARCH,
RUNBOOK, CHANGELOG, CONTRIBUTING, INBOX`) + `docs/{prd,design,conventions/{adrs,
recipes},research,runbooks,specs}` cada um com `_TEMPLATE-*`. **Opcionais** (`ROUTES,
SECURITY, TODOS, PRODUCT, BRAND` e `DESIGN` além do núcleo) entram como **stub
comentado** com blockquote "apague se não há X" — mesmo padrão do DESIGN.md dos
repos. Escopo desta spec = template **estático**; automatizar o scaffold é a
`spec-004 bootstrap-project` (dogfooding pelo PR do repo vivo). DDR é cidadão de
1ª classe: `_TEMPLATE-DDR.md` mora em `docs/design/` (decisão de design → pasta
design; é onde os 3 repos põem), par conceitual do ADR em `docs/conventions/adrs/`
— pastas distintas, distinguidas pelo prefixo. Template genérico não tem DDR.

**D-10 — `docs/way-of-working.md` (doutrina que torna o modelo transferível).**
O scaffold sem a doutrina é planta sem legenda. Este doc ensina as **cadeias**:
(a) proveniência de pesquisa `INBOX → docs/research/ → RESEARCH.md → ADR/DDR`
("research é insumo, não veredito"); (b) ciclo de spec `ongoing → done → docs/prd/
<sistema> + CHANGELOG (ponteiro, não resumo)`; (c) espinha de produto `STRATEGY
(porquê) → PRD (o quê) → DESIGN (pele) → ROUTES (navegação) → CONVENTIONS (como)`;
(d) 3 espécies de decisão `ADR (técnico) · DDR (design/UX) · ADR-Spec (local)`,
aceito imutável só superseded; (e) runbook (humano no loop) vs recipe (agente
sozinho), teste do executor-default; (f) molde/instância + regra CAIXA-ALTA (papel
de raiz) vs lowercase (slug de instância, é funcional — skill faz glob); (g) raiz
= estado atual, nunca decision log. É o "work like me" escrito.

**D-11 — `project.yaml` no scaffold, vinculado ao TODOS.md.** O template inclui
`project-template/.claude/project.yaml` (schema lean: `tracker{backend,database,
initiative}`, `executable_states`, `repo{trunk,branch_prefix}`, `verify_cmd`,
`smoke_cmd`, `pipeline_paths`) — metadata machine-readable que as skills leem
(fallback chain `project.yaml → CLAUDE.md project-level → prompt`). O `TODOS.md`
do template referencia esse arquivo explicando **onde a task vive** ("aqui ou
ali"): `TODOS.md` = fila local curta; o tracker canônico (github/notion/linear)
declarado em `project.yaml` = fonte da verdade de execução. Sem token de negócio:
IDs de board/DB reais dos repos ficam fora; o template usa placeholders. A doutrina
(D-10) lista **quais skills leem quais campos** (`spec-and-plan`/`ship-review`/
`git-workflow` já consomem a fallback chain — SUG-3 do round 2), pra consumidor do
scaffold não adivinhar o que `pipeline_paths`/`smoke_cmd` fazem.

**D-12 — v0 = história limpa, o "primeiro trabalho que fizemos".** O que subiu
na 003 é descartado. O público **re-nasce** de checkout scratch (`git init` novo,
tree sanitizado, commit único), mesmo mecanismo da 003 (D-07 daquela spec) — não
commit-por-cima da história errada. `~/.claude` nunca ganha origin acoplado à
história rica. Substitui o Rollback "reversível por novo commit" da versão
anterior desta spec: sob v0 o repo público é substituído, não emendado.

### Critérios de aceite

- SIM: `AGENTS.md` existe no público e no live; `CLAUDE.md` resolve pro mesmo
  conteúdo via symlink; título não diz "user-level".
- SIM: `git grep -i "headroom removido\|incidente 2026"` no público = 0 (slop
  histórica morta).
- SIM: público não contém `rtk`, `keybindings.json`, `templates/action-plan/`.
- SIM: `CHANGELOG.md` existe e passa: tem seção `## [Unreleased]`, ordem
  topo-mais-recente, e só usa seções permitidas (Added/Changed/Deprecated/
  Removed/Fixed/Security); primeira release = `[0.1.0]` (inicial único) e NÃO
  cita/descreve a publicação anterior (003) como release prévio.
- SIM: público tem `specs/_TEMPLATE-spec/` e nenhum `specs/**/spec-2026-*`.
- SIM: `project-template/` existe no público com o núcleo completo — cada hub
  doc raiz de CAIXA ALTA (`ls project-template/*.md` cobre README/AGENTS/CLAUDE/
  STRATEGY/PRD/CONVENTIONS/RESEARCH/RUNBOOK/CHANGELOG/CONTRIBUTING/INBOX) e cada
  `project-template/docs/<área>/` tem um `_TEMPLATE-*`; opcionais presentes como
  stub com blockquote "apague se não há X".
- SIM: `project-template/.claude/project.yaml` existe, é YAML válido com o schema
  completo do D-11 (`tracker{backend,database,initiative}`, `executable_states`,
  `repo{trunk,branch_prefix}`, `verify_cmd`, `smoke_cmd`, `pipeline_paths` — os 2
  últimos comentados/opcionais com nota, SUG-1 do round 2), usa placeholders
  (nenhum ID de board/DB real); `project-template/TODOS.md` referencia o
  `project.yaml` e explica "task vive aqui (fila local) ou ali (tracker canônico)".
- SIM: `docs/way-of-working.md` existe e cobre as 7 cadeias do D-10 (research→
  decisão, spec→PRD→changelog, espinha STRATEGY→…→CONVENTIONS, ADR/DDR/ADR-Spec,
  runbook vs recipe, molde/instância + CAIXA-ALTA/lowercase, raiz≠decision-log).
- SIM: v0 = história limpa — clone do público tem **1 commit** (`git -C <clone>
  rev-list --count HEAD` = 1); `~/.claude` não tem origin acoplado à história rica.
- SIM: README tem tabela taxonomia com exatamente **uma linha por diretório em
  `skills/*/`** do público (fonte da contagem = `ls -d skills/*/`), cada uma
  marcada user-invoked ou model-invoked.
- SIM: gate anti-slop (S6, contrato em §2) roda em todo `.md` e devolve 0
  achados Critical; achados corrigidos e re-scan limpo.
- SIM (gate final, bloqueia publish): todo `.md` do público em inglês; e
  `delegate.test.sh` = **0 failed** (verde absoluto) — não sobe repo com teste
  vermelho. Se vermelho, corrigir antes do push, não publicar.
- SIM: live `~/.claude` segue PT, mantém RTK/keybindings/specs reais, suite verde.
- SIM: ao fechar (S8), spec-003 e spec-006 em `specs/done/`, handoffs apagados,
  lição durável capturada.
- NÃO: nenhum token de negócio, codename, path de máquina, ou repo privado
  (`exitlag|comercial-estrela|holding-imob|personal-os|ector|llm-wiki|
  /Users/beneditobarbosa`) no público.

### Fora de escopo

- Skill nova (bootstrap-project = spec-004; watcher = spec-005). Automatizar o
  scaffold do `project-template/` é a 004 — aqui o template é **estático** (D-09).
- Docs de domínio específico no scaffold (`okf/` bundle, `business-plan/`,
  `content-planning/`, `BRAND.md`): aparecem em 1 repo cada, não são o núcleo
  transferível — ficam fora do template.
- GEMINI.md / adapters multi-harness reais (D-01 deixa a porta aberta, não cria).
- Mudar mecânica de hook, dispatch de delegate, ou policy de modelo.
- Reescrever conteúdo de doutrina (só reestruturar/deslop/traduzir, não mudar regra).

## 2. Design técnico

### Mudanças (por slice, ver §3)

Matriz live↔público (a fonte do "híbrido", D-04):

| Item | Live `~/.claude` | Público |
|---|---|---|
| AGENTS.md reestruturado | sim (PT) | sim (EN, gate) |
| CLAUDE.md → symlink | sim | sim |
| CONTEXT.md (fatos do repo fora do sempre-carregado) | sim (PT) | sim (EN) |
| CHANGELOG.md | sim (PT) | sim (EN) |
| matar slop histórica | sim | sim |
| RTK (seção+doc+wrapper), keybindings.json | **mantém** | **remove** |
| templates/action-plan | remove | remove |
| hooks/templates | mantém | mantém |
| specs reais | mantém | remove |
| specs/_TEMPLATE-spec | adiciona | adiciona |
| project-template/ (scaffold doc-system) | n/a¹ | adiciona |
| project-template/.claude/project.yaml | n/a¹ | adiciona (placeholders) |
| docs/way-of-working.md (doutrina) | n/a¹ | adiciona |
| tabela taxonomia (README) | n/a¹ | sim |
| história do repo | rica, privada, intocada | v0 limpa (re-init scratch, 1 commit) |
| tradução EN | não | sim |

¹ Artefato de distribuição — só existe no público. Live opera direto em
`~/.claude`, não precisa do scaffold/doutrina/README pra si.

### Contratos com sistemas externos

N/A. Único acoplamento novo: symlink `CLAUDE.md → AGENTS.md` — Claude Code
resolve symlink no session-start (verificado: leitura de arquivo segue link).

### Security / risco

- **Concorrência (config viva).** 3 sessões leem `CLAUDE.md` em runtime. Risco:
  janela entre remover CLAUDE.md e criar o symlink. Defesa: criar `AGENTS.md`
  como arquivo novo completo PRIMEIRO (validar conteúdo), depois trocar CLAUDE.md
  por symlink com `ln -sfn` (near-atômico); sessões leem no start, não em loop.
  Risco residual: baixo (uma sessão que iniciar no exato instante da troca).
- **Push público irreversível.** Mesmo threat-model da 003: sem token de negócio,
  codename, path de máquina, repo privado, segredo. Gate de leak reusa o pattern
  ESTENDIDO da 003 (inclui `ector|llm-wiki`) antes de todo push.
- **Divergência que reintroduz vazamento.** Editar live e público em paralelo
  pode ressuscitar conteúdo privado no público. Defesa: leak scan roda no set
  do público a cada slice que toca `.md`, não só no fim.

### Rollback

- Live: `git -C ~/.claude revert <sha>` (cada slice = 1 commit atômico ~100L).
  Symlink quebrado → `git checkout CLAUDE.md` restaura o arquivo real.
- Público: sob v0 (D-12) o repo re-nasce de scratch a cada publish — rollback =
  re-gerar o tree sanitizado e re-`git init`/force-push (repo `main`-only, 1
  commit, sem tag). Vazamento pós-push descoberto: `gh repo edit --visibility
  private` imediato; se segredo, rotacionar; `gh repo delete` se necessário.
  **Aviso: público+indexado pode ficar em cache — unpublish não é garantido**;
  por isso o leak scan por-slice + smoke de publicação são gate ANTES do push.
- **Artefatos público-only** (`project-template/`, `docs/way-of-working.md`) NÃO
  derivam do live (D-04 marca "n/a" no live) — "re-gerar o tree" acima não os
  recupera de fonte viva. Recovery deles = re-executar S5a/S5b conforme a spec
  (IMP-3 do round 2). Sem perda de dado de prod (são artefatos novos), mas o
  procedimento é re-build, não re-derivação.
- Slice bloqueado no meio preserva parciais: cada slice commita atômico só ao
  ficar verde; interrupção deixa a árvore no último slice bom (nada meio-escrito
  no tracked), retomada parte do próximo slice sem re-derivar.

### Estratégia de testes

- **Unit/contract:** `delegate.test.sh` **verde (0 failed)** no live — gate
  absoluto, bloqueia publish. Baseline real = **47/0** (rodado limpo). A falha
  `usou agy direto` reportada no round 2 foi falso-positivo: `DELEGATE_POLICY`
  temp do reviewer vazou pro `verify_cmd` e remapeou o pool agy — não é bug do
  código. Não subir com teste vermelho: se quebrar de verdade num slice, corrigir
  antes de seguir (não tolerar regressão).
- **Leak scan:** pattern estendido no set do público = 0, por slice `.md`.
- **Symlink resolve:** `readlink CLAUDE.md` = `AGENTS.md` E `cat CLAUDE.md`
  devolve o conteúdo (não link).
- **Anti-slop (contrato do gate S6):**
  - _Input:_ lista de todos os `.md` do público (`git ls-files '*.md'`).
  - _Reviewer:_ subagent fable (effort low), 1 por lote de arquivos, prompt =
    checklist derivado (vocab `leverage/robust/seamless/crucial`, construção
    "não é só X, é Y", tríades, transições-filler `Furthermore/Moreover`,
    em-dash splice >1/parágrafo, hedging, parágrafo-resumo vazio).
  - _Output (schema):_ por arquivo, lista de achados `{file, line, trecho,
    regra_violada, severidade: Critical|Minor}`. Critical = slop que muda/ofusca
    o sentido técnico; Minor = estilo.
  - _Critério de falha:_ qualquer `severidade=Critical` bloqueia; corrigir e
    re-rodar até 0 Critical. Minor é opcional (decisão do autor).
- **Smoke publicação:** `git -C <public> ls-files` bate com a matriz; nenhum
  `spec-2026-*` no público; nenhum arquivo pessoal (D-03); `project-template/`
  e `docs/way-of-working.md` presentes; `rev-list --count HEAD` = 1 (v0 limpo).
- **Scaffold válido:** cada `project-template/docs/<área>/` tem `_TEMPLATE-*`;
  `project.yaml` parseia (`python -c yaml.safe_load`) e não tem ID de board/DB real.

## 3. Slices

Ordem: deletar lixo → canônico+changelog → org (README+scaffold+doutrina) →
slop gate → [aprovação] → EN → publish v0. Cada slice = 1 commit atômico no live
(quando aplicável) + patch no scratch/público.

**S1 — cortar lixo.** Remover `templates/action-plan/`, `keybindings.json`
(público; live corta só action-plan). Público: `git rm` specs reais.
_Pronto:_ matriz D-07 batida; leak scan 0.

**S2 — specs viram template.** Criar `specs/_TEMPLATE-spec/` (spec.md placeholder
+ rubric.md + findings/.gitkeep) no live e no público. Ajustar ref em spec-and-plan
se apontar pra spec real. _Pronto:_ público sem `spec-2026-*`, template presente.

**S3 — AGENTS.md canônico + CLAUDE.md symlink.** Reestruturar conteúdo do
CLAUDE.md atual em AGENTS.md (ordem de seção disciplinada; tirar "user-level";
seção "Claude Code specifics" isola hooks/kill-switches; matar slop histórica
D-05). `ln -sfn AGENTS.md CLAUDE.md`. Live e público (público sem RTK, D-03).
_Pronto:_ symlink resolve; grep slop=0; `delegate.test.sh` verde.

**S4 — CONTEXT.md + CHANGELOG.md.** Extrair fatos-do-repo do AGENTS.md pra
`CONTEXT.md` (estilo Pocock). Criar `CHANGELOG.md` Keep-a-Changelog com release
inicial único `[0.1.0]` (o "primeiro trabalho"), sem citar a publicação anterior
(D-05/D-12). _Pronto:_ AGENTS.md só doutrina; CHANGELOG formato-válido, 1 release.

**S5 — taxonomia no README.** Tabela user-invoked vs model-invoked das skills
ativas (fonte: `ls -d skills/*/` do público, pós-sanitize — sem hardcodar número;
live tem 13 hoje, público pode diferir). Remover linha `templates/` morta se
houver. _Pronto:_ tabela = 1 linha por dir de `ls -d skills/*/`; links resolvem.

**S5a — project scaffold + project.yaml (D-09, D-11).** Criar `project-template/`
no público: núcleo (hub docs raiz CAIXA ALTA com blockquote "papel deste doc" +
`docs/{prd,design,conventions/{adrs,recipes},research,runbooks,specs}` cada um com
`_TEMPLATE-*` — `design/_TEMPLATE-DDR.md`, `conventions/adrs/_TEMPLATE-ADR.md`,
`conventions/recipes/_TEMPLATE-RECIPE.md`, etc.); opcionais (`ROUTES,
SECURITY, TODOS, PRODUCT, BRAND, DESIGN`) como stub comentado "apague se não há X".
Incluir `project-template/.claude/project.yaml` (schema lean, placeholders) e
`project-template/TODOS.md` vinculando ao project.yaml ("task vive aqui/ali").
Só no público (D-04). _Pronto:_ núcleo completo; cada `docs/<área>/` tem template;
`project.yaml` parseia sem ID real; leak scan 0.

**S5b — doutrina way-of-working (D-10).** Criar `docs/way-of-working.md` cobrindo
as 7 cadeias (research→decisão, spec→PRD→changelog, espinha STRATEGY→…→CONVENTIONS,
ADR/DDR/ADR-Spec, runbook vs recipe, molde/instância + CAIXA-ALTA/lowercase,
raiz≠decision-log). Linkar do README. _Pronto:_ 7 cadeias presentes; links do
scaffold pra doutrina resolvem; leak scan 0.

**S6 — gate anti-slop.** Subagent reviewer (fable low) varre todos os `.md` do
público com o checklist derivado (leverage/robust/seamless, "não é só X é Y",
tríades, transições-filler, em-dash splice, hedging, parágrafo-resumo vazio).
Corrigir achados. _Pronto:_ 0 Critical; re-scan limpo. **Gate: apresentar ao
Benedito antes de S7.**

**S7 — [APROVAÇÃO] tradução EN + publish v0.** Só após S1–S6 aprovados (inclui
S5a/S5b). Traduzir todo `.md` do público (incl. `project-template/` e `docs/way-
of-working.md`) pra inglês; re-passar anti-slop no EN. Live fica PT. Publish =
**v0 limpo** (D-12): `git init` em scratch, tree sanitizado, commit único,
force-push pro `way-of-work` (substitui a história errada). **Bloqueante antes do
push:** `delegate.test.sh` = 0 failed no live. _Pronto:_ `file`-check todos EN;
leak scan 0; `delegate.test.sh` verde; `rev-list --count HEAD` = 1; push v0 feito.

**S8 — fechar.** Mover spec-2026-006 (e a 003 pendente) pra `specs/done/`,
apagar handoffs, `/capture-lessons` (lição: leak-pattern precisa de codename;
divergência híbrida precisa de script de sanitize reproduzível — candidato 005).

## 4. Ao fechar

- Matriz live↔público reconciliada; `delegate.test.sh` verde no live.
- CHANGELOG = release inicial único `[0.1.0]` (v0); público re-nascido de scratch.
- `project-template/` + `docs/way-of-working.md` publicados; scaffold válido.
- spec-003 + spec-006 em `done/`; handoffs mortos.
- Lição durável capturada.

## 5. Gate — Evaluator Status Block

```
Gate 1 (spec): ok
round 1: codex (gpt-5.4) — pré-enriquecimento — critical 0 / important 3 / suggestion 3
round 2: agy [Claude Opus 4.6 (Thinking)] — material novo (D-09..D-12, S5a/S5b, v0)
         — critical 0 / important 3 / suggestion 3 — todos consolidados
teto: 2/2 (sem round 3)
```

**Round 1 — Important consolidados:**
- Dual-writer → D-04 fixa fluxo `live → sanitize → público` (1 escritor, 1 derivador).
- Gate anti-slop inacessível → contrato materializado em §2 (input/reviewer/output/falha).
- "10 skills" ambíguo → AC amarra contagem a `ls -d skills/*/`, 1 linha por dir.

**Round 2 — Important consolidados:**
- IMP-1 DDR sem diretório → `_TEMPLATE-DDR.md` fixado em `docs/design/` (D-09, S5a).
- IMP-2 "10 skills" defasado (live=13) → de-hardcodado em D-02 e S5 (fonte `ls -d`).
- IMP-3 rollback público-only incompleto → nota "recovery = re-rodar S5a/S5b".

**Round 2 — Suggestions:** SUG-1 (schema do project.yaml no AC) alinhado ao D-11
completo; SUG-3 (skills consumidoras) registrada em D-11 pra doutrina. **SUG-2
(delegate.test.sh 1 falha) = falso-positivo** — `DELEGATE_POLICY` temp do reviewer
vazou pro verify_cmd e remapeou o pool agy; rodada limpa = **47/0 verde**. Gate de
publish endurecido pra 0-failed absoluto (S7).

## 6. Fechamento (execução 2026-07-13)

Executada em 10 commits atômicos no live (S0 scenario-tests + S1–S6), depois
sanitize+publish v0. Gates finais: `delegate.test.sh` 47/0, anti-slop 0 Critical,
leak scan 0 por slice. Remoto `babarbosaf/way-of-work` = **1 commit** (v0 limpo,
commit `4454d61`), sem RTK/keybindings/specs reais; `project-template/` (29
arquivos) + `docs/way-of-working.md` + templates presentes.

**Desvio D-08 (tradução EN):** cancelado pelo autor no momento do publish — v0
sai em **PT-BR**. A tradução EN fica adiada (candidata a spec futura); o resto de
S7 (sanitize + push v0) rodou normal.

**Achados de sanitize resolvidos no ato** (leak scan pegou; não previstos no
D-03, mesmo racional "bit pessoal fora do público"):
- §LLM Wiki do AGENTS.md → removida do público (referenciava repo privado
  `~/Projects/llm-wiki`; `llm-wiki` estava no pattern de leak). Live mantém.
- Hook `emit_trace_guard.py` (gitignored, específico de projeto de negócio) →
  entrada removida do `settings.json` público; sem o script, o hook quebraria
  todo clone. Mesmo tratamento do `rtk-hook-wrapper.sh`.
- `.gitignore` público: `!keybindings.json` removido (arquivo não existe no
  público pós-sanitize).

**Lição durável → `/capture-lessons`:** (a) `DELEGATE_POLICY` vaza pro verify_cmd
do reviewer (falso-positivo no gate); (b) o pattern de leak precisa de codename e
o sanitize deveria ser script reproduzível (candidato spec-005) — a divergência
live↔público hoje depende de scan manual por-slice, e 3 bits pessoais (LLM Wiki,
emit_trace, keybindings) só apareceram no leak scan do publish, não antes.
