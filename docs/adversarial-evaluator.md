# Adversarial Evaluator — Referência Completa

Workflow: reviewer LLM independente revisa specs e diffs do Claude (segunda opinião adversarial). O gate é **LLM-agnóstico** — cascata `codex → gemini → subagente Claude → inline`.

## Invocação manual

```bash
~/.claude/scripts/peer-review.sh spec <path-to-spec.md> [--findings <prev.md>] [--model auto|codex|gemini]
~/.claude/scripts/peer-review.sh diff [git-ref] [--findings <prev.md>] [--spec <spec.md>] [--model ...]
```

- `--model auto` (default) = cascata `codex → gemini → exit 2`
- `--model codex` ou `--model gemini` = força um reviewer específico, sem fallback
- Bypass classifier: `echo "$PROMPT" | codex exec -` ou `gemini -p "$PROMPT"`

**Tamanho não captura risco.** O classificador pula por LOC/arquivos/prod-path, mas
mudança de **schema, migração de dados ou rename consumido downstream** é alto-risco mesmo
`<500 LOC` (perda de dado silenciosa, quebra de consumidor que unit/CI leve não pegam).
Nesses casos, forçar ≥1 round via `--model` direto (ou o bypass acima) em vez de aceitar o
skip automático.

**Contexto injetado automaticamente (spec mode):**
1. Primeiras 40 linhas do `CLAUDE.md` do projeto
2. PRD do sistema (`docs/prd/<slug>.md`, ou campo `idea_ref:` no frontmatter da spec apontando pro doc de origem)
3. Findings do round anterior (se `--findings` fornecido)

**Contexto injetado automaticamente (diff mode):**
1. Primeiras 40 linhas do `CLAUDE.md` do projeto
2. ACs da spec ativa (se `--spec` fornecido)
3. Findings do round anterior (se `--findings` fornecido)

## Cascata de reviewers

O gate é "segunda opinião de contexto independente"; o reviewer concreto é pluggable. Ordem da cascata (`--model auto`):

1. **codex** — primário (`reviewer: codex`). Requer `codex` CLI no PATH.
2. **gemini** — segundo (`reviewer: gemini`). Requer `gemini` CLI no PATH (`npm i -g @google/gemini-cli`).
3. **subagente Claude adversarial de contexto fresco** — quando 1 e 2 indisponíveis. A skill (writer do Block) spawna subagente (com modelo definido pelo agente principal, adequado à necessidade da spec) com prompt red-team explícito: *"Você é um revisor cético. Tente REFUTAR esta spec/diff. Liste apenas problemas reais classificados em Critical/Important/Suggestion; default a Critical quando em dúvida sobre segurança ou perda de dado."* Marca `reviewer: claude-adversarial`.
4. **inline Claude** (`reviewer: claude-inline`) — piso-do-piso, quando nem o subagente roda (ex. session limit). Mesmo viés do agente principal, por isso é último recurso.

### Cooldown per-model

Cada reviewer tem cooldown próprio em `~/.claude/gate/cooldown.<model>`. Codex em cooldown não bloqueia Gemini (e vice-versa) — a cascata pula direto. Override: `PEER_COOLDOWN_MINS` (default 60).

Limpo no primeiro sucesso. Manual: `rm ~/.claude/gate/cooldown.codex` ou `PEER_COOLDOWN_MINS=0`.

### Probe de disponibilidade

1. **Probe barato:** o script checa `command -v <reviewer>` antes de invocar; ausente → `rc=4`, desce na cascata sem latência.
2. **Workspace não-git é caso NORMAL pra review de spec.** Specs vivem no parent não-git por design (ex. `~/Projects/<seu-projeto>`); código vai pro subdir git. Codex sempre invocado com `--skip-git-repo-check`. Pra diff, o script roda `git diff` então precisa de git no cwd.
3. **`rc≠0` com output truncado** (efeito de RTK/`set -e` no pipe) = "**não rodou**", nunca "ok". Tratar como indisponível.
4. **Integridade do Block:** `reviewer:` reflete **quem realmente produziu output verificável**. Nunca preencher findings como se um reviewer indisponível tivesse rodado.

## Fallback quando todos os reviewers externos indisponíveis

Script retorna `exit 2` (`unavailable`). A skill chamadora então:

- **Spawna subagente Claude adversarial** (`reviewer: claude-adversarial`). Contexto separado corta viés de confirmação do agente principal.
- Se subagente também não disponível (session limit): **inline review com evidência linha-a-linha obrigatória** (cada finding cita `file:line` real, não inferência). `reviewer: claude-inline`. Cria task de re-review quando codex/gemini voltarem.

