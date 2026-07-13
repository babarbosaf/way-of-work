---
name: delegate
description: >-
  Despacha tarefas delegáveis para workers externos de custo zero (codex, agy)
  via ~/.claude/scripts/delegate.sh, guiado por ~/.claude/config/model-policy.json.
  Invoque SEMPRE que: for executar task de spec marcada com `delega: <task-type>`;
  precisar de varredura de codebase grande, segunda opinião de lógica/arquitetura,
  boilerplate/testes mecânicos ou review extra; ou quando uma tarefa mecânica de
  >10 min não exigir o contexto da sessão. Invoque também quando o usuário
  pedir economia de consumo ("modo economia", "economiza", "otimiza o consumo",
  "tô perto do limite") — ativa o modo economia da sessão. Não invoque para:
  decisão de arquitetura, integração de código na branch principal, ou tarefa
  que depende do contexto vivo da conversa — isso é core do orquestrador.
---

# Delegate — orquestração de workers externos

> Custo zero primeiro (D-01 da SPEC-2026-002): agy e codex não custam nada nos
> planos atuais. Sonnet/Opus de graça via `agy --model` > o mesmo modelo pago
> pela sessão. Em projetos com scope pago configurado, a cascata ainda tem um degrau pago
> estratégico antes da sessão: backend `claude_api` (API key dedicada, roteado
> pela policy — automático, sem ação sua). Claude da sessão assume tarefa
> delegável só quando tudo isso esgota (exit 2).

## Roteamento

A hierarquia vive em `~/.claude/config/model-policy.json` — **nunca escolha
modelo por conta própria nem cite modelos literais**: passe o `--task` e deixe
a policy rotear. Fica fora da pasta da skill de propósito: é dado
compartilhado entre esta skill (leitura) e `refresh-model-rankings`
(escrita/propõe diff) — não é recurso privado de uma skill só. Task-types:

| task-type | quando usar |
|---|---|
| `review` | revisão adversarial de spec/diff (o peer-review já usa) |
| `second-opinion` | validar raciocínio, decisão técnica, debug travado |
| `scan` | varredura/leitura de codebase ou arquivos grandes, sumarização |
| `boilerplate` | testes mecânicos, scaffolding, conversões repetitivas |
| `implement` | task comum de spec autocontida — código novo (modo worktree) |

Matriz completa de fallback manual (atividade × ranking de modelos, notas de
operação): `references/model-ranking-matrix.md` — consultar quando a cascata
automática não decide sozinha (fallback pós-exit-2, subagente interno,
override pedido pelo usuário).

Stage delegável dentro de um `Workflow` (pipeline/parallel): ver
`references/workflow-adapter.md` — não deixar `Workflow.agent()` spawnar
Claude direto pra tarefa que a cascata grátis resolve.

## Modo one-shot (default — sem escrita)

```bash
~/.claude/scripts/delegate.sh --task scan - <<'EOF'
<prompt>
EOF
```

Montagem do prompt do worker — ele não tem o contexto da sessão, então inclua:
1. **Objetivo em 2-3 frases** e o formato de saída esperado.
2. **Conteúdo ou paths absolutos** dos arquivos relevantes (worker roda no cwd).
3. **Regras do projeto**: cole as seções pertinentes do `AGENTS.md` do projeto.

Exit codes: `0` ok (resposta no stdout) · `2` cascata esgotada → **você assume
a tarefa inline** e segue; nunca re-tente em loop.

## Modo worktree (tasks de spec)

**O marcador `delega: <type>` é vinculante e decidido no planejamento** (Fase 2
do spec-and-plan classifica TODA task: delegável ou orquestrador). No build:
task marcada → despacha; task sem marcador → executa inline, sem reavaliar.
Degradar é sempre permitido (worker indisponível ou task marcada se revelou
acoplada → assumir inline, com nota na spec); **promover não** (nunca delegar
task não-marcada por conta própria — se parecer delegável, é gap do plano:
aponte pro usuário decidir). Spec anterior a esta convenção = retrofit único
do plano, não avaliação task-a-task no build.

Para despachar uma task:

```bash
~/.claude/scripts/delegate.sh --task implement --worktree <repo-dir> - <<'EOF'
Task: <título e descrição da task, copiados da spec>
Critérios de aceite: <ACs da task>
Contexto: <trechos do AGENTS.md + arquivos que a task toca>
Restrições: edite apenas os arquivos da task; rode os testes se existirem.
EOF
```

O worker roda com sandbox nativo do CLI, confinado a uma worktree em branch
`delegate/<slug>`; a branch de trabalho nunca é tocada. O output reporta
`branch:`, `worktree:` e o diff stat.

**Protocolo de integração (obrigatório, nunca pular):**
1. `git diff main...delegate/<slug>` — revisar o diff inteiro; qualquer arquivo
   fora do escopo da task = rejeitar a branch.
2. Rodar o `verify_cmd`/testes da task na worktree.
3. Verde e no escopo → integrar (merge/cherry-pick conforme o fluxo do repo),
   marcando a task como delegada nas notas da spec.
4. Limpar: `git worktree remove <worktree>` e `git branch -d delegate/<slug>`.
   Órfãs: `delegate.sh --gc <repo-dir>`.
5. Ruim mas recuperável → re-delegar com feedback no prompt (1 retry máx);
   ruim de novo → assumir a task inline.
