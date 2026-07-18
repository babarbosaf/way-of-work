# DESIGN

> **Opcional — apague este arquivo se o projeto não tem superfície visual.**
>
> **Papel (se mantiver):** front-end e superfícies que o usuário consome — cor,
> tipografia, espaçamento, componentes, movimento. O quê funcional está no
> [PRD.md](PRD.md); o como técnico no [CONVENTIONS.md](CONVENTIONS.md). Decisões
> de superfície viram DDR em `docs/design/`.
>
> **Skill recomendada: `impeccable`** (Paul Bakaus, `github.com/pbakaus/impeccable`).
> Instala como plugin, atualiza sozinho (`autoUpdatesChannel`) — rode
> `scripts/bootstrap-design-skill.sh` uma vez (ou os 2 comandos abaixo direto):
> ```bash
> claude plugin marketplace add pbakaus/impeccable
> claude plugin install impeccable@impeccable --scope project
> ```
> Cobre craft/redesign, `critique` com rubric **P0-P3**, detector de anti-padrão
> via hook, live-edit. Skill `frontend-design` (bundled Claude Code) fica
> redundante uma vez instalado — não rodar as duas.
>
> **Loop de design (opcional, escale conforme o projeto):** regra de design tem
> duas camadas — a que **código verifica** (contraste, off-scale, z-index cru,
> vira lint/CI) e a que **exige julgamento** (hierarquia, tom, craft, vira
> `critique` do impeccable + P0-P3 gate no `ship-review`). Craft notável (bom
> ou ruim) vira entrada em `docs/design/exemplars.md`, não só memória.

<!-- Esqueleto — descomente e preencha se mantiver:
## Princípios
## Cor
## Tipografia
## Espaçamento, raio e elevação
## Componentes
## Movimento
## Do / Don't
## Decisões de design (DDR)
## Exemplars (docs/design/exemplars.md)
## Skill de design (impeccable — instalação via plugin)
-->
