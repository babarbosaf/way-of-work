# PRD: x

## 1. Busca

`no ar`

### Propósito

A busca devolve dez resultados.

### Fluxo

Quem busca digita o termo e recebe a lista.

### Regras

| Quando | O produto garante |
|---|---|
| o termo não casa com nada | a lista sai vazia com o termo repetido, e não um erro |
| o critério de ordenação | `a definir`, e quem decide é o dono do catálogo |

## 2. Exportação

`parcialmente no ar`

### Propósito

Tirar a lista de resultados para fora do produto.

### Fluxo

Quem busca pede a exportação e recebe o arquivo.

### Regras

| Quando | O produto garante |
|---|---|
| a exportação sai em CSV | separador vírgula, cabeçalho na primeira linha |
| a exportação sai em planilha | `em aberto`, e quem decide é o dono do catálogo |
