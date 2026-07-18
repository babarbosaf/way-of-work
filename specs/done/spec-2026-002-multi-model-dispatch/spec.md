---
Spec: SPEC-2026-002
Título: Workflow multi-modelo — dispatcher delegate.sh, model-policy e ranking vivo
Owner: Benedito
Status: shipped
Rigor: governança
---

# Workflow multi-modelo

## Resumo

Hoje todo trabalho roda no Claude Code, gastando sessão Claude mesmo em tarefas que Codex e Antigravity (agy) fariam de graça nos planos atuais. Já existe um embrião de orquestração — o `peer-review.sh` despacha reviews para `codex exec` e `gemini -p` com circuit-breaker — mas ele só serve avaliação adversarial, com hierarquia de modelos escrita em código.

Esta spec generaliza esse embrião num dispatcher (`delegate.sh`) que roteia qualquer tarefa delegável para o melhor worker de custo zero, guiado por uma política em arquivo (dado, não código) mantida viva por uma rotina quinzenal de pesquisa de rankings com aprovação humana. A delegação se integra à cadeia existente: tasks do plano de uma spec podem ser marcadas como delegáveis e executadas por workers em worktrees isoladas, com o Claude Code como orquestrador e revisor.

## Como fica

```
ANTES
tarefa → Claude Code executa tudo
         (sessão Claude paga por
          boilerplate, scan, review)

DEPOIS
tarefa da spec
  │
  ├─ core (arquitetura, decisão,
  │  integração) → Claude Code
  │
  └─ delegável → delegate.sh
       │  lê model-policy.json
       │  (custo zero primeiro)
       ├─ one-shot: prompt → resposta
       │  (scan, review, 2ª opinião)
       └─ worktree: worker edita em
          branch isolada → Claude
          revisa e integra

quinzenal: pesquisa de rankings
  → proposta em arquivo + inbox
  → Benedito aprova → policy muda
```

## Decisões

**D-01 — Custo zero primeiro.** O critério primário de roteamento não é "melhor modelo para a tarefa" e sim "melhor worker de custo zero que dá conta da tarefa". Codex e agy não geram custo nos planos atuais do Benedito, então são sempre a primeira tentativa — inclusive quando a tarefa pede modelo Anthropic (Sonnet/Opus via `agy --model` sai de graça; o mesmo modelo pela sessão Claude, não). Claude Code executa direto apenas o core da sessão (arquitetura, decisões, integração, revisão do que os workers produzem) e assume tarefa delegável só quando todos os workers falham ou estão em cooldown. O trade-off aceito: um worker gratuito às vezes entrega menos que o Fable resolveria de primeira; o custo de re-delegar ou assumir é menor que pagar sessão por tarefa mecânica.

**D-02 — Política como dado, sem OpenRouter.** A hierarquia tarefa→worker vive em `~/.claude/config/model-policy.json` (JSON porque `jq` já existe na máquina e `yq` não), nunca hardcoded em script. Atualizar a hierarquia é editar dado. Providers pagos via API (OpenRouter etc.) ficam fora do v1 por decisão expressa; a policy já nasce com campo `cost` por backend para absorvê-los depois sem mudança de código.

**D-03 — Ranking vivo com gate humano.** Uma rotina quinzenal (scheduled agent, também invocável manualmente via skill) pesquisa rankings externos de código (LMArena/WebDev Arena, Aider polyglot, SWE-bench, changelogs dos CLIs) e descobre modelos novos nos CLIs instalados (`agy models` é dinâmico — um Sonnet 6 apareceria ali). O resultado não altera a policy sozinho: vira `~/.claude/gate/model-rankings/proposal-YYYY-MM-DD.md` (diff proposto + justificativa com fontes) mais uma linha no `~/.claude/inbox.md`, que o fluxo de inbox do Benedito já processa. Aprovou, a policy muda; benchmark barulhento nunca reescreve política sem revisão.

**D-04 — Evoluir o peer-review, não duplicar.** A camada de invocação (adapters `invoke_*`, cooldown per-model, log JSONL, timeout) sai do `peer-review.sh` para o `delegate.sh`, e o `peer-review.sh` vira consumidor dele. Um único ponto de manutenção para "como chamar worker externo"; o peer-review mantém intactos seu gating por tamanho, prompts adversariais e contrato de exit codes.

