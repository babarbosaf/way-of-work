---
name: capture-lessons
description: |
  Revisa a sessão e propõe atualizações cirúrgicas em memória, docs e TODOS.md, com aprovação antes de escrever. Auditoria de 4 lentes + roteamento por modelo do repo (PRD/ADR/lint de design quando existirem).
  Use ao final de sessão com bug resolvido, padrão/anti-pattern descoberto, decisão técnica, feedback do usuário, ou múltiplos arquivos editados. Funciona em qualquer projeto com CLAUDE.md ou MEMORY.md.
---

# capture-lessons

Revisa a sessão e propõe atualizações cirúrgicas — com aprovação antes de escrever.

Não invocar: meio de sessão, ou decisão estratégica não-técnica (use `/coaching`).

Fronteira com `/handoff`: estado de trabalho em curso (onde parei, próximo passo) não é lição — vai pro handoff. Aqui só entra o durável.

---

## 1. Auditar com 4 lentes

### Lente A — sessão atual

O que muda comportamento futuro? Capturar:
- **Bugs:** causa raiz + correção (não só "o que fazer")
- **Padrões / Anti-patterns:** atalhos, helpers, o que falhou e por quê
- **Decisões técnicas:** trade-off + contexto
- **Feedback do usuário:** correções, amendments a spec/plano. Scan ativo: "devíamos mudar", "ajusta isso", "na próxima", "faltou", "e se a gente".

Filtro único: se não muda como um agente agiria depois, não captura.

### Lente B — coerência das docs tocadas

**Escopo (via conversation history, não `git status`):**
1. Arquivos modificados (`Edit`/`Write`/`MultiEdit`).
2. Specs `ongoing/` referenciadas (`Read` ou menção a `SPEC-*`), mesmo sem edit.

Pra cada arquivo:
- Coerente com `MEMORY.md` / `CLAUDE.md` atual?
- Referencia algo removido/renomeado?
- TODO `[x]` sem data?
- Entrada stale em `MEMORY.md` contradizendo o novo estado?

**Specs `ongoing/` extra:** decisões novas refletidas? Tasks `[x]` com data + AC? Feedback do usuário incorporado? TODOS.md espelha o estado?

Divergência sessão↔spec = perda de informação → tag `[CRÍTICO]` com diff exato.

**Fallback (autocompact):** sinalizar "lista parcial — confirme se faltam arquivos".

### Lente C — saúde do conhecimento

1. **Clusters sem hub:** `grep -l "<tema>" memory/feedback_*.md | wc -l`. Se ≥5 e sem `concept_<tema>.md` → criar hub + mover ponteiros do MEMORY.md.
2. **Memórias com prazo expirado:** sufixo temporal (`_q1_`, `_2024`) ou conteúdo concluído > 30 dias → propor `mv` pra `memory/archive/`.
3. **Feedback com TODO embutido:** memória `feedback_*` com seção `## Pendente`/`## TODO`/`## Piloto` → split: regra fica na memória (curta), TODO vai pra TODOS.md.

### Lente D — higiene de docs e CLAUDE.md

Checar sempre, independe de a sessão ter editado os arquivos. Checklist completo (tamanho-alvo por doc, INBOX.md, duplicação, status estagnado, TODOS.md hygiene): `references/docs-hygiene-checklist.md`.

### Lente E — Trace ingestion (de findings/)

Condicional (só ≥3 specs novas em `done/` desde último capture). Detecção de padrão em `findings/*.md` e ações propostas: `references/trace-ingestion.md`.

---

## 2. Classificar e rotear

