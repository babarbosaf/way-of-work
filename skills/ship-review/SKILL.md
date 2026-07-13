---
name: ship-review
description: |
  Gate obrigatório pré-SHIP: review em 6 eixos (corretude, legibilidade, arquitetura, segurança, performance, simplificação), checklist de segurança e gates condicionais (Evaluator/rubric, smoke, doc-completeness, UI). Bloqueia ship com Critical em aberto.
  Invoque SEMPRE que o usuário disser "vou dar ship"/"pronto para commitar"/"vou fazer deploy"/"fechar essa feature", terminar feature M/L ou que toca prod, mexer em auth/input externo/credenciais/dados sensíveis, ou antes de `git commit` não-trivial.
---

> "Aprove quando definitivamente melhora a saúde geral do código, mesmo que não perfeito."
> "Segurança é restrição permanente, não fase posterior. Nunca commite credenciais."

---

## Processo

### 1. Ler spec e entender intenção
- Reler a spec antes de olhar o código
- Expectativa clara do que o código deveria fazer

### 2. Revisar testes primeiro — 4 camadas obrigatórias
- **Unit/contract tests:** funções e output structures (ex: `test_*_contracts.py`)
- **User journey tests:** se a feature encadeia 2+ comandos/handlers, usa state pendente, declara ação na interface com handler em outro arquivo, ou tem retorno assíncrono → exigir `test_user_journeys.py` com 1 classe `Test<Story>Journey` por user story. Sem isso, BLOQUEIA SHIP (Critical) — bugs como "ação wireada na interface mas dispatcher não roteia" só aparecem aqui.
- **Scenario test (computer-use):** se a mudança é user-facing E tem superfície dirigível (tela, CLI, bot, output publicado) → exigir scenario test executado via `verify` com evidência anexada (screenshot/transcript/output). Sem isso, BLOQUEIA SHIP (Critical) — a pele (UX quebrada, erro visível, empty state) só aparece dirigindo o app real; journey verde não cobre. Sem superfície dirigível → `n/a` justificado. Mecânica: `test-and-debug` → "Scenario tests".
- **Smoke automatizado pós-deploy:** se tem AC do tipo "rodar manualmente" → BLOQUEIA SHIP (Critical) e exige reescrita pra script de smoke com asserts. Validação manual humana é último recurso (estética, valor), nunca etapa padrão.
- Listar comportamentos cobertos e lacunas

### 3. Revisar implementação nos 6 eixos

**Corretude**
- Atende à spec? Trata edge cases? Sem erros de lógica?

**Legibilidade**
- Outro dev entenderia sem explicação? Nomes claros? Funções curtas?
- Sem duplicação significativa com código existente? (3+ linhas repetidas em 2+ lugares = candidato a extrair)
- Comentários explicam *por quê* (não *o quê*); código autoexplicativo dispensa comentário

**Arquitetura**
- Segue padrões do projeto? Abstração no nível certo? Sem over-engineering?
- **Pattern-scan obrigatório para mudança em módulo maduro** (>500 linhas ou >6 meses de existência): antes de aprovar, verificar que o autor descreveu 3 convenções existentes que estão sendo respeitadas (nomenclatura, estrutura de erro, organização de testes, etc). Razão: agentes geram dialeto novo facilmente; pattern-scan força respeito ao que já existe.

**Segurança** (ver checklist abaixo)
- Inputs validados? Sem credenciais? Logs sem dados sensíveis? Erros genéricos?

**Performance**
- Sem loops desnecessários? Sem chamadas síncronas bloqueantes? Sem N+1?

**Simplificação & Débito Técnico** (eixo obrigatório, não opcional)
- **Invocar a skill `simplify` sistematicamente** sobre o diff. Não pular — é o eixo que mais frequentemente captura abstração prematura.
- Caçar: regra de 3 violada (helper extraído na 1ª ou 2ª duplicação); abstração "reutilizável" sem 2º consumidor real; indireção que serve só ao caso atual; feature flag/migração sem critério de cleanup; acoplamento novo entre módulos antes separados; código morto deixado "por garantia".
- **Calibragem de severidade:**
  - **Critical** = compromisso de débito **irreversível** — abstração que vai travar refactor futuro inteiro, acoplamento que vai forçar reescrita ampla, migração sem rollback documentado. Critério pra Critical: "isso me força a aceitar o design errado por meses se mergear". Não é Critical: código verboso, naming subótimo, função grande que cabe quebrar.
  - **Important** = duplicação nova significativa, indireção desnecessária, código não usado, complexidade que cabe reduzir antes do ship sem virar over-engineering invertido.
  - **Suggestion** = polimento, opções de refactor que cabem em PR separado.
