# to-tickets — slice de spec → issue no tracker

**Fronteira MECE (não redefinir o que é de outro verbo):**
- **to-tickets** (aqui): slice → issue rica, executável sem contexto.
- **triage** (`references/triage.md`): finding/bug → destino + state. Não cria template, roteia.
- **refine** (`references/refine.md`): item magro → executável. Enriquece, não roteia.
- **`delega:`** (skill `delegate` + `model-policy.json`): task → worker. to-tickets **reusa** o marcador, não redefine.
- **ship-review §4**: severidade (block/não). to-tickets/triage **consomem**, não recriam.

## Quando roda

Fase 2 fecha as slices → materializa cada uma como issue. **Push automático no build, pós-gate** (só slice que passou o gate §5 vira issue; rascunho não vaza pro tracker). Issue é a **fonte da verdade da execução** daí pra frente; a spec é fonte da verdade do design. Spec não rastreia status — issue rastreia.

## Backend — lê de `project.yaml`

`tracker.backend` (ou `tracker.tech`/`tracker.nontech` quando o repo roteia duplo) decide o writer:

| backend | writer | relação obrigatória |
|---|---|---|
| `github` | `gh issue create --title … --body … --label ready-for-agent` + `gh issue edit` pra `blocked_by` | — |
| `linear` | MCP Linear (`create_issue`), team/estado/label de `project.yaml` | initiative/area de `project.yaml` |
| `notion` | MCP Notion (`API-post-page`) no `tasks_db` | linka relação (ver abaixo) |

**Roteamento tech vs nontech** (ex.: repo com iniciativa + código): task técnica (código, PR, endpoint) → `tracker.tech` (github). Task de iniciativa/OKR/não-técnica → `tracker.nontech` (notion), sempre vinculada a um KR.

**Relações por projeto** (de `project.yaml`, entram na criação):
- exemplo: issue no `tasks_db` (Acionável) **linka o repo** no `repos_db` (ex.: `<seu-repo>`).
- comercial nontech: issue no `tasks_db` **linka um KR** no `kr_db`. Sem KR = não cria (toda task pendura num KR).

## Links vivos — regra dura

Issue referencia **só URL cloud** (github blob permalink ou página do tracker). **Nunca path local** (`docs/specs/...`, `file://`) — stale garantido.
- Spec no repo github: **commit + push antes de criar as issues**; referencia pelo blob URL (`github.com/<org>/<repo>/blob/<sha>/docs/specs/.../spec.md`).
- Spec nativa no tracker (Notion): referencia a página.
- Cross-ref github↔notion no mesmo projeto é OK (task Notion aponta pro PR/issue github e vice-versa).

## Template canônico da issue (mesmos campos, todo backend)

```
Título: <verbo + resultado observável, conciso>

Contexto: <1-2 frases + link CLOUD da spec/PRD>

O que construir: <comportamento end-to-end user-facing — NÃO camada-a-camada>

Aceite (SIM/NÃO, 2-3 checkpoints verificáveis):
- [ ] <critério observável>

Arquivos (hint, por URL cloud): <blob URLs — pista, não a spec>
verify: <verify_cmd da task>

blocked_by: <#id das issues que travam esta — relação nativa no tracker>
priority: <P0|P1|P2>
delega: <task-type | não (orquestrador)>
executor: <primário resolvido> (fallback: <próximo na cascata>)   # DERIVADO do delega via model-policy, não hand-authored
spec: <link cloud | none>   # opcional; ausência não bloqueia
label: ready-for-agent      # default; muda pra ready-for-human se delega=não
```

## Regras de fatiamento (tracer-bullet)

- Slice = fatia vertical demoável/verificável sozinha, **cabe numa janela de contexto fresca**. Não fatiar por camada (schema/API/UI separados).
- **`blocked_by` ordena**: bloqueadores primeiro; relação nativa do tracker (github sub-issues, Linear blocking, Notion relation). Priority ≠ dependência — os dois campos coexistem.
- Prefactor antes: "make the change easy, then make the easy change". Refactor largo = expand→contract em issues separadas.

## Executor + fallback — derivado, não reescrito

O `delega: <task-type>` resolve a cascata do `model-policy.json` (`tasks.<type>`: backend primário → fallback). A issue **renderiza** `executor: X (fallback: Y)` lendo a cascata — pra humano/loop ler quem pega e quem assume se o primário cair. Não hand-authora executor; muda a policy, muda o render.

## Invariante de completude (presença, checada no gate)

Toda slice vira issue com **`{título, aceite, priority, delega-decision, destino/backend, blocked_by}`** preenchidos. Falta qualquer um = gate bloqueia o build. Presença é mecânica aqui; **acerto** da triagem/estimativa é do review adversarial, não deste passo.

## Terreno pra loop (preparado, não ativado)

Issue cloud + `ready-for-agent` + executor renderizado + links vivos = consumível por loop headless (`/schedule`) quando ligar. Loop só pega `ready-for-agent`. Tracker headless: github nativo; Linear/Notion exigem token de API guardado (não o MCP OAuth interativo, que morre em run headless).