| Tipo | Destino |
|---|---|
| Bug / gotcha / pattern do projeto | `MEMORY.md` do projeto |
| Anti-pattern (o que falhou) | `MEMORY.md` → `## Anti-Patterns` (máx 5) |
| Mudança de comportamento no projeto | `CLAUDE.md` do projeto |
| Setup user-level cross-projeto | `CLAUDE.md` user-level |
| Fato sobre o usuário | `profile/me.md` |
| Tema com hub existente | Memória atômica + atualizar hub `concept_<tema>.md` |
| Cluster ≥5 sem hub (Lente C) | Criar hub + remover ponteiros redundantes do MEMORY.md |
| Memória com prazo expirado | `memory/archive/` + remover ponteiro |
| Tarefa com owner + esforço | `TODOS.md` |
| Item exige design / múltiplas etapas | Spec → TODOS = ponteiro `→ SPEC-YYYY-NNN` |
| Amendment a spec/plano ativo | Atualizar spec `ongoing/` + memória se muda contexto futuro |
| Padrão em `findings/` (Lente E) | Memory `[ANTI-PATTERN]` OU edit no rubric default OU passo novo na skill produtora |

Roteamento condicional pra repo modelo-v2 (PRD/ADR) e projeto com loop de design (DESIGN.md/lint/exemplars): `references/routing-tables-modelo-v2.md`.

**Triage TODOS.md:** owner+esforço+ação → TODOS · design próprio → spec (TODOS = ponteiro) · contexto/padrão → memória · hipótese → inbox.

**Formato TODOS:**
```
- [ ] **[P1/S]** Título — owner: X
  _contexto: por que surgiu, 1 linha_ (opcional)
```

---

## 3. Propor (formato único)

Ordem: **manutenção (Lente B+C+D) → captura nova (Lente A)** — saúde estrutural primeiro.

Snapshot inicial:
```
**Estado:** N linhas em MEMORY.md, M ponteiros, H hubs.
**Sinais:** clusters sem hub: <tema> (N); candidatos archive: N; arquivos acima do teto: N.
```

Cada item:
```
**N. [TAG] Título curto**
Arquivo: caminho → Seção
Conteúdo: [texto exato — 1-3 linhas]
Motivo: [por que muda comportamento futuro]
Impacto: ~Xk tokens/turn  (só pra manutenção)
```

**Tags:** `[CRÍTICO]` · `[OTIMIZAÇÃO]` · `[ANTI-PATTERN]` · `[LIMPEZA]` · `[MANUTENÇÃO]`.

Conteúdo de memória: regra/fato → `**Why:**` → `**How to apply:**`. 1-3 linhas por bloco.

---

## 4. Aprovar e aplicar

> "Quais rejeitar ou ajustar? `n:X` ou `ajustar:X <texto>`. Qualquer outra resposta aprova tudo."

Interpretar: `ok`/texto livre → aprovar tudo · `n:X` → descartar X · `ajustar:X <texto>` → ajuste antes de escrever.

**Aplicação:**
1. Edits cirúrgicos — substituir seções, não reescrever.
2. Pra cada `create/update/delete` em `memory/*.md`, **append em `memory/log.md` ANTES** (hook bloqueia): `## [YYYY-MM-DD] <op> | <basename> (session=<id>)` + 1-3 linhas.
3. Limpar TODOS.md automaticamente: `[x]` com `→ feito|shippado|fechado|concluído YYYY-MM-DD` em **Ativo** vão pra **Concluído** cronológico. `[x]` sem data → aviso, não move. Se `## Concluído > 20` → arquivar (requer aprovação).
4. Reportar arquivos atualizados + tokens economizados (soma dos `Impacto:`).

---

## Regras

- Nunca escrever sem aprovação (exceto a limpeza determinística do TODOS).
- Ler o arquivo-destino antes de propor; comprimir/substituir o obsoleto, não acumular.
- Lentes A-D **obrigatórias**; E só com ≥3 specs novas em `done/` (batch suficiente pra ver padrão). 0 capturas + itens de manutenção ainda é valor.
- Checar o `CLAUDE.md` local pra convenções do projeto.

(Thresholds e escopo das lentes valem onde estão definidos — Lente C: 5 memórias/hub, 30 dias/archive; Lente B: conversation-history, não `git status`.)