**D-05 — Delegação por task da spec, em worktree.** A unidade de delegação é a task do Plano de Implementação de uma spec. Task marcada como delegável roda via `delegate.sh --worktree`: o worker recebe a task + critérios de aceite, edita numa git worktree em branch própria, e devolve a branch para o Claude Code revisar, rodar os testes e integrar. O confinamento de escrita não é a worktree em si (que é só um diretório): é o **sandbox nativo do CLI**, obrigatório no modo worktree — `codex --sandbox workspace-write`, `agy --sandbox`. Backend sem sandbox disponível não é elegível para worktree, só para one-shot; o dispatcher recusa em vez de rodar sem confinamento. Nada chega à branch principal sem revisão. One-shot (prompt→resposta, sem escrita) continua sendo o modo para scan, review e segunda opinião.

**D-06 — Versionar `~/.claude` com git.** O diretório vira repo git com `.gitignore` cobrindo estado volátil e sensível (gate/, logs, sessions, credenciais, todos, projects/). Habilita histórico da policy, rollback de scripts/skills e o próprio Gate 2 desta spec.

**D-07 — AGENTS.md como fonte única por projeto.** Em cada projeto ativo, o conteúdo do `CLAUDE.md` migra para `AGENTS.md` (padrão lido por Codex, agy/Gemini, Cursor etc.) e o `CLAUDE.md` fica reduzido a `@AGENTS.md` + overrides exclusivos do Claude quando existirem. Todos os projetos ativos em `~/Projects` são convertidos nesta spec. O `~/.claude/CLAUDE.md` global não migra — é config do harness Claude, não contexto de projeto.

**D-08 — Descoberta dinâmica de backends.** O refresh (D-03) não confia só em pesquisa web: enumera o que está de fato instalado e disponível (`agy models`, versão dos CLIs) para propor só o que é acionável. Modelo ótimo que nenhum CLI local serve não entra na policy.

## Critérios de aceite

- [ ] Dada uma tarefa de scan/review/segunda opinião, `delegate.sh` a executa num worker externo de custo zero e devolve a resposta, sem intervenção manual de escolha de modelo.
- [ ] Dada uma task de spec marcada como delegável, o worker produz o resultado numa branch isolada e nenhuma mudança chega à branch de trabalho sem revisão do orquestrador.
- [ ] Quando o worker preferido está indisponível ou em cooldown, o dispatcher tenta o próximo da política e, esgotados todos, sinaliza que o Claude assume — nunca falha silenciosamente.
- [ ] Mudar a hierarquia de modelos não exige editar nenhum script — só o arquivo de política.
- [ ] A cada ciclo do refresh, existe uma proposta datada em arquivo com justificativa e fontes, e uma linha nova no inbox; a policy só muda após aprovação expressa.
- [ ] O `peer-review.sh` continua funcionando com o mesmo contrato de antes (mesmos modos, exit codes e Evaluator Status Block) após passar a usar o dispatcher.
- [ ] Num projeto convertido, Codex e agy leem as mesmas regras de projeto que o Claude Code (via AGENTS.md), e o Claude Code não perde nenhuma instrução.
- [ ] `~/.claude` versionado: `git log` mostra histórico e nenhum arquivo sensível/volátil rastreado.

## Fora de escopo

- Providers pagos via API (OpenRouter, chaves diretas) — direção futura, absorvível pela policy.
- Orquestrador externo (Vibe Kanban, Claude Squad, opencode) e UI de paralelismo.
- Atualização automática da policy sem aprovação humana.
- Delegação de sessões interativas longas (worker conversacional); v1 é one-shot e task-em-worktree.
- Migração do `~/.claude/CLAUDE.md` global para AGENTS.md.

## Mudanças

1. **Repo git em `~/.claude`** — `git init`, `.gitignore` (gate/, logs/, projects/, todos/, sessions, `*.log`, `settings.local.json`, caches), commit inicial.
2. **`~/.claude/config/model-policy.json`** — schema: lista de `backends` (nome, comando de invocação, `cost: free|paid|session`, modo suportado `oneshot|worktree`, modelos disponíveis) e mapa `tasks` (task-type → lista ordenada de backends). Task-types iniciais: `review`, `second-opinion`, `scan` (cobertos por journey) e `boilerplate`, `implement` (reserva — entram na policy mas só ganham journey quando o primeiro uso real chegar).
3. **`~/.claude/scripts/delegate.sh`** — dispatcher. Interface:
   `delegate.sh --task <type> [--model <backend>] [--worktree <repo-dir>] [--timeout N] - < prompt`
   Lê a policy, resolve a cascata, invoca adapters (`invoke_codex`, `invoke_gemini`, `invoke_agy`), herda do peer-review o cooldown per-model (`~/.claude/gate/cooldown.<backend>`), o log JSONL de uso e o contrato de exit codes (0 ok, 2 nenhum worker disponível, 3 cooldown, 4 CLI ausente). Modo `--worktree`: cria `git worktree add` com branch `delegate/<slug>`, roda o worker com auto-aprovação confinada ao diretório da worktree, reporta branch + resumo no stdout, nunca mergeia.
