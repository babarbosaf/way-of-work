# Tickets: shunt de tokens

Desenho e medição: `docs/research/token-shunt.md`. Não há spec própria: a pesquisa
já carrega o desenho, e a leva cabe numa sessão.

Ordem de execução é a numérica. `blocked_by` só marca dependência real (mesmo
arquivo ou contrato consumido).

| # | tamanho | o que |
|---|---|---|
| 01 | S | threshold como dado, dois degraus |
| 02 | M | `bash_read_guard`, fecha o buraco do `cat` |
| 03 | S | bloqueio que roteia, nos dois guards |
| 04 | M | `--paths`/`--question`, o bulk-read |
| 05 | S | `--reference`, e obrigatório no boilerplate |
| 06 | S | `bytes_in`/`bytes_out` no log |
| 07 | S | subtrair o rewrite de `cat` do rtk |
