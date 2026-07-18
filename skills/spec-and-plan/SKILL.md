---
name: spec-and-plan
description: |
  Transforma ideia refinada em spec técnica (contrato + plano) com tasks executáveis e build incremental com TDD. Toda spec nasce como folder em `docs/specs/ongoing/`.
  Invoque SEMPRE que o usuário for implementar feature que afeta mais de 1 arquivo, leva mais de 30 min, toca prod, ou cria endpoint/handler/cron/pipeline; também quando disser "vou implementar X"/"preciso construir Y"/"quero automatizar Z".
  Não invoque para: bug com linha localizada (test-and-debug), refactor puro, script one-shot, ajuste de config/docs.
---

> "A spec é a fonte de verdade. O plano é a ponte entre spec e código. O build é incremento por incremento, cada um verde."
> Nenhuma linha de código antes da Zona 1 aprovada. Nenhum commit grande sem teste.

---

## Project config — fallback chain

Skills resolvem metadata do projeto (tracker backend, trunk, verify_cmd, smoke_cmd, pipeline_paths) nesta ordem:

1. **`.claude/project.yaml`** no repo (preferido, estruturado)
2. **`CLAUDE.md` project-level** (parsear `## Tracker` / `## Verify` / `## Smoke` se existirem)
3. **Prompt humano** no momento (último recurso)

Schema lean do `project.yaml`:
```yaml
tracker:    { backend: notion|github|linear|none, database: "...", initiative: "..." }
# Roteamento duplo (repo com tracker técnico + não-técnico):
#   tracker: { tech: github, nontech: notion, tasks_db: "<id>", kr_db: "<id>" }
# Notion: tasks_db (onde desdobra), kr_db/repos_db (relação obrigatória na criação).
executable_states: [ready-for-agent, ...]  # states que loop/delegate podem pegar; resto = lixo, não executa
repo:       { trunk: <branch>, branch_prefix: feature }
verify_cmd: "<comando que roda aceite de slice>"
smoke_cmd:  "<comando que roda smoke E2E quando pipeline_paths é tocado>"
pipeline_paths: ["<dir/>", "..."]   # diff tocando aqui ⇒ smoke_cmd obrigatório
```
Override fino por-spec (raro): frontmatter `tracker_target: <db-id|label>` no `spec.md`, lido em cima do `project.yaml` quando ESTA spec mira sub-database/label diferente. Config de repo NÃO desce pra spec — fonte única é o `project.yaml`.

Sem squad config (autonomy/task_structure/handoff/rules são do legado `tracker.yaml` abolido).

---

## Spec como folder (físico)

**Toda spec nova nasce como folder**, não arquivo solto. Layout canônico:

```
docs/specs/ongoing/spec-YYYY-NNN-<slug>/
├── spec.md              # contrato + plano (frontmatter aponta rubric + threshold)
├── rubric.md            # opcional — override do rubric default
├── findings/
│   ├── pass-1.md        # 1ª passada do Adversarial Evaluator
│   └── pass-2.md        # cap 3 passes
├── state.json           # opcional — matriz feature × passing/failing
└── traces/              # opcional — smoke/playwright logs por pass
```

Regras:
- **`spec.md` dentro da folder é o documento principal** (o que era `spec-NNN-slug.md` antes). Tooling que glob por `docs/specs/ongoing/*` precisa virar `docs/specs/ongoing/*/spec.md`.
- **Frontmatter da `spec.md`** declara o rubric: `rubric: feature-backend` (resolve em `~/.claude/docs/rubrics/` ou `docs/rubrics/`) + `threshold: 4`. Sem rubric declarado, Adversarial Evaluator usa juízo livre (legado).
- **`done/` antigo fica flat** (specs frozen). Nova convenção só pra `ongoing/` daqui pra frente.
- **Template do projeto** (`_TEMPLATE-spec/` no modelo-v2; `TEMPLATE-spec/` em legado) é folder com `spec.md` placeholder + `rubric.md` opcional + `findings/.gitkeep`.

A skill **CRIA o folder** ao materializar a spec na Fase 1 — `mkdir -p docs/specs/ongoing/spec-YYYY-NNN-<slug>/findings && cp -r <template>/* docs/specs/ongoing/spec-YYYY-NNN-<slug>/`. Não criar arquivo solto.

