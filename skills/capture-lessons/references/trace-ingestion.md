### Lente E — Trace ingestion (de findings/)

Aplica em sessões que invocam `capture-lessons` após N specs terem fechado (sinal: ≥3 specs em `docs/specs/done/<slug>/findings/` desde último capture). Varre `docs/specs/done/*/findings/*.md` (e opcionalmente `ongoing/*/findings/*.md` pra padrões emergentes).

**Detecção de padrão:**
1. **Critério X falhou em N de M últimas specs** (N ≥ 2 e M ≤ 5) → propor uma de:
   - `[ANTI-PATTERN]` memória nova capturando a regra que o critério codifica (se a falha repetida é de execução, não de juízo)
   - `[OTIMIZAÇÃO]` no rubric default desse tipo (se o critério está mal calibrado — score 1-5 não distingue casos reais)
   - `[CRÍTICO]` passo novo na skill que produz aquele tipo de artefato (se o critério revela passo faltando em `spec-and-plan` / `test-and-debug` / `ship-review`)
2. **Rubric override per-spec repetido** (mesmo override em ≥2 specs sem ser exceção genuína) → propor `[OTIMIZAÇÃO]` no rubric default (override virou regra de facto).
3. **Verdict `teto_atingido` em ≥2 specs** com mesmo padrão → propor `[CRÍTICO]` revisão da decomposição (specs estão entrando no evaluator largas demais).
4. **Trace de `--fresh` sempre invocado** num tipo de spec → propor `[OTIMIZAÇÃO]` mover `--fresh` pra default daquele rubric (mudar threshold de invocação no `ship-review`).

**Scope dump pra cada padrão detectado:** spec_path + critério/verdict + N ocorrências + arquivos. Não interpretar — entregar pra usuário decidir destino.
