# Echo-preamble pra subagente Claude fresco

`Agent` (sem `subagent_type: "fork"`) spawna subagente com contexto vazio —
herda só `CLAUDE.md` + tools + MCP servers, **não herda skills da sessão**.
Se esse subagente precisar operar `delegate`/`model-policy.json`
(escolher task-type, interpretar exit codes, seguir o protocolo de
integração pós-worktree), ele começa cego. Padrão portado de
`jbaruch/sub-agent-delegation` (registro Tessl): passagem explícita de
contexto + eco de validação, em vez de assumir herança.

## Quando usar

- Vai spawnar um `Agent` fresco (não-`fork`) que vai chamar `delegate.sh`
  diretamente ou decidir task-type por conta própria.
- Não usar pra `fork` (herda contexto completo, já sabe) nem pra subagente
  que só executa um comando fixo passado por você (não precisa "entender"
  a skill, só rodar o comando).

## Como montar

1. Gerar o preâmbulo com os pontos que esse subagente específico precisa
   saber (não a skill inteira — só o que a tarefa dele toca):

   ```bash
   ~/.claude/skills/delegate/scripts/echo_preamble.sh build \
     "task-types disponíveis: review, second-opinion, scan, boilerplate, implement" \
     "exit 2 = cascata esgotada — você assume a tarefa inline, nunca re-tenta em loop" \
     "protocolo de integração pós-worktree: revisar diff completo, rodar verify, integrar manualmente, nunca merge automático"
   ```

2. Colar a saída no início do prompt do `Agent`, seguida da tarefa real.

3. Capturar a resposta do subagente num arquivo e validar o eco antes de
   confiar no resultado:

   ```bash
   ~/.claude/skills/delegate/scripts/echo_preamble.sh check <response-file> \
     "task-types" "exit 2" "protocolo de integração"
   ```

4. `check` falhou (exit 1) → o subagente não confirmou entendimento.
   **Não assuma que ele sabe mesmo assim.** Reforce o prompt (repita o
   preâmbulo, mais explícito) e rode de novo; se falhar de novo, trate como
   falha de delegação — resolva você mesmo ou escale, não force adiante.

## Por que markers curtos, não a skill inteira

O eco serve pra confirmar que o subagente *leu e processou* os pontos
críticos, não pra copiar `SKILL.md` de volta. Markers de 1 frase por ponto
mantêm o preâmbulo barato e o `check` (grep simples, sem LLM) determinístico.