---

## Modelo de docs — detectar no início

Antes de escolher o formato, detecta o modelo do repo:

- **Repo modelo-v2** — tem `docs/prd/`, `CONVENTIONS.md` e `docs/specs/_TEMPLATE-spec/`. A spec segue o **template do projeto** e o loop fecha no PRD. Aplica os 4 deltas abaixo; o resto da skill (Voz, Tiering, Gates, Fase 3/TDD) vale igual.
- **Repo legado** — sem esses marcadores. Comportamento atual: tudo abaixo como está, formato 2-zonas + `TODOS.md`. É o degradê.

**Deltas do modelo-v2** (só quando os marcadores existem):

1. **Escopo vem do PRD.** O Contexto (§1) linka a seção do `docs/prd/<sistema>.md` que a mudança altera, em 1 linha.
2. **Formato = `_TEMPLATE-spec/` do projeto.** Seções: §1 Contrato (contexto+link PRD · aceite SIM/NÃO · fora de escopo) · §2 Design técnico (contratos externos · security · rollback · testes) · §3 Slices · §4 Ao fechar · §5 Gate. **Sem `## Plano de Implementação` granular** — a §3 é o handoff.
3. **Fase 2 = slices na §3 da spec.md.** Slices ficam na própria spec (não em `TODOS.md`); o build da Fase 3 consome slice a slice em ordem. TDD por slice na Fase 3 (igual).
4. **Gate na §5 + findings/ + fechamento no PRD.** O **resumo (verdict + reviewer)** de cada round do Adversarial Evaluator vai pra **§5 da `spec.md`** como Evaluator Status Block. O **detalhe** (findings, evidências, próximo passo) vai pra **`findings/pass-N.md`** dentro da folder da spec — handoff estruturado pro próximo loop, sobrevive a compaction de contexto. Ao fechar (§4 do template): atualiza `docs/prd/<sistema>.md` pra nova verdade + entrada no `CHANGELOG.md` + Acionáveis done.

A mecânica das 3 fases abaixo (desambiguação, gates, TDD, red flags) é a mesma. Onde o texto disser "Zona 1 / Zona 2 / `## Plano de Implementação` / `TODOS.md`", no modelo-v2 leia "§1 Contrato / §2 Design + §3 Slices / §3 Slices / Acionáveis". A checklist final (Verification) mapeia igual.

**Vocabulário público em modelo-v2:** ao escrever a spec e ao falar com o usuário, **use `§1`, `§2`, ..., `§5`** (ou os nomes do template: "Contrato", "Design técnico", "Slices", etc.). **Não diga "Zona 1/Zona 2"** — esse é vocabulário de revisão interna, não do doc. Vazar "Zona 1" pra conversa quando o repo é modelo-v2 é red flag.

---

## Tiering — quanta cerimônia (decidir no início)

A spec escala com o escopo. Declare o nível no topo (`Rigor: <nível>`).

| Nível | Quando | Zona 2 exige |
|-------|--------|--------------|
| **leve** | one-shot reversível, sem prod, sem input externo | Plano + testes unit. Sem Security/Rollback/ADR. |
| **padrão** | feature multi-arquivo, comportamento novo | + Mudanças, Mini-ADR (se ≥2 caminhos), testes 4 camadas |
| **governança** | prod, pipeline, handler de input externo, irreversível | + Security (modelo de ameaça), Rollback, Notas de pipeline |

Zona 1 é **sempre** obrigatória — é o que o dono revisa. O tiering só governa a profundidade da Zona 2.

---

## O artefato — spec em 2 zonas

A spec se lê em duas zonas. A primeira é o contrato — o que o dono revisa e assina. A segunda é o plano técnico — como vai ser construído.

**Zona 1 — Contrato** (sempre obrigatória):
- **Como fica:** fluxo antes → depois, em ASCII estreito (≤40 colunas). O quadro do mundo pós-ship em linguagem de negócio.
- **Decisões `D-NN`:** parágrafo curto cada uma. O que foi decidido, por que, e o trade-off envolvido. Não usar template formulaico (`pergunta · escolha · tradeoff`) — escreve direto.
- **Critérios de aceite:** lista em SIM/NÃO comportamental. Não cita SQL ou função; cita o que o sistema faz.
- **Fora de escopo:** o que explicitamente não entra.

