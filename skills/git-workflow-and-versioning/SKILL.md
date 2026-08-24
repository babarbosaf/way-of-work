---
name: git-workflow-and-versioning
description: |
  Disciplina de versionamento + gate de ship: atomic commits (~100 linhas, máx 300), trunk-based, mensagens que explicam o porquê, checklist pré-ship (testes, segurança, docs vivos).
  Invoque SEMPRE que o usuário pedir para "commitar"/"dar push"/"abrir PR"/"dar ship"/"fazer deploy"/"fechar essa feature", fechar incremento do BUILD, mencionar branch nova ou merge, ou antes de `git commit` não-trivial.
  Não invoque para: commits triviais de docs/config sem proteção de branch, operações de leitura sem intenção de commit.
---

> "Commits são save points. Branches são sandboxes. Histórico é documentação."
> Especialmente importante quando agentes geram código rapidamente.

---

## Overview

Garante que cada entrega tem um histórico limpo, reversível e legível. Trunk-based development com atomic commits e branches de curta duração.

---

## Modos de operação

As disciplinas abaixo (atomic, diff revisado, sem secrets, mensagem com *porquê*) valem para **os dois modos**. O que muda é quem aperta os botões.

**Modo autônomo (default neste setup):**
- O agente dirige o ciclo inteiro até a borda do push: `git switch`/branch → implementa → revisão (ver § 3 camadas) → `git add -p` → `git commit`. Pode fazer N commits e abrir PR draft sozinho.
- **Único gate humano: `git push`.** O agente **para e pede autorização** antes de qualquer push. Como push é pré-requisito de merge em `main`, esse é o ponto de controle do humano. Reforçado de forma determinística por regra `ask` em `Bash(git push:*)` no `settings.json`, mesmo que o agente esqueça, o harness trava.
- Atribuição: commit com o humano como autor/committer + rodapé `Co-Authored-By` (ver step 4).

**Modo human-driven:**
- O humano executa o `git commit` (repos onde se prefere controle commit a commit). O agente apresenta o comando pronto e revisado.

---

## 3 camadas de revisão (a ordem importa)

Revisão pesada e ciclos de ajuste acontecem **local, antes do push**, nunca "push → revisa → corrige → re-push" (isso fura o gate e polui o PR). O PR é registro permanente; o CI é a rede pós-push.

1. **Revisão de código (local, antes do commit):** subagent reviewer em contexto fresco (`/code-review`). Segunda opinião adversarial (`peer-review.sh diff main`) é opcional, recomendada se o diff toca prod ou é caro de reverter. Quem revisa nunca é quem implementou.
2. **Testes do produto (local + CI):** suíte completa verde local é pré-condição pro push; o CI re-roda em ambiente limpo após o push.
3. **CI no PR (pós-push, automático):** full suite + lint em ambiente limpo. Merge em `main` **só com CI verde**.

**Documentação do feedback:** PR-first. Findings vão pro **comentário da PR** (co-localizado com o diff, resolvível).

---

## When to Use

**Use quando:**
- Pronto para shipar um incremento (fase SHIP)
- Antes de iniciar trabalho em feature nova (branch)
- Após corrigir um bug

**Não use quando:**
- Ainda no meio do BUILD → commita quando o incremento estiver verde

---

## Gate de ship (antes de commit não-trivial / deploy / fechar feature)

Um checklist, uma passada. **Critical aberto bloqueia o ship.**

- [ ] **Intenção:** o diff faz o que a spec/pedido descreve? Hunk que não casa = refactor não-relacionado → commit separado.
- [ ] **Testes:** suite completa verde; comportamento novo tem teste; bug corrigido tem teste de regressão. AC "rodar manualmente" é anti-padrão → reescrever como script com assert.
- [ ] **`/simplify` sobre o diff** (builtin do Claude Code), recomendado, não bloqueante. Caça: regra de 3 violada (helper na 1ª duplicação), abstração sem 2º consumidor real, indireção que serve só ao caso atual, código morto "por garantia". Anti-purismo: abstração com 2+ consumidores reais não é prematura; duplicação com semântica diferente não vira DRY forçado.
- [ ] **Segurança:** `references/security-checklist.md`, inputs validados, sem credenciais no diff, logs sem dado sensível, erros genéricos pro usuário.
- [ ] **Docs vivos:** comportamento de produto mudou → `PRD.md` atualizado; fluxo → `ROUTES.md`; padrão visual → `DESIGN.md`; padrão técnico → `CONVENTIONS.md`; decisão cara de reverter → ADR em `docs/adrs/`.
- [ ] **Segunda opinião (opcional):** diff que toca prod ou é caro de reverter → oferecer `peer-review.sh diff` antes do commit. O dono decide.

**Severidade:** Critical = segurança, perda de dado, funcionalidade quebrada, débito irreversível ("me força a aceitar o design errado por meses"), bloqueia. Important = resolver antes do ship ou virar issue rastreada. Suggestion = opcional.

**Report de fechamento (4 linhas, sem prosa):**
```
feito: <o que mudou, observável>
como: <abordagem em 1 frase>
verify: <comando/prova que rodou + resultado>
findings: <N> (issues #...)
```

---

## Process

