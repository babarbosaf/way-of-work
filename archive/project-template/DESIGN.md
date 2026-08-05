# DESIGN

> **Opcional — apague este arquivo se o projeto não tem superfície visual.**
>
> **Papel (se mantiver):** front-end e superfícies que o usuário consome — cor,
> tipografia, espaçamento, componentes, movimento. O quê funcional está no
> [PRD.md](PRD.md); o como técnico no [CONVENTIONS.md](CONVENTIONS.md). Decisões
> de superfície viram DDR em `docs/design/`.
>
> **Hierarquia de fonte da verdade:** o projeto **Claude Design** (`claude.ai/design`)
> é a base canônica de design — cross-produto, onde componente/tela nasce ou evolui
> antes de qualquer implementação. Este arquivo (`DESIGN.md`) é **aplicação local**:
> registra o que foi usado neste produto e por quê, não decide direção nova. Skill
> `design-workflow` orquestra o fluxo completo (buscar na base → discutir
> reuso/evolução/criação → validar com Artifact → salvar incremento na base →
> aplicar aqui). Invoque sempre que for construir componente/tela novo ou redesenhar
> existente.
>
> **Skill de refino: `impeccable`** (Paul Bakaus, `github.com/pbakaus/impeccable`).
> Instala como plugin, atualiza sozinho (`autoUpdatesChannel`) — rode
> `scripts/bootstrap-design-skill.sh` uma vez (ou os 2 comandos abaixo direto):
> ```bash
> claude plugin marketplace add pbakaus/impeccable
> claude plugin install impeccable@impeccable --scope project
> ```
> Cobre craft/redesign, `critique` com rubric **P0-P3**, detector de anti-padrão
> via hook, live-edit. Refina o que a referência não especifica (hierarquia, ritmo,
> contraste) — **não decide** direção estética nova, isso vem do `design-workflow`.
> Skill `frontend-design` (bundled Claude Code) fica redundante uma vez instalado —
> não rodar as duas.
>
> **Loop de design (opcional, escale conforme o projeto):** regra de design tem
> duas camadas — a que **código verifica** (contraste, off-scale, z-index cru,
> vira lint/CI) e a que **exige julgamento** (hierarquia, tom, craft, vira
> `critique` do impeccable + P0-P3 no gate de ship). Craft notável (bom
> ou ruim) vira entrada em `docs/design/exemplars.md`, não só memória.

<!-- Esqueleto — descomente e preencha se mantiver:
## Princípios
## Cor
## Tipografia
## Espaçamento, raio e elevação
## Componentes
   claude-design-project-id: <uuid do projeto canônico em claude.ai/design>
   (changelog de aplicação local — o que foi puxado da base e por quê;
   não é fonte da verdade, isso é o projeto Claude Design)
## Movimento
## Do / Don't
## Decisões de design (DDR)
## Exemplars (docs/design/exemplars.md)
## Skill de design (design-workflow — orquestra a base; impeccable — refina craft)
-->
