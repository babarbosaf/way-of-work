# Runbook — Adotar o way-of-work

Como colocar este modelo de trabalho pra rodar. Três modos de consumo; escolha um pela pergunta "quem é o dono da fonte de verdade?".

| Modo | Fonte de verdade | Quando |
|------|------------------|--------|
| User-level | `~/.claude` na sua máquina | Default. Todo projeto local herda. |
| Cloud multi-source | O repo, clonado por rotina em nuvem | Agente agendado (`/schedule`) que roda isolado. |
| Submodule | O repo, vendorizado no projeto | CI hermético / projeto self-contained. |

---

## Modo 1 — User-level (canônico)

Fonte única na máquina. Toda sessão de Claude Code lê `~/.claude` em runtime.

### Setup

```bash
# Se ~/.claude já existe e tem coisa sua, faça backup antes.
mv ~/.claude ~/.claude.bak 2>/dev/null || true
git clone https://github.com/babarbosaf/way-of-work ~/.claude
```

### Override privado (obrigatório se você usa roteamento de modelo ou scope pago)

O que é específico do seu ambiente — scope de API paga, path do `.env`, roteamento de findings pra repos de negócio — **não vive no repo**. Vive em `config/*.local.json`, que está no `.gitignore` e faz merge sobre a base pública em runtime (objetos deep-merge, arrays substituem).

```bash
cp config/model-policy.json config/model-policy.local.json
# edite o .local.json com seus valores reais (scope, env_file, finding_routing)
```

Verifique que o merge resolve seus valores:

```bash
scripts/model-policy-effective.sh config/model-policy.json | jq .backends.claude_api.scope_pattern
# deve imprimir seu scope real, não o placeholder
```

### Verificação pós-instalação

```bash
ls ~/.claude/skills            # skills presentes
git -C ~/.claude check-ignore config/model-policy.local.json   # override é ignorado
```

Abra uma sessão nova de Claude Code em qualquer projeto — as skills (`/spec-and-plan`, etc.) devem estar disponíveis.

---

## Modo 2 — Cloud multi-source

Rotinas de agente em nuvem clonam way-of-work junto com o repo-alvo. O campo `sources` da rotina é um array — liste os dois.

```json
"sources": [
  { "git_repository": { "url": "https://github.com/babarbosaf/way-of-work" } },
  { "git_repository": { "url": "https://github.com/SEU-ORG/SEU-REPO" } }
]
```

O agente sobe num ambiente isolado com ambos clonados e herda skills/docs/hooks do way-of-work. Override privado **não** vai por aqui (o `.local.json` é gitignored) — configure o que o agente precisa via secrets/env do ambiente de nuvem.

---

## Modo 3 — Submodule (projeto self-contained)

Projeto que não pode depender do `~/.claude` da máquina (CI hermético, onboarding zero-config) vendoriza o repo:

```bash
git submodule add https://github.com/babarbosaf/way-of-work .claude
git commit -m "chore: adota way-of-work como submodule"
```

Atualizar pra a última versão upstream:

```bash
git -C .claude pull origin main
git add .claude && git commit -m "chore: atualiza way-of-work"
```

Trade-off: você fixa uma versão e atualiza deliberadamente (bom pra reprodutibilidade), ao custo de não herdar melhorias automaticamente como no modo user-level.

---

## Melhorias fluem de volta

Adotou, usou, sentiu uma dor, ajustou a skill? Proponha upstream — veja [`CONTRIBUTING.md`](../../CONTRIBUTING.md). O modelo melhora pelo uso real, não por planejamento antecipado.