- [ ] **1. Checar staged changes antes de commitar**
  - Ação: `git diff --staged`, revisar o que está sendo commitado
  - **Staging por propósito**: nunca `git add .` cego. Use `git add -p` ou por path, agrupando por intenção (feat → test → docs → refactor → chore). Cada grupo lógico vira um commit
  - Verificar: sem `.env`, sem credenciais, sem arquivos de debug
  - Saída: diff limpo e intencional

- [ ] **2. Validar tamanho do commit**
  - Regra: ~100 linhas por commit; máximo aceitável ~300 linhas para mudança lógica única
  - Se > 300 linhas: divida em commits menores antes de continuar
  - Saída: commit atômico com uma responsabilidade

- [ ] **3. Rodar verificações pré-commit**
  - Ação: `suite de testes do projeto` → todos passando
  - Saída: zero regressões

- [ ] **4. Escrever mensagem descritiva**
  - Formato:
    ```
    T##: descrição do que foi implementado
    Fix: descrição do bug corrigido
    Refactor: descrição do que foi refatorado
    ```
  - Rodapé obrigatório: `Co-Authored-By: Claude <noreply@anthropic.com>` (ajustar modelo conforme sessão)
  - Mensagem deve explicar o *porquê*, não o *o quê* (o diff já mostra o quê)
  - Saída: mensagem de commit clara

- [ ] **5. Commit + parar no push**
  - **Modo autônomo (default):** o agente executa o `git commit` direto, após revisão verde (§ 3 camadas). Em seguida **para e pede autorização** antes de `git push`, esse é o gate humano. Nunca pushar sem OK explícito do dono do repo
  - **Modo human-driven:** apresentar o comando de commit pronto para o dono do repo executar
  - Atribuição: rodapé `Co-Authored-By` em ambos os modos
  - Saída: commit no histórico; push só após autorização

---

## Estratégia de branches

**Trunk e branch_prefix vêm do `.claude/project.yaml`** (`repo.trunk`, `repo.branch_prefix`). Fallback: `CLAUDE.md` project-level. Padrão (sem project.yaml): trunk=`main`, branch_prefix=`feature`. Repos podem ter trunk diferente (ex.: sp-platform usa `stg`).

```
<trunk> (sempre deployável)
  └── <branch_prefix>/morning-command   (1-3 dias, depois merge e delete)
  └── fix/slack-timeout                  (horas, depois merge e delete)
```

- Feature flags para código incompleto que vai ao main antes de estar pronto
- Branches de longa duração → sinal de feature mal dimensionada

**Branch por tarefa (branch-per-ask):**
Tarefa que bate o critério de PR (§ Estratégia de PR: >1 arquivo, >30min, prod,
endpoint/handler/cron/pipeline) abre branch isolada dedicada a ela, mesmo em
sessão solo com agente. Tarefa trivial (fix 1 linha, config, doc sem risco de
prod) vai direto no trunk, branch nesse caso é atrito sem ganho de proteção.
Custo de isolamento é proporcional ao blast radius da tarefa, não constante.

Merge dessa branch é sempre **squash merge** (histórico limpo, 1 commit por
tarefa em `main`) seguido de **delete da branch**, nunca deixar branch órfã
pós-merge.

---

Sessões paralelas com worktree (1 sessão = 1 worktree = 1 branch) e comandos de referência (switch/restore/clone): `references/worktree-and-commands.md`.

---

## Estratégia de PR

**Quando commitar direto em main (sem PR):**
- Docs (CLAUDE.md, MEMORY.md, strategy.md, runbooks)
- Configs sem efeito em prod (settings locais, .gitignore, hooks de dev)
- Scripts one-shot que não rodam em prod
- Mudanças triviais (1-3 linhas) com testes locais OK
- Qualquer mudança quando não há proteção de branch e o repo é pessoal/exploratório

**Quando abrir PR:**
- Feature M+ (>30 min de trabalho ou >1 arquivo)
- Código que vai pra prod (Render, Vercel, Supabase, qualquer ambiente compartilhado)
- Auth, handlers de input externo (Slack, webhooks, APIs públicas), credenciais
- Mudança que merece runbook
- Refactor que muda contrato de função pública

**Self-review do próprio PR (não vira teatro se for checklist):**
- [ ] Ler diff de cima a baixo no GitHub (não no editor local, viés diferente)
- [ ] Cada hunk casa com a spec ou descrição? (se não, sobrou refactor não relacionado, mover pra commit/PR separado)
- [ ] Gate de ship (seção acima) rodou, checklist completo, sem Critical aberto
- [ ] CI verde no PR

**Quando delegar review humano:**
- PR > ~300 linhas em área de prod
- Código de auth/segurança/dados sensíveis
- Mudança que afeta usuários externos diretamente
- Quando você está cansado/com pressa (caso clássico de erro)

---

Fluxo CI / preview / deploy (setup mínimo por projeto novo, Render/Vercel): `references/ci-deploy-flow.md`.

---

Red flags e rationalizations: `references/red-flags-and-rationalizations.md`.

---

## Verification

- [ ] `git diff --staged` revisado, sem arquivos indesejados
- [ ] Commit ≤ 300 linhas (idealmente ~100)
- [ ] `suite de testes do projeto` passando
- [ ] Mensagem de commit descritiva com rodapé Co-Authored-By
- [ ] Revisão verde (§ 3 camadas) antes do commit
- [ ] `git push` só após autorização explícita do dono do repo (gate)
