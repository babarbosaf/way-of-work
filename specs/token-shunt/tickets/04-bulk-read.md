04 [M]  `delegate.sh` monta o prompt de leitura, e para de cobrar heredoc

O que construir: `--paths a b c` mais `--question "..."` no `delegate.sh`. Com
eles, o script monta o prompt que hoje se escreve à mão: pergunta, arquivos em
tag XML com o path no atributo, e contrato de saída em bullets sem prosa. Path
inexistente falha alto. `--paths` sem `--question` (e vice-versa) é erro de uso.
Modo heredoc continua igual, sem quebra pra chamador nenhum.

Motivo medido: `gate/delegate.log` tem 211 chamadas de `review` (que o
`peer-review.sh` dispara sozinho) contra 22 de `scan` e 3 de `boilerplate`. O
que depende de montar heredoc à mão não é chamado.

files:      skills/delegate/scripts/delegate.sh, skills/delegate/SKILL.md
blocked_by: nenhum
delega:     não
verify:     bash tests/delegate.test.sh

Aceite:
- [x] `--paths x y --question "q"` roda sem stdin e o worker recebe os dois arquivos
- [x] cada arquivo vai numa tag com o path absoluto no atributo
- [x] o prompt carrega o contrato de saída em bullets, sem prosa
- [x] `--paths` sem `--question` morre com mensagem de uso
- [x] path inexistente morre antes de invocar worker
- [x] heredoc puro (sem as flags novas) segue idêntico