**Regras do fallback:**
- Cada nível classifica nos mesmos 3 baldes (Critical/Important/Suggestion). `critical_aberto` do fallback bloqueia igual aos externos.
- Mesmo teto de 2 rounds.
- Níveis 3 e 4 são **piso**, não substituto. Quando codex/gemini voltam, eles são preferidos.
- `ship-review` aceita `reviewer: claude-adversarial` (ou `claude-inline`) + `Gate 2: ok` como validação degradada (não rejeita por "indisponível" se um fallback rodou e passou).

## Findings: stdout por default; sidecar opcional em folder

Toda execução com `rc=0` joga os findings no **stdout** (o caller monta o Evaluator Status Block a partir deles). **Sem sidecar legado** `*.gate-round-N.md` ao lado da spec nem `.gate-findings/` no cwd — abolidos em 2026-06-11. Motivação original: spec auto-contida, sem doc paralelo.

**Registro durável** (quem escreve = o caller, lendo o stdout):
- **Spec mode (default):** resumo de cada round vai pra **§5 da `spec.md`** — Evaluator Status Block + Criticals encontrados + o que mudou na spec por causa deles. É **resumo**, não verbatim.
- **Diff mode:** feedback vai pro **comentário da PR**, co-localizado com o diff.

**Sidecar opcional: `findings/pass-N.md` dentro da folder da spec** (introduzido 2026-06-23, alinhado ao spec-as-folder). Materializa o **detalhe verbatim** (file:line, evidência, hipótese, próximo passo) quando o round tem **handoff denso** que vale persistir pro builder dos slices. Heurística:

- **NÃO criar** quando o round é pequeno (1-2 itens) ou o detalhe destila inteiro na §5. Default = só §5.
- **CRIAR** quando: >3 Criticals/Importants com evidência file:line, OU o builder vai precisar reler o detalhe verbatim (não só o summary), OU handoff estruturado pro próximo loop (Anthropic harness pattern: "structured handoffs cure compaction drift").

**Sem duplicação.** §5 aponta pra `findings/pass-N.md` quando este existir (1 linha: "Detalhe verbatim: findings/pass-1.md"); não copia conteúdo. Os dois têm papéis distintos: §5 = summary durável, findings/ = detail escalonável.

**Re-rodar incremental (round 2) via stdin:** como nada é gravado, o round anterior é re-injetado pelo **stdin** com `--findings -`. O caller passa os findings do round 1 (que tem em contexto, ou relê da §5):
```bash
printf '%s' "$ROUND1_FINDINGS" | \
  ~/.claude/scripts/peer-review.sh spec docs/specs/SPEC-XXX.md --findings -
```
O reviewer recebe o round 1 como contexto e foca em verificar os fixes. Sem `--findings`, é round 1 limpo. `--findings <path>` ainda funciona se um arquivo existir, mas o script não gera nenhum.

## Classificação automática de M/L

- Spec M/L = ≥100 linhas OU ≥5 headers `##`, OU toca handler/endpoint/webhook
- Diff M/L = toca `agent/`, `apps/`, `bin/`, `libs/`, `migrations/`, `scripts/*.py|.sh`, ou arquivos com "handler/endpoint/webhook/cron", OU diff grande (≥500 LOC, ≥20 arquivos)
- Fora disso, script retorna "pulado" sem invocar reviewer.

## Orçamento — teto por spec, não diário

Sem teto diário. Observabilidade ad-hoc via `~/.claude/gate/usage.log` (JSONL).

**Teto hard por spec:**
- Até 1 invocação por spec (round 1), seja `peer-review.sh spec` ou  `peer-review.sh diff`.
- Total default por spec: 2 chamadas.
- **Round 2 exige aprovação expressa do usuário.** Claude nunca dispara round 2 autonomamente, mesmo com `critical_aberto`. Quando round 1 retorna Critical:
  1. Apresentar os Criticals com a evidência crua (citações do reviewer).
  2. Propor opções: (a) consolidar todos os fixes num patch + rodar **round 2** (precisa "aprovado"), (b) consolidar patch e seguir **sem round 2** (caminho típico), (c) redesenhar, (d) abandonar.
  3. Esperar decisão. Round 2 só roda após "aprovado round 2".
- Round 2 (se aprovado) deve incluir **todos** os fixes acumulados num único patch consolidado antes de re-rodar.
- Se round 2 ainda tem `critical_aberto`, Claude para e pede decisão (aceitar / redesenhar / abandonar). Não existe round 3 — qualquer extensão exige nova aprovação expressa.


## Evaluator Status Block — fonte canônica