4. **`peer-review.sh` refatorado** — adapters e cooldown removidos do corpo; passa a chamar `delegate.sh --task review`. Gating, prompts e Block intactos.
5. **Skill `/delegate`** (`~/.claude/skills/delegate/`) — ensina o orquestrador quando e como despachar: heurística task-type → delegação, montagem do prompt do worker (task + ACs + contexto do AGENTS.md), revisão obrigatória do retorno, e o protocolo de worktree (revisar diff, rodar verify, integrar, remover worktree).
6. **Integração com `spec-and-plan`** — convenção nova no plano de tasks: marcador `delega: <task-type>` na task. A skill spec-and-plan ganha 1 parágrafo documentando o marcador; a skill `/delegate` consome.
7. **Skill `/refresh-model-rankings` + scheduled agent quinzenal** — pesquisa (WebSearch) + descoberta local (`agy models`, versões) → `proposal-YYYY-MM-DD.md` + linha no inbox. A aplicação da proposta (após aprovação) é edição assistida da policy com commit.
8. **AGENTS.md nos projetos ativos** — para cada projeto em `~/Projects` com `CLAUDE.md`: mover conteúdo para `AGENTS.md`, deixar `CLAUDE.md` = `@AGENTS.md` (+ overrides Claude-only se houver). Template em `~/Projects/_template`.
9. **Reinstalar Codex CLI** — vendor binary quebrado (`ENOENT`); pré-condição de tudo.

### Contratos com sistemas externos

- **CLIs workers**: `codex exec --skip-git-repo-check -` (stdin), `gemini -p`, `agy -p --model <M>` (headless, `--print-timeout`). O dispatcher trata os três como caixas-pretas com contrato prompt→stdout + exit code; mudança de flag num CLI quebra só o adapter correspondente.
- **peer-review.sh ↔ delegate.sh**: peer-review chama `delegate.sh --task review --timeout 120 -`. Mapeamento explícito de exit codes: delegate 0 → peer-review 0 (findings no stdout); delegate 2/3/4 (nenhum worker / todos em cooldown / CLI ausente após esgotar a cascata) → peer-review 2 (fallback adversarial), preservando a interface externa atual (0/2) que os hooks conhecem. Códigos 3/4 são internos à cascata do delegate e nunca vazam pelo peer-review.
- **Hooks existentes** (`peer-gate-hook.sh` etc.): não mudam — continuam invocando `peer-review.sh` pela interface atual.

## Mini-ADR

Considerei três arquiteturas. **Orquestrador externo neutro** (opencode/Antigravity como hub) daria neutralidade máxima de provider, mas abandona hooks, skills e memória do Claude Code — o custo de migração mata o ganho. **Runner de paralelismo** (Vibe Kanban, Claude Squad) resolve um problema que ainda não temos (N tarefas grandes simultâneas) ao preço de uma camada de estado nova. **Claude Code como orquestrador com workers headless** ganhou: preserva 100% do setup, é o padrão dominante entre power-users, e o `peer-review.sh` já provou o mecanismo — a spec só o generaliza. Para a camada de roteamento, descartei proxy de API (claude-code-router/LiteLLM): troca o modelo por dentro do harness degradando-o, e é a classe de wrapper global que o incidente RTK (2026-07) proibiu.

Para o formato da policy, JSON com `jq` ganhou de YAML (`yq` não instalado; não vale dependência nova) e de bash puro sourced (policy tem que ser legível por skill e por humano, e diffável na proposta do refresh).

## Segurança

