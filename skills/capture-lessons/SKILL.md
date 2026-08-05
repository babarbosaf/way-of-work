---
name: capture-lessons
description: |
  Revisa a sessão e roteia lições pra dois destinos: FEEDBACK.md do projeto (correção/padrão local, com teto e promoção) ou memória global (padrão cross-projeto). Propõe antes de escrever.
  Use ao final de sessão com bug resolvido, padrão/anti-pattern descoberto, decisão técnica, feedback do usuário, ou múltiplos arquivos editados. Funciona em qualquer projeto com AGENTS.md/CLAUDE.md.
---

# capture-lessons

Revisa a sessão e roteia lições — com aprovação antes de escrever.

Não invocar: meio de sessão, ou decisão estratégica não-técnica (use `/coaching`).

Fronteira com `/handoff`: estado de trabalho em curso (onde parei, próximo passo) não é lição — vai pro handoff. Aqui só entra o durável.

---

## 1. Auditar a sessão

O que muda comportamento futuro? Capturar:
- **Bugs:** causa raiz + correção (não só "o que fazer")
- **Padrões / Anti-patterns:** atalhos, helpers, o que falhou e por quê
- **Decisões técnicas:** trade-off + contexto
- **Feedback do usuário:** correções, amendments. Scan ativo: "devíamos mudar", "ajusta isso", "na próxima", "faltou", "e se a gente".

Filtro único: se não muda como um agente agiria depois, não captura.

Checar também os arquivos tocados na sessão (via conversation history): referenciam algo removido/renomeado? Contradizem `FEEDBACK.md`/`MEMORY.md` atual? Divergência = perda de informação → tag `[CRÍTICO]` com diff exato.

---

## 2. Rotear — dois destinos

**A pergunta única: a lição vale fora deste projeto?**

| Resposta | Destino |
|---|---|
| Não — é deste projeto (gotcha da stack local, correção de comportamento aqui, padrão do código daqui) | `FEEDBACK.md` do projeto (formato do scaffold: data + contexto + instrução) |
| Sim — é jeito de trabalhar, preferência do usuário, padrão de qualquer projeto | Memória global (`memory/`, hub-first) |

Casos derivados:

| Situação | Ação |
|---|---|
| Lição de projeto que já está no FEEDBACK.md (reincidência) ou virou norma | **Promover:** mover pro doc permanente (AGENTS.md se instrução de agente, CONVENTIONS.md se regra de código, PRD.md/DESIGN.md se produto) e apagar a entrada |
| FEEDBACK.md perto do teto (~30) | Compactar: promover o que virou norma, deletar o obsoleto |
| Decisão técnica cara de reverter | ADR em `docs/adrs/` + linha no índice do CONVENTIONS.md |
| Tarefa com owner + esforço | `TODOS.md` do projeto |
| Fato sobre o usuário | `profile/me.md` |
| Tema global com hub existente | Memória atômica + atualizar hub `concept_<tema>.md` |
| Cluster ≥5 memórias sem hub | Criar hub + remover ponteiros redundantes do MEMORY.md |
| Memória com prazo expirado (sufixo temporal, concluído >30 dias) | `memory/archive/` + remover ponteiro |

**Formato TODOS:**
```
- [ ] **[P1/S]** Título — owner: X
  _contexto: por que surgiu, 1 linha_ (opcional)
```

---

## 3. Higiene (junto com a captura)

- **Docs de raiz acima do alvo** (`AGENTS.md` ≤130 linhas, `MEMORY.md` ≤200): propor `[OTIMIZAÇÃO]` — mover detalhe pro doc certo, deixar link.
- **Duplicação** entre AGENTS.md raiz e child: conteúdo universal mora só no pai; child só override.
- **Status estagnado** (`## Status (YYYY-MM-DD)` >30 dias): atualizar ou cortar.
- **TODOS.md:** `## Concluído` >20 itens → arquivar antigos, manter os 10 mais recentes.

---

## 4. Propor (formato único)

Ordem: **manutenção/higiene → captura nova** — saúde estrutural primeiro.

Cada item:
```
**N. [TAG] Título curto**
Arquivo: caminho → Seção
Conteúdo: [texto exato — 1-3 linhas]
Motivo: [por que muda comportamento futuro]
```

**Tags:** `[CRÍTICO]` · `[OTIMIZAÇÃO]` · `[ANTI-PATTERN]` · `[LIMPEZA]` · `[MANUTENÇÃO]`.

Conteúdo de memória: regra/fato → `**Why:**` → `**How to apply:**`. 1-3 linhas por bloco.

---

## 5. Aprovar e aplicar

> "Quais rejeitar ou ajustar? `n:X` ou `ajustar:X <texto>`. Qualquer outra resposta aprova tudo."

Interpretar: `ok`/texto livre → aprovar tudo · `n:X` → descartar X · `ajustar:X <texto>` → ajuste antes de escrever.

**Aplicação:**
1. Edits cirúrgicos — substituir seções, não reescrever.
2. Pra cada `create/update/delete` em `memory/*.md`, **append em `memory/log.md` ANTES** (hook bloqueia): `## [YYYY-MM-DD] <op> | <basename> (session=<id>)` + 1-3 linhas.
3. Limpar TODOS.md automaticamente: `[x]` com data em **Ativo** vão pra **Concluído** cronológico; `[x]` sem data → aviso, não move.
4. Reportar arquivos atualizados.

---

## Regras

- Nunca escrever sem aprovação (exceto a limpeza determinística do TODOS).
- Ler o arquivo-destino antes de propor; comprimir/substituir o obsoleto, não acumular.
- 0 capturas + itens de manutenção ainda é valor.
- Checar o AGENTS.md local pra convenções do projeto.