- **Princípio anti-purismo:** simplificação não é minimalismo. Se uma abstração tem 2+ consumidores reais hoje, ela não é prematura. Se uma duplicação tem semântica diferente (acidental, não fundamental), DRY força acoplamento ruim — flagar como Suggestion, não Important.

### 3b. Doc-completeness — modelo-v2 (Critical)

Só em repo **modelo-v2** (tem `docs/prd/` + `CONVENTIONS.md`). Verifica que a mudança fechou o loop no doc, não só no código. Cada item não-cumprido é **Critical** (bloqueia ship):

- **PRD do sistema atualizado.** Mudou comportamento/escopo de um sistema → o `docs/prd/<sistema>.md` reflete a nova verdade, não o estado antigo. Se a spec tinha "Ao fechar: atualizar PRD", confirma que foi feito.
- **CHANGELOG com entrada.** Há linha no `CHANGELOG.md` linkando a spec e as seções de PRD afetadas.
- **DESIGN/CONVENTIONS respeitados ou ADR.** Decisão técnica/estrutural nova → ou segue o CONVENTIONS vigente, ou vira ADR novo em `docs/conventions/adrs/`. Mudança no que o usuário final consome → DESIGN atualizado.
- **Documentação de código e dados.** Mexeu em model/source/seed dbt → `description` de negócio preenchida no `schema.yml`/`sources.yml`. Módulo Python novo/alterado → docstring. (Padrão em CONVENTIONS §Documentação.)

Repo legado (sem o modelo): pular este passo.

### 3c. UI/Design — projeto com `DESIGN.md` (condicional)

Só quando o projeto tem `DESIGN.md` E o diff toca superfície que o usuário consome
(componentes, telas, estilos). Revisa o que o usuário vê contra o `DESIGN.md`, não só o
código. **Rodar o lint de design primeiro** (se houver regra de design no ESLint/CLI): o
determinístico não precisa de juízo; o review humano foca no que o lint não vê
(hierarquia, fluxo, tom, craft). Classifica achados com rubric **P0-P3**, mapeada pra
severidade do gate:

- **P0 → Critical (bloqueia ship).** Viola contrato firme do DS de forma visível: cor
  fora do papel (ex: ouro como texto, ilegível), tela quebrada/superfície mock vazada,
  ação destrutiva sem confirmação, contraste de texto abaixo de AA, foco/teclado inacessível.
- **P1 → Important (resolve antes do ship).** Estado faltando num primitivo
  (default/hover/focus/active/disabled/loading/error incompletos), valor fora da escala de
  tokens, >1 primário por tela, empty/erro não tratado.
- **P2/P3 → Suggestion.** Polimento, micro-inconsistência sem impacto de uso.

Projeto sem `DESIGN.md`: pular este passo.

### 4. Classificar findings

| Severidade | Ação |
|---|---|
| **Critical** | Bloqueia ship — falha de segurança, perda de dados, funcionalidade quebrada |
| **Important** | Resolve antes do ship — testes faltando, arquitetura errada, error handling ausente |
| **Suggestion** | Opcional — clareza de nome, estilo |

**Todo finding não-trivial vira issue endereçada** (não morre no review): roteia destino+state via `~/.claude/skills/spec-and-plan/references/triage.md` (consome esta severidade → priority P0/P1/P2), cria no tracker do executor certo via `to-tickets.md`. Critical em aberto ainda bloqueia o ship; a issue garante que o resto não some.

### 5. Apresentar veredicto

- **Aprovado** / **Aprovado com ressalvas** / **Bloqueado**
- Findings classificados (+ issues criadas: `#id`)
- Pontos positivos
- O que exatamente corrigir antes de commitar