| Vetor | Defesa | Risco residual |
|---|---|---|
| Worker com auto-aprovação executa ação destrutiva ou escreve fora da worktree | Sandbox nativo do CLI obrigatório no modo worktree (`codex --sandbox workspace-write`, `agy --sandbox`); backend sem sandbox só roda one-shot; branch isolada, nunca merge automático; `--worktree` exige repo git limpo no alvo | Worker pode **ler** além da worktree; escapes do sandbox do próprio CLI são possíveis em tese — mitigado por revisão do diff e por `~/.claude` versionado (T1) detectar mudança em scripts/hooks |
| Prompt do worker vaza segredo (env, credencial em arquivo) | Prompt montado só com task + ACs + AGENTS.md; nunca inclui `.env`/settings; log JSONL registra metadados, não conteúdo | Worker lê arquivo sensível do repo por conta própria durante worktree — mitigado por revisão do diff antes de integrar |
| Policy corrompida roteia tudo pra backend errado/pago | `delegate.sh` valida schema via `jq` no load e cai pro default seguro (cascata codex→agy) se inválida — **ruidosamente**: aviso no stderr, evento no log JSONL e linha no inbox (modo degradado nunca é silencioso); policy versionada em git | Janela entre edição ruim e detecção |
| Refresh automático injeta recomendação maliciosa de fonte web | Proposta é arquivo inerte + gate humano obrigatório; agent do refresh não tem escrita na policy | Aprovação desatenta do humano |
| Commit acidental de segredo ao versionar `~/.claude` | `.gitignore` escrito antes do commit inicial; revisão do `git status` no primeiro commit | Arquivo sensível futuro fora dos padrões do ignore |

## Rollback

| Cenário | Procedimento |
|---|---|
| `delegate.sh` com bug quebra o peer-review (gate de commits) | `git -C ~/.claude revert` do commit da refatoração; contrato preservado garante que a versão anterior do peer-review volta a funcionar standalone. Kill switch: `DELEGATE_DISABLED=1` faz `delegate.sh` sair com exit 2 (Claude assume tudo), mesmo padrão dos kill switches existentes |
| Policy nova (pós-refresh) degrada qualidade | `git -C ~/.claude revert` do commit da policy |
| Worktree de worker deixa lixo | `git worktree remove --force` + `git branch -D delegate/<slug>`; delegate.sh lista worktrees órfãs com `--gc` |
| AGENTS.md quebra um projeto (instrução perdida) | Conversão é `git mv` + edição no repo do projeto; revert local no projeto |
| Scheduled agent do refresh incomoda | Deletar a routine agendada; skill manual permanece |

## Estratégia de testes

- **Unit/contract (mocks de CLI):** suíte bash (`~/.claude/tests/delegate.test.sh`) que antepõe um diretório de mocks ao `PATH` (fake `codex`/`gemini`/`agy` que ecoam, falham, simulam rate-limit). Cobre: resolução de cascata pela policy, cooldown arma/expira, exit codes, policy inválida → fallback default, kill switch.
- **User journeys** (ramos do Como fica):
  - `TestOneShotJourney`: tarefa scan → delegate → resposta do mock no stdout + log JSONL.
  - `TestWorktreeJourney`: repo git de fixture → task delegável → branch `delegate/*` criada com edição do mock → branch principal intocada.
  - `TestFallbackJourney`: todos os mocks em rate-limit → exit 2 + mensagem "Claude assume".
  - `TestPeerReviewJourney`: `peer-review.sh diff` roda inteiro sobre o delegate com mocks, Block ok.
- **Smoke pós-build (real):** `delegate.sh --task scan - <<< "responda OK"` contra codex e agy reais, 1 vez cada; `peer-review.sh spec` desta própria spec via delegate.

## Plano de Implementação

Pré-condições: T0 e T1 desbloqueiam tudo; nenhuma dependência externa (sem bloqueado-em-X).