6. **Report de fechamento (tech-lead, sucinto/caveman)** — pós-integração, emitir
   pra sessão orquestradora captar em 4 linhas (executor reportando pro tech-lead):
   ```
   feito: <o que mudou, observável>
   como: <abordagem em 1 frase>
   verify: <verify_cmd rodado + resultado>
   findings: <N> (issues #...)   # finding do worker vira issue via triage, não some
   ```
   Sem prosa extra. Fecha a issue da task (`ready-for-agent → done`) no tracker.

**Follow-up sem remontar do zero:** `--continue <slug>` reusa a
worktree/branch já criada em vez de abrir uma nova — útil pra retry com
feedback (passo 5) ou round 2 de review/debug na mesma branch:

```bash
~/.claude/scripts/delegate.sh --task implement --worktree <repo-dir> --continue <slug> - <<'EOF'
Feedback da revisão anterior: <o que ficou fora do escopo ou quebrou>
EOF
```

Slug inexistente → erro claro (nunca cria uma nova silenciosamente). Uma
worktree reaproveitada via `--continue` nunca é apagada automaticamente pelo
script, mesmo se a cascata esgotar nessa chamada — limpeza continua manual
(passo 4) ou via `--gc`.

## Delegação interna — subagentes Claude (tier `session`)

Workers externos não são a única saída: o **Agent tool aceita override de
`model` (`sonnet`/`opus`/`haiku`) e `effort` (`low`→`max`) por chamada** — dá
pra rodar Fable low na sessão e despachar um subagente Sonnet medium ou Opus
high pra uma tarefa pontual, com contexto isolado. Custa plano Claude, então
pela D-01 entra DEPOIS dos workers grátis. Use quando:

- a tarefa precisa do harness Claude (tools do repo, MCP, skills) que os CLIs
  externos não têm;
- a cascata externa esgotou (exit 2) mas a tarefa merece mais qualidade ou
  contexto isolado do que "assumir inline";
- review adversarial de contexto fresco (o fallback do peer-review já faz isso).

Calibre o modelo à tarefa como faria na policy: mecânico → haiku/sonnet low;
denso → sonnet medium; crítico → opus high. Nunca subagente caro pra tarefa
que um worker grátis resolve.

**Subagente `Agent` fresco (sem `fork`) não herda skills da sessão** — se ele
precisa saber operar `delegate`/`model-policy.json`, ver
`references/subagent-echo-preamble.md` (preâmbulo explícito + eco de
validação, `scripts/echo_preamble.sh`).

## Modo economia (sessão inteira)

Ativa quando o usuário sinaliza pressão de consumo — "modo economia",
"economiza", "otimiza o consumo", "seja eficiente nesta sessão", "tô perto do
limite (5h/semanal)". Detalhe completo: `references/economy-mode.md`.
Resumo: rotear agressivamente pros workers grátis tudo que couber num
task-type, Claude fica só com decisão/integração/síntese, cascata esgotada
cai pra fallback interno mais barato (nunca opus/fable sem pedido explícito).

## Falhas e higiene

- Worker indisponível/rate-limited entra em cooldown automático (60 min) — o
  dispatcher já pula pro próximo da cascata (ordem da matriz); não gerencie
  cooldown manualmente. Cooldown é por **pool** (`backend:pool`, ex.
  `agy:gemini` vs `agy:claude_gpt`), não por backend inteiro — um pool ruim
  não derruba os outros do mesmo CLI. Não há cap diário fixo: a prioridade
  vem só da ordem da cascata na policy, e degradar só acontece quando o
  worker realmente rejeita (rate limit real) **ou** devolve `rc=0` com
  stdout vazio (falha silenciosa do provider — mesmo tratamento do rate
  limit: cooldown, cascata desce, nunca desabilita o pool na policy porque
  tier costuma resetar sozinho, ex. semanal).
- **Sandbox read-only:** o worker roda confinado — comando que escreve fora do
  repo (`uv sync` grava `~/.cache/uv`, instalar deps, fetch de rede) falha com
  `Operation not permitted (os error 1)`, não erro real da task. Não delegar
  gate/CI que sincroniza (retorna FAIL espúrio); rodar inline. Delegar só
  leitura/análise sobre conteúdo já no repo (scan, review, second-opinion).
- Timeout default vem da policy por task-type (`.timeouts`); `--timeout` só
  pra override pontual.
- Aviso de "policy inválida" no stderr = modo degradado ruidoso; corrigir a
  policy (`jq . model-policy.json`) é prioridade sobre a tarefa em curso.
- Kill switch: `DELEGATE_DISABLED=1`.
- Log de uso (metadados): `~/.claude/gate/delegate.log`.
- **Eval de conformidade real** (sem mock, contra os CLIs de verdade):
  `scripts/smoke_backends.sh [--task <type>]` — sonda cada modelo/pool
  habilitado na policy com prompt trivial, confirma resposta não-vazia, e já
  arma/limpa os cooldowns reais que o dispatcher usa (roda antes de uma
  sessão que vai delegar pesado, pra não descobrir pool morto no meio de uma
  task). `delegate.test.sh` é todo mockado — não pega isso.
- Atualização da hierarquia: só via proposta do `/refresh-model-rankings`
  aprovada — nunca editar a policy no meio de uma delegação.
