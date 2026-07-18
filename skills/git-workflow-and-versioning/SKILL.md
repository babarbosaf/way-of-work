---
name: git-workflow-and-versioning
description: |
  Disciplina de versionamento: atomic commits (~100 linhas, máx 300), trunk-based, mensagens que explicam o porquê, sem credenciais no diff.
  Invoque SEMPRE que o usuário pedir para "commitar"/"dar push"/"abrir PR", fechar incremento do BUILD, mencionar branch nova ou merge, ou antes de `git commit` não-trivial.
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
- **Único gate humano: `git push`.** O agente **para e pede autorização** antes de qualquer push. Como push é pré-requisito de merge em `main`, esse é o ponto de controle do humano. Reforçado de forma determinística por regra `ask` em `Bash(git push:*)` no `settings.json` — mesmo que o agente esqueça, o harness trava.
- Atribuição: commit com o humano como autor/committer + rodapé `Co-Authored-By` (ver step 4).

**Modo human-driven:**
- O humano executa o `git commit` (repos onde se prefere controle commit a commit). O agente apresenta o comando pronto e revisado.

---

## 3 camadas de revisão (a ordem importa)

Revisão pesada e ciclos de ajuste acontecem **local, antes do push** — nunca "push → revisa → corrige → re-push" (isso fura o gate e polui o PR). O PR é registro permanente; o CI é a rede pós-push.

1. **Revisão de código (local, antes do commit):** subagent reviewer em contexto fresco (`/code-review`) + **Adversarial Evaluator** (`peer-review.sh diff main`) se diff M+ ou área crítica. Quem revisa nunca é quem implementou.
2. **Testes do produto (local + CI):** suíte completa verde local é pré-condição pro push; o CI re-roda em ambiente limpo após o push.
3. **CI no PR (pós-push, automático):** full suite + lint em ambiente limpo. Merge em `main` **só com CI verde**.

**Documentação do feedback:** PR-first. Findings + Evaluator Status Block vão pro **comentário da PR** (co-localizado com o diff, resolvível). O sidecar `.gate-findings/` é buffer efêmero do loop (gitignored); só vira artefato commitado em repo sem remote/PR. Ver `~/.claude/docs/adversarial-evaluator.md`.

---

## When to Use

**Use quando:**
- Pronto para shipar um incremento (fase SHIP)
- Antes de iniciar trabalho em feature nova (branch)
- Após corrigir um bug

**Não use quando:**
- Ainda no meio do BUILD → commita quando o incremento estiver verde

---

## Process

- [ ] **1. Checar staged changes antes de commitar**
  - Ação: `git diff --staged` — revisar o que está sendo commitado
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
  - **Modo autônomo (default):** o agente executa o `git commit` direto, após revisão verde (§ 3 camadas). Em seguida **para e pede autorização** antes de `git push` — esse é o gate humano. Nunca pushar sem OK explícito do Benedito
  - **Modo human-driven:** apresentar o comando de commit pronto para o Benedito executar
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

**Branch por tarefa (branch-per-ask), condicional ao mesmo gate do `spec-and-plan`:**
Tarefa que bate o critério de PR (§ Estratégia de PR — >1 arquivo, >30min, prod,
endpoint/handler/cron/pipeline) abre branch isolada dedicada a ela, mesmo em
sessão solo com agente. Tarefa trivial (fix 1 linha, config, doc sem risco de
prod) vai direto no trunk — branch nesse caso é atrito sem ganho de proteção.
Custo de isolamento é proporcional ao blast radius da tarefa, não constante.

Merge dessa branch é sempre **squash merge** (histórico limpo, 1 commit por
tarefa em `main`) seguido de **delete da branch** — nunca deixar branch órfã
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
- [ ] Ler diff de cima a baixo no GitHub (não no editor local — viés diferente)
- [ ] Cada hunk casa com a spec ou descrição? (se não, sobrou refactor não relacionado — mover pra commit/PR separado)
- [ ] Rodar `ship-review` skill como gate (6 eixos + checklist segurança)
- [ ] Codex Gate se diff M+ (>~150 linhas) ou área crítica — usar Evaluator Status Block
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

- [ ] `git diff --staged` revisado — sem arquivos indesejados
- [ ] Commit ≤ 300 linhas (idealmente ~100)
- [ ] `suite de testes do projeto` passando
- [ ] Mensagem de commit descritiva com rodapé Co-Authored-By
- [ ] Revisão verde (§ 3 camadas) antes do commit
- [ ] `git push` só após autorização explícita do Benedito (gate)
