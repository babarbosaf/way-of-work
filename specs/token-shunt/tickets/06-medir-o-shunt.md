06 [S]  O log do delegate grava tamanho, e o threshold para de ser opinião

O que construir: `bytes_in` e `bytes_out` na linha JSONL do `delegate.log`,
como número. `bytes_in` é o prompt enviado, `bytes_out` a resposta recebida.
Vale pra toda linha de sucesso, não só pra `scan`.

Motivo: sem tamanho, não existe resposta pra "quanto o scan economizou", e o
threshold do ticket 01 se calibra por palpite. O `rtk gain` mede o compressor
local; nada mede o shunt.

files:      skills/delegate/scripts/delegate.sh
blocked_by: 04, 05
delega:     não
verify:     bash tests/delegate.test.sh

Aceite:
- [x] linha de sucesso tem `bytes_in` e `bytes_out` numéricos e maiores que zero
- [x] linha de falha não inventa número (0 ou ausente, nunca lixo)
- [x] `jq -e '.bytes_in|numbers'` passa em toda linha nova do log
