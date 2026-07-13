# Eval Runner — Guia Completo

Executar após ter o draft da skill e test cases em `evals/evals.json`.

## Step 1: Spawn all runs em um único turn

Para cada test case, spawnar dois subagents simultaneamente — um with-skill, um baseline (sem skill ou versão anterior).

**With-skill run:**
```
Execute this task:
- Skill path: <path-to-skill>
- Task: <eval prompt>
- Input files: <eval files if any, or "none">
- Save outputs to: <workspace>/iteration-<N>/eval-<ID>/with_skill/outputs/
- Outputs to save: <o que o usuário se importa>
```

**Baseline run:** mesmo prompt, sem skill path → `without_skill/outputs/`. Se melhorando skill existente: snapshot primeiro (`cp -r <skill-path> <workspace>/skill-snapshot/`), apontar baseline para snapshot.

`eval_metadata.json` para cada test case:
```json
{
  "eval_id": 0,
  "eval_name": "descriptive-name-here",
  "prompt": "The user's task prompt",
  "assertions": []
}
```

## Step 2: Draft assertions enquanto runs rodam

Não esperar — usar o tempo para rascunhar assertions objetivamente verificáveis. Atualizar `evals/evals.json` e `eval_metadata.json`. Explicar ao usuário o que ele verá no viewer.

## Step 3: Capturar timing data

Quando subagent completa, salvar em `timing.json` no run directory:
```json
{"total_tokens": 84852, "duration_ms": 23332, "total_duration_seconds": 23.3}
```
Dado vem pela notificação — não persiste depois.

## Step 4: Grade, agregar e lançar viewer

1. **Grade:** spawnar grader lendo `agents/grader.md`. Salvar em `grading.json`. Campos obrigatórios: `text`, `passed`, `evidence` (não `name`/`met`/`details`).

2. **Agregar:**
   ```bash
   python -m scripts.aggregate_benchmark <workspace>/iteration-N --skill-name <name>
   ```

3. **Análise:** ler benchmark, surfaçar padrões escondidos (assertions não-discriminantes, alta variância, tradeoffs de tokens). Ver `agents/analyzer.md`.

4. **Viewer:**
   ```bash
   nohup python <skill-creator-path>/eval-viewer/generate_review.py \
     <workspace>/iteration-N \
     --skill-name "my-skill" \
     --benchmark <workspace>/iteration-N/benchmark.json \
     > /dev/null 2>&1 &
   VIEWER_PID=$!
   ```
   Iteration 2+: adicionar `--previous-workspace <workspace>/iteration-<N-1>`.
   Headless/sem display: usar `--static <output_path>` para HTML estático.

5. Dizer ao usuário: "Abri os resultados no browser. Aba 'Outputs' para feedback qualitativo, 'Benchmark' para métricas. Quando terminar, volte aqui."

## Step 5: Ler feedback

```json
{
  "reviews": [
    {"run_id": "eval-0-with_skill", "feedback": "chart missing axis labels"},
    {"run_id": "eval-1-with_skill", "feedback": ""}
  ],
  "status": "complete"
}
```

Feedback vazio = estava ok. Focar em test cases com reclamações específicas.

```bash
kill $VIEWER_PID 2>/dev/null
```

## Loop de iteração

1. Aplicar melhorias na skill
2. Rerun em novo `iteration-<N+1>/` (com baselines)
3. Lançar viewer com `--previous-workspace`
4. Aguardar feedback
5. Repetir até: usuário satisfeito, feedback vazio, ou sem progresso

## Blind comparison (opcional)

Para comparação rigorosa entre duas versões: ler `agents/comparator.md` + `agents/analyzer.md`. Dar dois outputs a um agente independente sem revelar qual é qual.
