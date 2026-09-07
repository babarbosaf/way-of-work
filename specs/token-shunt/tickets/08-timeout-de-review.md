08 [S]  O timeout de review sai do script e volta pra policy

O que construir: `peer-review.sh` para de passar `--timeout 120` e deixa o
`.timeouts.review` da policy mandar. O valor da policy sobe pra 300, com margem
sobre o tempo medido.

Motivo medido: revisão adversarial de um diff de 1432 linhas no Gemini 3.1 Pro
(High) leva **170s**, e o script cravava 120. Estourado o timeout, a cascata se
esgota, o `peer-review` sai com exit 2 e a sessão come a review inline: o
fallback mais caro do sistema. No `gate/delegate.log`, 90 de 212 chamadas de
`review` terminaram em `unavailable`, 42%.

É o mesmo defeito do ticket 01 em outro arquivo: número de operação cravado em
código em vez de dado na policy.

files:      scripts/peer-review.sh, config/model-policy.json, tests/peer-review.test.sh
blocked_by: nenhum
delega:     não
verify:     bash tests/peer-review.test.sh

Aceite:
- [x] `peer-review.sh` não passa `--timeout` na chamada do delegate
- [x] `.timeouts.review` cobre o tempo medido com margem
- [x] assert impede a volta do número cravado