**Zona 2 — Plano técnico** (profundidade segue o tiering):
Mudanças · Contratos com sistemas externos · Mini-ADR (+ alternativas descartadas) · Segurança · Rollback · Estratégia de testes · Plano de tasks · Notas.

**Regras de ouro:**

1. **Zona 1 não tem detalhe de implementação** (sem SQL, sem nome de tabela/função, sem mecanismo). Cita comportamento, não código. Termo de domínio do dono é ok — o vocabulário que ele já usa no dia a dia é a linguagem dele, não jargão.
2. **Contexto não reescreve o PRD.** Se o sistema tem PRD (`docs/prd/<sistema>.md`), o Como fica referencia o problema/solução por link. Sem PRD, 3 linhas inline.
3. **Como fica (ramo "depois") é a fonte única dos cenários de teste.** Cada ramo vira um user journey na Zona 2 (mecânica em `test-and-debug`). Não descrever jornadas duas vezes.
4. **Toda `D-NN` da Zona 1 aparece em ≥1 task da Zona 2.** Decisão sem task = decisão órfã.
5. **"Zona 1" / "Zona 2" é LENTE de revisão interna, não vocabulário público.** O arquivo segue o template canônico do projeto, cujos nomes de seção H2 (`## 1. Contrato`, `## 2. Design técnico`, ou `## Mudanças`, `## Critérios de Aceite`) o tooling consome (`peer-review.sh` classifica M/L por eles; `ship-review` lê o Evaluator Status Block). **Em modelo-v2, ao falar com o usuário e ao escrever a spec, use `§1`, `§2`, `§3`, `§4`, `§5` (ou os nomes do template), NÃO "Zona 1/Zona 2".** Zona serve só pra você pensar internamente "esta seção é contrato ou plano técnico?". Mapeamento: §1 Contrato = Zona 1; §2-§3 = Zona 2. Em repo legado (sem `_TEMPLATE-spec/`), o doc nasce com seções canônicas (`## Resumo`, `## Decisões`, `## Critérios de Aceite`, `## Mudanças`, `## Plano de Implementação`); aí também NÃO usar "Zona" como cabeçalho. **Nunca usar `## ZONA 1` / `## ZONA 2` como cabeçalho físico** — quebra o tooling e o doc fica com cara de template preenchido.

---

Guia de voz/estilo do doc final: `references/style-and-flags.md`.

---

## Fase 1 — Spec

Aprovada pelo usuário (Zona 1) antes de qualquer implementação.

### Processo

- [ ] **1. Desambiguação upstream — 3 lentes num bloco só**
  - Antes de escrever, resolver ambiguidade em 3 lentes (não pular nenhuma que se aplique):
    1. **Técnica** — stack, autenticação, escopo de dados, dependências externas. Confirma premissas antes de virar decisão. Se uma `D-NN` depende de um fato técnico (esta credencial é read-only? roda em que ambiente? o gatilho nasce onde?), confirma o fato — chama a API, lê a doc (lib/framework externo: `use context7` pra assinatura atualizada e versionada), checa o ambiente. Premissa técnica não-verificada vira Critical no Gate.
       - Se o fato vive numa fonte canônica inacessível agora (código atrás de auth, ambiente fora de alcance), verifica contra a melhor proxy disponível (snapshot, doc, cópia arquivada), reconhece internamente que é proxy (não documenta isso no doc final como termo técnico), e cria uma task de re-verificação contra o live antes do build começar. No doc final, escreve simplesmente *"Fica decidida em T0, com dado em mãos"* — não rotula como "verificada-contra-stale".
    2. **Arquitetural (mini-ADR)** — dispara se há >1 caminho não-óbvio (SQL vs NoSQL, sync vs async, lib A vs B) OU decisão difícil de reverter. Compara opções, escolhe, justifica em 1 frase. Vai pra Zona 2 em prosa, não em template.
    3. **Produto/escopo** — paginação, formato de output, edge case, política de erro visível, autorização. Vira `D-NN` na Zona 1, em parágrafo.
  - **Disparar por default.** Pular só se: `1p` linkado já cobre ACs Dado/Quando/Então (happy + edges) E spec é leve sem handler. Se pular, anotar: `Desambiguação: pulada — 1p cobre ACs e é leve`.
  - Apresentar perguntas em batch único, priorizadas; o usuário responde uma por vez. Anti-padrão: 10 perguntas sem rank (desengaja).
  - Razão: spec ambígua é causa-raiz #1 de retrabalho no Gate. Custo de perguntar < custo de redesenhar.

