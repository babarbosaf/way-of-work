05 [S]  Boilerplate sem arquivo de referência não sai

O que construir: `--reference <file>` injeta o arquivo como padrão a seguir, em
tag própria. Em `--task boilerplate` no modo novo (`--question`), `--reference`
é obrigatório: sem ele, erro de uso antes de invocar worker. Modo heredoc não
muda, pra não quebrar `delega: boilerplate` de spec já escrita.

Motivo: é a lição direta do `code-write` do Portal. Sem referência o worker gera
código sem contexto, que não encaixa em nada, e o custo de revisar passa o de
escrever à mão.

files:      skills/delegate/scripts/delegate.sh
blocked_by: 04
delega:     não
verify:     bash tests/delegate.test.sh

Aceite:
- [x] `--task boilerplate --question q` sem `--reference` morre com uso
- [x] com `--reference`, o conteúdo do arquivo chega ao worker em tag própria
- [x] `--reference` inexistente morre antes de invocar worker
- [x] `--task scan --question q` sem `--reference` continua válido
- [x] `--task boilerplate` por heredoc continua válido
