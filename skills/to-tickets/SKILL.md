---
name: to-tickets
description: |
  Materializa o mapa de slices de uma spec aprovada em tickets executáveis por agente frio: ownership de arquivo, aceite, dependência e marcador de paralelismo.
  Invoque quando o usuário pedir `/to-tickets`, quando uma spec for aprovada, ou quando finding e bug soltos precisarem virar trabalho endereçado.
  Não invoque para: escrever a spec (isso é `to-spec`), tarefa que cabe numa sessão e vai direto pro código, ou despachar worker (isso é `delegate`).
---

> O ticket é a unidade de execução. A spec é a fonte da verdade do desenho;
> o ticket é a fonte da verdade do trabalho.
> Um ticket cabe numa janela de contexto fresca, porque é isso que ele vai receber.

Spec aprovada que não vira ticket é plano soterrado. No estado antigo o plano
ocupava 3% do documento e o build acontecia inline, sequencial, numa sessão só.

---

## Onde o ticket mora, e é um lugar só

Lê `tracker.backend` do `.claude/project.yaml`:

| backend | destino |
|---|---|
| `none` (ausente) | `docs/specs/<slug>/tickets/<NN>-<slug>.md` |
| `github` | `gh issue create` |
| `linear` | MCP Linear |
| `notion` | MCP Notion no `tasks_db` |

**Um arquivo por ticket, nunca um arquivo combinado.** Arquivo único sofre corrida
quando dois agentes escrevem ao mesmo tempo.

**Arquivo ou tracker, nunca os dois.** Espelho apodrece: uma cópia avança, a outra
não, e ninguém sabe qual manda.

Backends, template por backend e regra de link vivo: `references/backends-e-template.md`.

## O ticket

```
NN [tamanho] [P]  <verbo + resultado observável>

O que construir: <comportamento end-to-end. Não camada-a-camada>

files:      <arquivos que ESTE ticket possui>
blocked_by: <IDs reais, ou "nenhum">
delega:     <task-type | não>
verify:     <comando que prova que fechou>

Aceite:
- [ ] <critério observável>
- [ ] <critério observável>
```

Três campos carregam o peso, e são os que faltavam:

- **`files:` é ownership, não pista.** Nenhum outro ticket da leva toca esses
  arquivos. Sem isso não há paralelismo seguro: conflito entre agentes diferentes
  é o dobro do conflito dentro de um mesmo agente.
- **`blocked_by:` com ID real** do tracker (`#28`), nunca pseudo-ID de rascunho
  (`#S3`). ID que não resolve não ordena nada e mente pro loop.
- **`verify:`** vem do `verify_cmd` do `project.yaml`. Placeholder `<TODO: ...>`
  ali significa que nenhum ticket do repo tem como fechar: resolver antes.

`delega:` é decidido aqui e é **vinculante no build**. Task marcada, o `delegate`
despacha; sem marcador, roda inline e ninguém reavalia. Degradar é permitido,
promover não.

## Fases, e o marcador `[P]`

```
Fase 0  Setup         scaffolding, migration base       sequencial
Fase 1  Foundational  o que todo mundo depende          NUNCA [P]
Fase 2  Slices        vertical, demoável                [P] quando files disjuntos
Fase 3  Polish        docs, PRD, ticket de integração   sequencial
```

`[P]` só quando os `files:` não se cruzam com nenhum outro `[P]` da mesma fase.
Na dúvida, não marca: um `[P]` errado custa mais que um ticket sequencial.

**Mudança cross-cutting nunca é `[P]`.** Import, config central, wiring, tabela de
rotas: vai pro ticket de integração da Fase 3, por último. Junto com ownership de
arquivo e "criar arquivo novo em vez de editar compartilhado", é a terceira regra
que faz uma leva paralela sobreviver ao merge.

Regras de fatiamento, expand/contract e o teste do demo: `references/fatiamento.md`.

## Fases da skill

- [ ] **1. Ler o mapa de slices** da spec aprovada. Slice que não passa no teste do
      demo volta pro fatiamento antes de virar ticket.
- [ ] **2. Separar faz-agora de bloqueado-em-externo** (auth, sign-off, credencial,
      dado que não chegou). Bloqueado leva `bloqueado: <X>` e vai depois.
- [ ] **3. Escrever cada ticket**, tamanho `XS/S/M`. Nunca `L`, quebrar.
- [ ] **4. Carimbar `files:`, `[P]` e `delega:`** em todos. Ticket sem os três é
      planning gap, não decisão implícita.
- [ ] **5. Rastrear `D-NN` → ticket.** Decisão sem ticket é decisão órfã.
- [ ] **6. Rodar o lint.** Gate de presença:
      `~/.claude/scripts/check-spec.py --tickets <dir>`
- [ ] **7. Materializar** no destino do `project.yaml`. Rascunho não vaza pro tracker.

## Do ticket ao código

Execução é do `/execute`: branch de integração por rodada, worker em worktree por
ticket, merge serial, uma PR ao final. Regra: **1 ticket ou 1 `/execute` = 1 worktree
= 1 branch = 1 PR**. Detalhe em `skills/execute/references/branching-1-pr.md`.

O que este passo garante pra isso funcionar: todos os `[P]` de uma fase com `files:`
disjuntos, `blocked_by` com ID real, e `verify:` que roda. Sem os três o `/execute`
trava na Fase 0, e é aqui que se conserta.

## Ticket sem spec

Bug e finding chegam soltos e não precisam de spec. Roteamento e state machine
(`needs-triage → needs-info → ready-for-agent`): `references/triage.md`. Item magro
que precisa engordar até ficar executável: `references/refine.md`.

## Verification

- [ ] Todo ticket com `files:`, aceite, `blocked_by`, `verify:`, `delega:`
- [ ] Nenhum `files:` se cruza entre tickets `[P]` da mesma fase
- [ ] Cross-cutting fora da Fase 2
- [ ] `blocked_by` resolve pra ID que existe
- [ ] `~/.claude/scripts/check-spec.py --tickets` verde
- [ ] Cada ticket responde "o que eu demonstro quando isto fecha?"

Exemplo completo, quatro tickets reais com `[P]` e dependência:
`references/exemplo.md`.

**Próximo passo:** `/execute <slug>`. Ele despacha os `delega:` pro worker, roda o
resto inline, e fecha com `git-workflow-and-versioning` numa PR só.