**Report de fechamento (tech-lead → sucinto, caveman).** Ao fechar a feature, emitir o bloco padrão pra humano/agente captar em 4 linhas:
```
feito: <o que mudou, observável>
como: <abordagem em 1 frase>
verify: <comando/prova que rodou + resultado>
findings: <N> (issues #...)
```
Sem prosa extra. É report pro tech-lead, não narração.

### 6. Runbook check (antes de fechar)

**Pergunta obrigatória:** este ship tem ritual operacional recorrente pós-deploy?

Sinais de "sim":
- Cron que roda semanal/mensal
- Setup manual com tokens ou permissões (OAuth, secrets, service account)
- Passo manual que vai se repetir
- Outra pessoa (ou eu em 3 meses) precisa operar sem reler a spec

**Se sim:** gerar `docs/runbooks/[nome].md` no projeto, apontando para a spec. Template mínimo:
```markdown
# Runbook — <nome>
Spec: SPEC-YYYY-NNN
Atualizado em: YYYY-MM-DD

## Quando rodar
## Pré-requisitos (one-time)
## Fluxo
## Troubleshooting
```

**Se não:** skip. Runbook é lembrete, não obrigação.

### 7. Atualizar PRD do sistema (se aplicável)

**Pergunta:** este ship muda o comportamento descrito em `docs/prd/<sistema>.md`?

**Se sim:**
- Atualizar o PRD pra nova verdade + link para a spec em `docs/specs/done/`
- Razão: PRD é fonte da verdade do sistema. Sem update, fica dessincronizado do que foi entregue.

**Se não:** skip. (Capture-lessons fará o fallback se ship-review não rodar — mas ship-review é o disparo primário porque está mais perto do momento de entrega.)

---

Checklist de segurança (aplicar sempre antes do ship) + regras absolutas: `references/security-checklist.md`.

---

Red flags e rationalizations: `references/red-flags-and-rationalizations.md`.

---

Matriz de ação por status do Gate 2 no Evaluator Status Block, regras de dual-writer, e Modo Evaluator (`--rubric`, findings/pass-N.md, threshold, cap de passes): `references/adversarial-evaluator-detail.md`.

---

## Smoke gate (via project.yaml)

Antes de aceitar ship, ler `.claude/project.yaml` (fallback: `CLAUDE.md` project-level). Se o diff toca `pipeline_paths`, o `smoke_cmd` é **obrigatório verde**. Sem project.yaml, smoke fica como recomendação humana, não gate duro.

---

## Verification

- [ ] Todos os 6 eixos revisados
- [ ] Eixo de simplificação rodou `simplify` sobre o diff (não pulado)
- [ ] (modelo-v2) Doc-completeness: PRD/CHANGELOG/ADR/descrições atualizados ou explicitamente n/a
- [ ] Nenhum finding Critical em aberto
- [ ] Findings Important resolvidos ou com decisão documentada
- [ ] Checklist de segurança completo
- [ ] Runbook criado (se aplicável) ou pulado com consciência
- [ ] Suite de testes verde após correções
- [ ] Veredicto comunicado ao usuário
- [ ] `bash scripts/check-security.sh` passou (onde aplicável)

---

## Próximo passo

Veredicto Aprovado → SHIP via ciclo de versionamento do projeto (ver `git-workflow-and-versioning`):

1. `git push` da branch.
2. PR pra `main` → CI do projeto verde (build + testes + journeys).
3. Review humano + merge (squash/rebase, sem merge commit).
4. Deploy pelo mecanismo do projeto (CI/CD, workflow de deploy, ou comando documentado no runbook). Preferir deploy automatizado com smoke pós-deploy + rollback em falha; nunca deploy manual de prod sem trilha.

Veredicto Bloqueado → volta para `test-and-debug` ou ajuste direto.
Pós-ship com ritual recorrente → criar runbook em `docs/runbooks/`.

### Verificações adicionais

- **Smoke pós-deploy verde** — não shipar com smoke amarelo/falho.
- **Sem regressão de cobertura** — a suite de journeys não pode ter menos cenários verdes que a última entrega, nem um scenario test antes existente pode sumir (regressão silenciosa de cobertura é Critical).
- **Tool-makes-tool** — se você fez ≥2x a mesma tarefa manual durante o ship (curl, comparação de logs, listar recursos), sugerir tool comitada ANTES de SHIP. Compounding via reuso, não memória.
