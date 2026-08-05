# TODOS

> Fila local curta de tarefas — o que está na mesa agora. **Não é a fonte da
> verdade.** Onde a task vive:
>
> - **Aqui** (`TODOS.md`): captura rápida, item pequeno, trabalho da sessão.
>   Formato: `- [ ] [effort] descrição — owner · critério de pronto`.
> - **Ali** (o tracker oficial): declarado em [`.claude/project.yaml`](.claude/project.yaml)
>   → `tracker.backend` (github/notion/linear). É a fonte da verdade da
>   execução; `spec-and-plan` desdobra slices de spec em issues lá. Só o que
>   está `executable_states` é pegável por loop/delegate.
>
> Regra: item que sobreviver à sessão ou virar trabalho real migra pro tracker.
> `TODOS.md` não acumula histórico — item feito sai daqui (o registro fica na
> issue fechada e no `CHANGELOG.md`).

## Agora

- [ ] [S] <descrição da tarefa> — <owner> · <critério de pronto>

## Bloqueado

- [ ] [M] <tarefa> — bloqueado: <o que destrava>
