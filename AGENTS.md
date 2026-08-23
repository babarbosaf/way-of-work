# AGENTS.md — instrução de trabalho (todos os projetos)

Fonte única de instrução pro agente (padrão AGENTS.md, lido por Codex/Cursor/
Copilot/etc.). `CLAUDE.md` é symlink pra este arquivo. A mecânica específica do
Claude Code (hooks, kill-switches) vive na seção final "Claude Code specifics".

**Escrita:** terse, sem AI slop. Fragmento > frase. Bom português. Fonte única:
`llm-wiki` → `concept_voz_benedito` (banidos + brevidade + naturalidade +
calibração de voz; cresce por correção ao vivo, não hardcodar lista aqui).
Doutrina de origem: `docs/research/escrita.md`.

## Modelo de trabalho — 3 modos

```
projeto novo    →  /kickoff-project (entrevista → PRD·ROUTES·DESIGN·CONVENTIONS·AGENTS·FEEDBACK)
feature grande  →  spec curta em docs/specs/<slug>.md (contrato+plano) → TDD → ship
todo o resto    →  direto no código com TDD → ship
```

Feature grande = várias sessões, muitos arquivos, toca contrato ou prod. Na
dúvida, vai direto e promove pra spec se crescer. A spec é descartável: ao
shippar, a verdade funcional vai pro PRD (skill `spec-and-plan`).

**Docs vivos** (política por projeto, no AGENTS.md dele): decisão de produto
edita PRD; fluxo novo, ROUTES; padrão visual, DESIGN; padrão técnico,
CONVENTIONS. Decisão técnica cara de reverter vira ADR em `docs/adrs/`.
Correção/lição do projeto: append no `FEEDBACK.md`, **uma linha por entrada** com o
gatilho embutido (teto 10; narrativa do incidente fica na decisão que o produziu, e
entrada que virou norma é promovida ao doc permanente e apagada). Lição
cross-projeto: memória (skill `capture-lessons` roteia). Achado colateral: resolve agora ou vira linha
no `TODOS.md` com contexto — nunca solto na conversa.

**Identidade de projeto vive na `llm-wiki`.** Mudança que altera o que um projeto
**é** (o que faz, stack, canal, quem mantém, se morreu) atualiza a entidade dele
em `wiki/entities/` na mesma rodada, com `updated:`; sistema desligado vira
`status: superseded`. Quem sabe que mudou é quem mudou: cron que descobre depois
sempre chega tarde, e foi assim que uma página descreveu por três meses um agente
que não existia mais.

Cross-cutting: context7 antes de API/lib; `delegate` mecânico/economia;
`design-workflow` antes de componente/tela visual novo ou redesenho; `/handoff`
antes de compactar com trabalho aberto. Segunda opinião adversarial
(`scripts/peer-review.sh {spec|diff}`) é opcional, sob demanda — recomendada em
diff que toca prod ou é caro de reverter (`docs/adversarial-evaluator.md`).
Autonomia/loops: escada turn→`/goal`→`/loop`→`/schedule`, stop-condition de
máquina (`docs/autonomy-loops.md`).

## Testes — 3 regras

1. Comportamento novo nasce com teste: RED antes do código, GREEN mínimo,
   REFACTOR = `/simplify` mantendo verde.
2. Todo bug ganha teste de regressão ANTES da correção; debug para na causa
   raiz, não no sintoma ("deduplicar no resultado" é sintoma; "query errada" é causa).
3. Suite verde é pré-condição de commit. "Parece certo" não é done; AC "rodar
   manualmente" vira script com assert.

## Código simples — YAGNI extremo

- Abstração só na 3ª repetição (rule of three). Helper extraído na 1ª duplicação = corte.
- Zero feature especulativa: com agente, adicionar depois é trivial; remover
  depois que espalhou não é.
- Antes de escrever helper, procurar função existente (stdlib, lib do projeto, codebase).
- Diff pequeno > diff completo. Deletar código conta como progresso.
- Evoluir > criar: estender artefato existente antes de criar paralelo
  (`docs/evolve-over-create.md`).

## Antes de propor

**Repo que já existe: o inventário é o primeiro entregável.** O que tem, onde
estão os buracos, o que sai. Bloco de escolhas antes do mapa faz o dono escolher
no escuro.

**Fonte acessível se mede, não se opina.** API, banco ou arquivo na mão: medir
primeiro. Diagnóstico com número decide; com adjetivo, negocia.

**Operação em lote sobre dado dele** (Notion, wiki, Drive, prod) tem gate no
**plano**, não só na execução: desenho do resultado e método na mesa, e espera o ok.

## Higiene de docs de raiz (AGENTS.md/CLAUDE.md, README.md, PRD…)

Carregam toda sessão; instrução viva, não changelog. Sem histórico (→ ADR/spec/
FEEDBACK/memória), sem status volátil (→ TODOS/tracker). Child AGENTS.md só
escreve override próprio. Teste linha-a-linha: "cortar isso faria o agente
errar?" Não → cortar. Raiz em CAIXA-ALTA = doc único e estável; instância
(`spec-<slug>`, `adr-NNNN`) em lowercase. Transiente vai pra `_tmp/` (gitignored).
Escopo se declara pelo que o projeto **É**: nada de tabela de exclusão nem de
"isto saiu daqui" — a negativa que importa vive na decisão que a produziu.

## Coding practices atualizadas (context7)

Antes de escolher API/assinatura/versão de lib, consultar doc atualizada via
context7 MCP (`use context7`). Ref: `docs/research/context7.md`.

## Auto-memória — regras

1. Append em `memory/log.md` antes de criar/editar memória (header `## [YYYY-MM-DD] <op> | <basename> (session=<id>)`).
2. **Índice hub-first.** Atômica nova referenciada no hub `concept_*` do tema (hubs são índices, não conteúdo), nunca em lista de órfãs no `MEMORY.md`. `MEMORY.md` = só hubs + cross-cutting sem hub natural — atômica coberta por hub não repete linha (chega por recall). 3+ atômicas sem hub → criar hub.
3. **Teto do índice.** `MEMORY.md` ≤ ~40 linhas / hubs-only. Estourou = compactar (dobrar órfãs em hub), não relaxar.
4. Precedência: AGENTS.md > memory; memória conflitante corrigida/arquivada na hora.

## Infra / migração de schema

Antes de artefato de fidelidade (baseline, equivalência, snapshot de prod): reconhecimento completo do ambiente primeiro — versão real do servidor, enumeração dinâmica de objetos, tipos invisíveis a `information_schema`. Não usar CI/prod como sonda de descoberta.

## RTK (economia de tokens)

Proxy sempre-ligado; analytics: `rtk gain`. Detalhes: `docs/rtk.md`.

---

## Claude Code specifics

Mecânica de enforcement específica do Claude Code — a mensagem de bloqueio do
hook ensina na hora. Outros harnesses ignoram esta seção.

**Hooks ativos.** Grep-first em Read >200 linhas; no-op flush bloqueado; lembrete
context7 em import novo/manifesto de dependência (não bloqueia); memória exige
append em `memory/log.md` antes de criar/editar; guard de tamanho do CLAUDE.md.
Auto-compact forçado em 400k via env; RTK roda via hook proxy.

**Kill-switches.** `READ_GUARD_DISABLED=1`, `NOOP_GUARD_DISABLED=1`,
`CONTEXT7_REMINDER_DISABLED=1`, `MEMORY_HOOK_DISABLED=1`.

**Skills.** Dispatch por `/`.