Artefato emitido por skills do ciclo pra desambiguar estado do gate. Skills downstream (`ship-review`) consomem, não re-inferem.

**Ownership por contexto (nunca duas skills escrevem o mesmo Block):**
- `spec-and-plan` Fase 1 → único writer com `phase: fase-1` (Gate 1)
- `spec-and-plan` Fase 3 → único writer com `phase: fase-3` (Gate 2) em fluxo normal
- `test-and-debug` → único writer com `phase: standalone` em fluxo sem spec ativa
- `ship-review` → **nunca escreve.** Leitor puro. Rejeita ship se estado != `ok`/`pulado`.

**Formato exato (todos campos obrigatórios):**
```
---
Evaluator Status Block
  spec_path: <path absoluto OU "standalone">
  phase: <"fase-1" | "fase-3" | "standalone">
  emitted_by: <"spec-and-plan" | "test-and-debug">
  reviewer: <"codex" | "gemini" | "claude-adversarial" | "claude-inline">
  git_rev: <SHA curto OU "no-git">
  session_id: <UUID>
  timestamp: <ISO-8601>
  tasks_completed: <N ou "n/a">
  tasks_total: <N ou "n/a">
  suite_status: <"green" | "red" | "not-run" | "n/a">
  Gate 1 (spec review): <ok | pulado | indisponível | critical_aberto | teto_atingido | n/a>
    razão: <texto>
    findings_path: <path OU "n/a">
    round: <1 | 2 | 3 | n/a>
  Gate 2 (diff review): <ok | pulado | indisponível | critical_aberto | blocked_precondition | teto_atingido | n/a>
    razão: <texto>
    findings_path: <path OU "n/a">
    round: <1 | 2 | 3 | n/a>
---
```

**Estados:**
- `ok` — 0 Critical, apresentável/commitável
- `pulado` — classifier do script pulou (XS/S sem input externo)
- `indisponível` — todos reviewers externos falharam → executar **fallback** (subagente, depois inline) antes de marcar. Se o subagente rodar: `reviewer: claude-adversarial`, estado vira `ok`/`critical_aberto` conforme o veredicto (validação degradada). Se nem o fallback rodar: "parcialmente validado"
- `critical_aberto` — reviewer rodou, tem Critical. Bloqueia avanço até fix + re-run
- `blocked_precondition` — só Gate 2. Pré-requisito (suite verde) falhou. Block preserva payload
- `teto_atingido` — 2 rounds consumidos com Critical remanescente. Claude para, pede decisão do usuário
- `n/a` — fase não se aplica

**Regras obrigatórias:**
1. Session-scoped. Sessão futura retomando deve re-rodar o gate
2. Claude nunca escreve "sem bloqueantes" se Block indica `indisponível`, `blocked_precondition`, `critical_aberto` ou `teto_atingido`
3. Claude nunca apresenta spec pra aprovação / propõe commit sem Block no output
4. Consumidor localiza "Block corrente" pelo par `spec_path`+`phase` com `timestamp` maior no output da sessão ativa

## Hook automático de nudge

Registrado em `~/.claude/settings.json` (`peer-gate-hook.sh`). Emite lembrete (não bloqueia) em:
- Edit/Write em `**/docs/specs/ongoing/*.md` → sugere `peer-review.sh spec`
- Edit/Write em `**/agent/*.py` → sugere `peer-review.sh diff HEAD`
- Bash de `git commit`/`git push` com arquivos dessas áreas staged → sugere review antes

Silencioso em projetos sem essas pastas ou sem git.

## Quando o gate pula mas deveria rodar

Spec pode estar com layout diferente do canônico. Opções:
- Ajustar spec pro layout canônico — preferido
- Invocar manualmente com `codex exec -` (ou `gemini -p ...`) + prompt customizado — bypass

## Política de relatórios

Registro durável:
- **§5 da `spec.md`** (spec mode, default) — Evaluator Status Block + Criticals + resumo do que mudou.
- **Comentário da PR** (diff mode) — co-localizado com o diff.
- **`findings/pass-N.md` dentro da folder da spec** (opcional, quando handoff denso justifica — ver §"Findings: stdout por default; sidecar opcional em folder"). Não duplica §5; complementa.

## Referências

- `~/.claude/skills/ship-review/SKILL.md` — invoca o gate pré-SHIP
- `~/.claude/scripts/peer-review.sh` — implementação
- `~/.claude/scripts/peer-gate-hook.sh` — hook de nudge
- `~/.claude/gate/usage.log` — JSONL de uso (metadados, sem conteúdo)
- Memórias por-projeto: `feedback_gate_*` / `feedback_codex_*` (renomes pendentes) em `~/.claude/projects/*/memory/`
