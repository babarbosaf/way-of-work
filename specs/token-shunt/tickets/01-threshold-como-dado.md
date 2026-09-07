01 [S] [P]  Threshold de leitura sai do hook e vira dado da policy, com dois degraus

O que construir: os hooks param de carregar `LIMIT = 200` hardcoded e leem
`.shunt` da `model-policy.json`, com override por env. Dois degraus, porque o
repo tem dois tiers de custo de latência diferente (grep local em ms, worker em
10-30s): abaixo de `grep_max` resolve inline; entre `grep_max` e `worker_min`
grep mais Read paginado; acima de `worker_min` vai pro worker, onde a latência
já se paga. Policy ausente ou inválida cai em default embutido e NUNCA quebra a
sessão.

files:      config/model-policy.json, hooks/shunt_policy.py
blocked_by: nenhum
delega:     não
verify:     bash tests/hooks.test.sh && jq -e .shunt config/model-policy.json

Aceite:
- [x] `.shunt.grep_max` e `.shunt.worker_min` existem na policy e passam no `jq`
- [x] `shunt_policy.load()` devolve os valores da policy
- [x] `SHUNT_MIN_LINES` e `SHUNT_GREP_MAX` sobrescrevem a policy
- [x] policy corrompida devolve os defaults, sem exceção propagada
- [x] `read_size_guard` usa o helper, e nenhum número mágico sobra no hook