- [ ] **2. Escrever a Zona 1 (contrato)** — voz da seção `## Voz` aplicada
  1. **Como fica** — fluxo antes→depois em ASCII estreito. O quadro do mundo pós-ship, em linguagem de negócio. (PRD linkado? Contexto = link, não repete.)
  2. **Decisões `D-NN`** — parágrafo curto cada. O quê + por quê + trade-off envolvido, escrito direto. Não usar template `pergunta · escolha · tradeoff`.
  3. **Critérios de aceite** — lista SIM/NÃO em comportamento ("rota desconhecida → sem zona + aviso", não "WHERE zona IS NULL").
  4. **Fora de escopo** — o que explicitamente não entra, 1 linha cada.

- [ ] **3. Escrever a Zona 2 (plano técnico)** — profundidade conforme o tiering
  1. **Mudanças** — o que será construído (em partes). Sub-seção **Contratos com sistemas externos** quando a spec emite/consome evento/registro/chamada em outro componente; senão "N/A".
  2. **Mini-ADR** — opções/escolha/porquê + alternativas descartadas (Tradeoff / Quando seria certa / Decisão). Absorve "Decisões Tomadas" e "Alternativas" — não criar seções separadas.
  3. **Security** *(governança)* — **Modelo de ameaça** (vetor × defesa × risco residual) + defesas operacionais. `ship-review` verifica contra este modelo; não o redefine.
  4. **Rollback** *(governança)* — cenário × procedimento concreto (comando/flag); intervenção manual exige runbook linkado.
  5. **Estratégia de testes** — 4 camadas (ver §3 abaixo).
  6. **Plano de Implementação** — preenchido na Fase 2.

- [ ] **3b. Estratégia de testes — 4 camadas**
  - **Unit/contract:** funções e estruturas de output (ver `test-and-debug` → "Output contracts").
  - **User journeys:** **derivam dos ramos do COMO FICA** — um `Test<Story>Journey` por ramo. Obrigatório se a feature encadeia 2+ comandos/handlers, usa state pendente, ou tem retorno assíncrono. Mecânica e padrão de classe: `test-and-debug` → "User journey tests". Não re-descrever aqui.
  - **Scenario (computer-use):** sempre que a mudança é user-facing E tem superfície dirigível (tela, CLI, bot, output publicado) — dirigir o sistema como o usuário faria e observar a reação, execução via skill `verify`. Mecânica: `test-and-debug` → "Scenario tests". Declarar o roteiro + evidência esperada; sem superfície → `n/a` justificado.
  - **Smoke automatizado pós-deploy:** script que invoca o handler com input sintético + asserts. AC do tipo "usuário roda na mão" é anti-padrão; reescrever como script com asserts.

- [ ] **4. Gate 1 — Adversarial Evaluator automático** (antes de apresentar pra aprovação)
  - Invocar `~/.claude/scripts/peer-review.sh spec <path>` **sem perguntar ao usuário**. Cascata `codex → gemini` automática via `--model auto` (default).
  - Classificar findings: **Critical** (bloqueia), **Important** (ajustar antes da aprovação), **Suggestion** (apresentar pra decisão).
  - Emitir **Evaluator Status Block** (formato + estados + fallback canônicos em `~/.claude/docs/adversarial-evaluator.md`).
  - `critical_aberto`: **parar e pedir decisão do usuário.** Apresentar Criticals + opções: (a) consolidar fixes + rodar round 2 (precisa "aprovado round 2"), (b) consolidar patch sem round 2 (típico), (c) redesenhar, (d) abandonar. Round 2 só roda após aprovação expressa. Sem round 3.
  - **`indisponível`:** todos os reviewers externos (codex+gemini) falharam → executar **fallback adversarial** (subagente Claude de contexto fresco — ver `adversarial-evaluator.md` § Fallback). Marca `reviewer: claude-adversarial`. Não pular o gate silenciosamente.
  - `teto_atingido`: apresentar Criticals remanescentes + pedir decisão (aceitar / redesenhar / abandonar).

