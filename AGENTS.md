# AGENTS.md — instrução de trabalho (todos os projetos)

Fonte única de instrução pro agente (padrão AGENTS.md, lido por Codex/Cursor/
Copilot/etc.). `CLAUDE.md` é symlink pra este arquivo. A mecânica específica do
Claude Code (hooks, kill-switches) vive na seção final "Claude Code specifics".

**Escrita:** terse, sem AI slop (dash-conector, "canônico", verborragia).
Fragmento > frase. Padrões do Benedito, bom português. Doutrina caveman:
`docs/research/caveman.md`.

## Ciclo de desenvolvimento — fluxo ideal

Cada elo é entrada independente; entra no ponto que a tarefa pede.

```
coaching ─→ PRD ─→ spec-and-plan ─→ test-and-debug ─→ git-workflow ─→ ship-review ─→ capture-lessons
 pensar   sistemas   spec ongoing    TDD/bug+regress    atomic ~100L    gate Critical    lição durável
 (pula se escopo claro)  (>1 arq, >30min, prod, endpoint)      (ao longo, não no fim)
```

Cross-cutting (atravessa, não é passo): context7 antes de API/lib; Evaluator
`peer-review.sh` 1x spec + 1x diff; `delegate` mecânico/economia.

**Handoff proativo:** sessão longa com trabalho aberto → gerar `/handoff` ANTES
de compactar (compact manual ou autocompact). Não esperar o corte; contexto rico
se perde na compaction. Transiente (retomar), não durável (→ capture-lessons).

Atalhos (sem cadeia): bug com linha → `test-and-debug` direto. Refactor puro /
script one-shot / config → nenhuma skill.

**Autonomia/loops:** escada turn→`/goal`→`/loop`→`/schedule` (subir por degrau).
Loop exige stop-condition de máquina (`verify_cmd`/suite-verde, nunca juízo do
agente), turn cap, exit quantitativo, piloto em 1 slice. Gate = Evaluator+
`simplify` (não spawnar reviewer paralelo). Corpo mecânico → `delegate` free tier.
Doutrina: `docs/autonomy-loops.md`.

## Higiene de docs de start-up (instrução do agente: AGENTS.md/CLAUDE.md, README.md)

Carregam toda sessão; instrução viva, não changelog. Sem histórico (→ ADR/runbook/
spec/memória), sem status volátil (→ tracker). Child AGENTS.md/CLAUDE.md só escreve
override próprio. Teste linha-a-linha: "cortar isso faria o agente errar?" Não →
cortar.

## Inbox e achados colaterais — não largar contexto na mesa

Vale pra `inbox.md` e achado no meio de outra tarefa:
0. Baseline limpa antes de spec: `git status`; >5 arquivos `M`/`D` sem relação = parar e processar.
1. Resolve agora (spec-and-plan ou item em TODOS.md/inbox: `[effort] descrição — owner` + critério). Achado que afeta spec ongoing atualiza spec+task no mesmo turno.
2. Difere com contexto (arquivo+linha, sintoma, hipótese, critério, owner).

Regra dura: nunca deixar achado solto na conversa. 3+ na mesma tarefa = parar e processar todos (fila, não pilha).

## Tombamento — nada fora do formato

Todo arquivo cai num slot (doc-raiz + `docs/<área>/`, ou `src/`/`tests/`); o resto vai pra `_tmp/` (gitignored) → tombar, evoluir (registrando o porquê) ou morrer. Antes de mover, grep nos refs: doc vivo e referenciado fica.

## Evoluir > criar (anti-duplicação)

Estender artefato existente antes de criar paralelo. Cobre ~80%? → estender. "Mais limpo" sem consumidor pedindo = evoluir; "`_v2` e migro depois" = nunca migra. Doutrina: `docs/evolve-over-create.md` (ler antes de criar model/módulo/flag/abstração paralela e em ship-review).

## Coding practices atualizadas (context7)

Antes de escolher API/assinatura/versão de lib, consultar doc atualizada via context7 MCP (`use context7`). Amarrado em `spec-and-plan`/`test-and-debug`. Ref: `docs/research/context7.md`.

## Adversarial Evaluator (2a opinião)

`scripts/peer-review.sh {spec|diff} <arg>`. Teto: 1 round spec + 1 diff por feature; round 2 exige aprovação. Status Block obrigatório em `spec-and-plan`/`test-and-debug`; ausente ou ≠ `ok`/`pulado` bloqueia `ship-review`. Mecânica: `docs/adversarial-evaluator.md`.

## Auto-memória — regras

1. Append em `memory/log.md` antes de criar/editar memória (header `## [YYYY-MM-DD] <op> | <basename> (session=<id>)`).
2. **Índice hub-first.** Atômica nova referenciada no hub `concept_*` do tema (hubs são índices, não conteúdo), nunca em lista de órfãs no `MEMORY.md`. `MEMORY.md` = só hubs + cross-cutting sem hub natural — atômica coberta por hub não repete linha (chega por recall). 3+ atômicas sem hub → criar hub.
3. **Teto do índice.** `MEMORY.md` ≤ ~40 linhas / hubs-only. Estourou = compactar (dobrar órfãs em hub), não relaxar.
4. Precedência: AGENTS.md > memory; memória conflitante corrigida/arquivada na hora.

## Infra / migração de schema

Antes de artefato de fidelidade (baseline, equivalência, snapshot de prod): reconhecimento completo do ambiente primeiro — versão real do servidor, enumeração dinâmica de objetos, tipos invisíveis a `information_schema`. Não usar CI/prod como sonda de descoberta.

---

## Claude Code specifics

Mecânica de enforcement específica do Claude Code — a mensagem de bloqueio do
hook ensina na hora. Outros harnesses ignoram esta seção.

**Hooks ativos.** Grep-first em Read >200 linhas; no-op flush bloqueado; lembrete
context7 em import novo/manifesto de dependência (Edit/Write/MultiEdit, não bloqueia);
memória exige append em `memory/log.md` antes de criar/editar. Auto-compact
forçado em 400k via env.

**Kill-switches.** `READ_GUARD_DISABLED=1`, `NOOP_GUARD_DISABLED=1`,
`CONTEXT7_REMINDER_DISABLED=1`, `MEMORY_HOOK_DISABLED=1`.

**Skills / templates.** Skill dispatch por `/`; templates de hook em `hooks/templates/`.