- [x] **T0 [XS]** Reinstalar Codex CLI e validar `codex exec` headless. AC: `echo "diga OK" | codex exec --skip-git-repo-check -` responde. `dep:—`
- [x] **T1 [XS]** `git init ~/.claude` + `.gitignore` + commit inicial revisado. AC: `git status` limpo; `git ls-files` auditado contra checklist de padrões sensíveis (auth, token, key, credential, history, sessions, .env) com zero hits. `dep:—`
- [x] **T2 [S]** Criar `config/model-policy.json` (schema + conteúdo inicial com backends codex/gemini/agy e task-types) + validação `jq` documentada no próprio arquivo README curto. AC: `jq . model-policy.json` passa; policy expressa D-01 (free antes de session). `dep:T1`
- [x] **T3 [M]** Criar `delegate.sh` modo one-shot: leitura da policy, cascata, adapter codex extraído do peer-review + adapter agy novo (gemini vira adapter legado `enabled: false` — CLI morto pro free tier), cooldown, log, exit codes, kill switch, fallback pra cascata default com policy inválida. TDD com mocks no PATH. AC: journeys OneShot e Fallback verdes. `dep:T2`
- [x] **T4 [S]** Refatorar `peer-review.sh` para consumir `delegate.sh --task review`. AC: journey PeerReview verde; interface e exit codes idênticos; hooks intocados. `dep:T3`
- [x] **T5 [M]** Modo `--worktree`: criação/branch, invocação com auto-aprovação confinada, relatório, `--gc`. AC: journey Worktree verde; branch principal intocada. `dep:T3`
- [x] **T6 [S]** Skill `/delegate` (SKILL.md): heurística de roteamento, montagem de prompt, protocolo de revisão/integração de worktree. AC: skill passa no checklist do skill-creator; referencia a policy, não modelos literais. `dep:T3,T5`
- [x] **T7 [XS]** Convenção `delega: <task-type>` documentada na skill spec-and-plan (1 parágrafo) e consumida pela `/delegate`. AC: os dois textos cruzam referência. `dep:T6`
- [x] **T8 [M]** Skill `/refresh-model-rankings` + scheduled agent quinzenal: pesquisa web + `agy models`, gera `gate/model-rankings/proposal-*.md`, linha no inbox (cria `~/.claude/inbox.md` se ausente). Proposta **aprovada** é copiada para `config/model-policy-history/` (versionada) no mesmo commit da policy — `gate/` é gitignored e a justificativa não pode sumir do histórico. AC: rodada manual produz proposta com fontes e diff da policy; nada escrito na policy. `dep:T2`
- [x] **T9 [S]** Template AGENTS.md em `~/Projects/_template` + conversão de 1 projeto piloto (o mais ativo). AC: no piloto, `CLAUDE.md` = `@AGENTS.md` (+overrides); verificação por diff de contexto — dump das instruções efetivamente carregadas por sessão Claude antes e depois da conversão é idêntico em conteúdo; `codex`/`agy` respondem corretamente a uma pergunta cuja resposta só existe nas regras do projeto. `dep:—`
- [x] **T10 [S]** Converter os demais projetos ativos de `~/Projects`. AC: todos com CLAUDE.md convertidos no mesmo padrão. `dep:T9`
- [x] **T11 [XS]** Smoke real (codex + agy vivos) e commit final. AC: smoke passa; Gate 2 rodado. `dep:T3,T4,T5`

Checkpoints: **CP1** após T2 (fundação), **CP2** após T5 (dispatcher completo), **CP3** após T8 (loop de ranking), **CP4** após T11 (fechamento).

Rastreabilidade: D-01→T2/T3 · D-02→T2 · D-03→T8 · D-04→T3/T4 · D-05→T5/T6/T7 · D-06→T1 · D-07→T9/T10 · D-08→T8.

## Notas

- `agy` hoje serve: Gemini 3.5 Flash (3 efforts), Gemini 3.1 Pro (2), Claude Sonnet 4.6 (Thinking), Claude Opus 4.6 (Thinking), GPT-OSS 120B — confirmado via `agy models` em 2026-07-05.
- Codex CLI: npm `@openai/codex@0.122.0` presente, vendor binary arm64 ausente (motivo do T0).
- `gemini` CLI (0.46.0) está **morto para o free tier individual**: `IneligibleTierError: This client is no longer supported... migrate to the Antigravity suite` (verificado em 2026-07-05 durante o Gate 1 desta spec). Consequência: a cascata default é **codex → agy**; o adapter gemini entra como legado opcional na policy (`enabled: false`), removível após 2 ciclos consecutivos do refresh confirmando a deprecação.

## Gate

```
Gate 1: ok (patch pass-1 aplicado, sem round 2 por decisão do owner)
Reviewer: claude-adversarial (fallback — codex quebrado, gemini free tier morto)
Findings: findings/pass-1.md (1 Critical, 3 Important, 3 Suggestions — todos endereçados na spec)

Gate 2: ok (fixes aplicados in-place, suite 28/28 verde depois da última mudança)
Reviewer: codex (via delegate.sh — dogfooding do próprio build)
Findings: findings/pass-2.md (0 Blockers, 3 Important, 3 Suggestions — Importants + 2 Suggestions corrigidos; lock de cooldown/log documentado como risco aceito, uso solo)
```