- [ ] **5. Obter aprovação explícita da Zona 1**
  - Aprovar a Zona 1 **é** a validação de intenção (o passo que formaliza o que o dono quer). Apresentar com Evaluator Status Block no corpo, aguardar "aprovado".
  - Atualizar frontmatter: `Status: aprovado`.

- [ ] **6. Referenciar no TODOS.md** — `- [ ] **[P1/M]** [nome] → spec: SPEC-YYYY-NNN.md`

Red flags da spec: `references/style-and-flags.md`.

---

## Fase 2 — Plano de Tasks

Decompõe a spec aprovada em tasks pequenas, ordenadas e verificáveis. Output: seção `## Plano de Implementação` (Zona 2) + linhas em `TODOS.md`.

### Processo

- [ ] **0. Pré-condições de execução (campo de 1ª classe).** Antes de ordenar as tasks, separar o que é **faz-agora** do que está **bloqueado-em-X-externo** (auth/login, sign-off de terceiro, credencial, deploy, dado que ainda não chegou). Marcar cada task bloqueada com `bloqueado: <X>`. O slice executável-já vai primeiro, pra entregar valor sem esperar o desbloqueio. (Mesma família da regra `/ultraplan precondições` no CLAUDE.md — git, auth.)
- [ ] **1. Modo leitura — sem escrever código.** Ler spec completa + arquivos relevantes.
- [ ] **2. Mapear grafo de dependências.** Foundations primeiro (utils → handlers → orquestradores). Identificar o que bloqueia o quê.
- [ ] **3. Fatiar verticalmente.** Cada task = caminho completo testável (função + teste + integração). Não horizontal.
- [ ] **4. Escrever tasks estruturadas:** título + 1 parágrafo · 2-3 critérios de aceite testáveis · arquivos modificados · dependências (`dep:T3,T4`) · effort `XS/S/M` (nunca L — quebrar).
  - **Delegação (SPEC-2026-002) — classificação obrigatória:** TODA task recebe decisão explícita: ou marcador `delega: <task-type>` (types em `~/.claude/config/model-policy.json`), ou fica no orquestrador. O marcador é vinculante no build (a skill `delegate` despacha pra worker de custo zero em worktree; sem marcador = inline, sem reavaliação). É delegável a task autocontida — ACs fechados, arquivos definidos, sem decisão de arquitetura aberta nem dependência do contexto da conversa; o marcador força o fatiamento certo. Task com decisão de arquitetura ou acoplada à conversa nunca leva o marcador.
- [ ] **5. Ordenar + checkpoints.** Ordem respeitando dependências; checkpoint a cada 2-3 tasks pra validar com o usuário.
- [ ] **6. Rastreabilidade `D-NN` → task.** Listar no fim do plano: cada decisão da Zona 1 mapeada pra ≥1 task (ou explicitamente em Escopo Fora). Decisão sem cobertura = gap.
- [ ] **7. Desdobrar em issues no tracker** (writer + template + regras de link-vivo/relação/backend: `references/to-tickets.md`). **Push automático no build, pós-gate** (só slice aprovada vira issue). A issue é a **fonte da verdade da execução**; a spec, do design. **Invariante de completude (gate bloqueia se faltar):** toda slice vira issue com `{título, aceite, priority, delega-decision, backend/destino, blocked_by}`. Presença é mecânica aqui; acerto é do review. Finding que surgir no build/review não morre em `findings/` — vira issue via `references/triage.md` (roteia destino+state) e `references/refine.md` (engorda item magro até `ready-for-agent`).

Checklist obrigatório para pipelines / handlers / endpoints (idempotência, TTL, persistência, falha encadeada, ambiente vs gatilho): `references/checklists.md`.

### Cláusula Shift Work Mode

Após spec + plano aprovados, o build roda end-to-end sem ping até o próximo `CHECKPOINT N`. Pings fora de checkpoint são exceção. Obstáculo → registra nas Notas de Implementação e segue até o checkpoint mais próximo.

### Cláusula Paralelismo de specs

Antes da Fase 3, confirmar que arquivos tocados não conflitam com specs em `ongoing/` ativas. Conflito → bloquear build até resolução: (a) mergear spec antiga, (b) refatorar fronteira pra módulos separados, (c) coordenar ordem com sessão paralela. (A concorrência de CI do projeto cobre o lado infra; o gate humano é estrutural.)

Red flags do plano: `references/style-and-flags.md`.

---

## Fase 3 — Build incremental

Cada task em incrementos pequenos, cada um verde. TDD (Red-Green-Refactor) é o default. **Mecânica de TDD/debug: `test-and-debug` é o dono** — esta fase só orquestra a ordem das tasks.

### Processo

- [ ] **1. Ler a task + apenas os arquivos que ela toca.**
- [ ] **2. RED** — teste que falha antes do código (documenta o comportamento esperado). Rodar → confirma falha.
- [ ] **3. GREEN** — mínimo código pra passar. Sem extras. Rodar → verde.
- [ ] **4. REFACTOR** — limpar mantendo verde. Sem adicionar comportamento.
- [ ] **5. Verificar escopo do diff** — só arquivos da task; nada "extra" no commit.
- [ ] **6. Checkpoint com usuário antes do próximo slice.**
- [ ] **7. Gate 2 — Adversarial Evaluator automático no fim do BUILD** (antes de propor commit final)
  > Formato do Block + estados + teto de 2 rounds + **fallback adversarial**: `~/.claude/docs/adversarial-evaluator.md`.
  - **Trigger:** todas as tasks `[x]` no Plano de Implementação E suite completa verde.
  - **Pré-requisito bloqueante:** suite verde (`pytest` etc. retorna 0, zero skipped sem justificativa). Se falhar: Block com `Gate 2: blocked_precondition` preservando payload; voltar pro `test-and-debug`. Não commitar.
  - Invocar `~/.claude/scripts/peer-review.sh diff HEAD` **sem perguntar**. Cascata `codex → gemini` automática. Atualizar Block.
  - `critical_aberto` (qualquer tipo): **parar e pedir decisão.** Apresentar Criticals + opções: (a) escrever fixes (Prove-It pra bugs; patch in-place pra design/segurança) + rodar round 2 (precisa "aprovado round 2"), (b) aplicar fixes sem round 2 (típico — confiar no ship-review), (c) redesenhar, (d) abandonar. Round 2 só após aprovação expressa.
  - **`indisponível`:** todos os reviewers externos falharam → fallback adversarial (subagente fresco — `adversarial-evaluator.md` § Fallback), `reviewer: claude-adversarial`.
  - `teto_atingido`: parar, apresentar Criticals, pedir decisão do usuário.
  - **Garantia:** `Gate 2: ok` exige suite verde **depois** da última mudança.

Red flags do build: `references/style-and-flags.md`.

---

Rationalizations comuns (rejeitar): `references/style-and-flags.md`.

---

## Verification (checklist antes de fechar)

- [ ] Zona 1 revisável (sem jargão), aprovada pelo usuário antes de qualquer código
- [ ] COMO FICA presente; Contexto linka o PRD (não repete)
- [ ] Critérios de aceite em SIM/NÃO comportamental
- [ ] Toda `D-NN` mapeada pra task (rastreabilidade)
- [ ] Zona 2 com profundidade do tiering declarado
- [ ] Estratégia de testes na spec; journeys = ramos do COMO FICA
- [ ] Plano com efforts + dependências; nenhuma task L/XL
- [ ] Suite verde após build; diff focado
- [ ] Evaluator Status Block no output (Gate 1 e Gate 2)

---

## Próximo passo

Build completo → **`ship-review`** (revisão + segurança + SHIP).
Bug durante build → **`test-and-debug`**.
