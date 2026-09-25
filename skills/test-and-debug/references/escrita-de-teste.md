# Ofício de escrever teste

O que vale em qualquer projeto, em qualquer linguagem. O dialeto (framework, onde
o arquivo mora, comando de rodar, corte de cobertura, qual é a fronteira de mock
aqui) fica no `CONVENTIONS.md` do projeto, que é padrão e não tutorial.

## Conteúdo

- O nome diz o comportamento
- Um conceito por teste
- O valor esperado vem de fora
- Fronteira de mock
- Hermeticidade
- Fixture no lugar de setup repetido
- Nível do teste
- Antipadrões

## O nome diz o comportamento

`test_<o_que_faz>_quando_<condição>`. Quem lê a saída vermelha entende o contrato
sem abrir o arquivo.

| Ruim | Bom |
|---|---|
| `test_parse` | `test_parse_rejeita_linha_sem_separador` |
| `test_media_2` | `test_media_de_lote_vazio_devolve_zero` |
| `test_bug_412` | `test_dois_clientes_nao_compartilham_fila` |

Nome que cita número de ticket morre junto com o tracker. O comportamento não.

## Um conceito por teste

Um teste que assere cinco coisas falha na primeira e esconde as outras quatro.
Vários asserts sobre o **mesmo** conceito (os três campos do objeto devolvido)
são um conceito só e ficam juntos.

O crivo: quando este teste ficar vermelho, a mensagem diz sozinha o que quebrou?

## O valor esperado vem de fora

O valor esperado é escrito à mão, ou vem de uma fonte independente do produto.
Calcular o esperado com o código do produto produz um teste que concorda consigo
mesmo:

```python
# tautológico: se a função errar, o esperado erra junto
assert formatar(x) == formatar(x)
assert total(itens) == sum(i.preco for i in itens)   # reimplementa a função

# honesto: o número foi calculado fora
assert total(itens) == 47.50
```

## Fronteira de mock

Mockar **a fronteira do sistema**, nunca o que está sob teste. Fronteira é rede,
relógio, sistema de arquivos, aleatoriedade, e serviço de terceiro. Tudo dentro
disso roda de verdade.

Teste que mocka o módulo que ele deveria estar testando passa sempre, inclusive
depois de alguém apagar o módulo.

Quando o mock devolve exatamente a resposta que o teste quer ver, ele não está
testando o produto: está testando o mock. A pergunta 3 do gate de nascimento
existe por isso.

## Hermeticidade

Um teste roda igual em qualquer máquina, em qualquer ordem, sem rede, e duas
vezes seguidas com o mesmo resultado.

- nada de ler `~/`, nem arquivo fora do repo. Entrada de teste mora em
  `fixtures/`, versionada;
- o que precisa vir de fora entra por variável de ambiente, com a fixture do repo
  como padrão;
- nada de depender de ordem: cada teste monta e desmonta o que usa;
- nada de deixar rastro: arquivo temporário morre no fim, inclusive quando o
  teste falha.

Teste verde por acidente na máquina de quem escreveu é pior que teste ausente,
porque ele compra confiança que não existe.

## Fixture no lugar de setup repetido

Na terceira repetição do mesmo setup, extrair. Antes disso, duplicar e seguir: a
fixture extraída cedo demais vira parâmetro em cima de parâmetro, e aí ninguém
entende mais o que cada teste está exercitando.

Fixture com nome que diz o cenário (`lote_com_dois_clientes`) vale mais que
fixture com nome que diz o tipo (`dados`).

## Nível do teste

O teste mora no **nível mais alto que ainda falha pelo motivo certo** e roda
rápido o bastante pro loop de sinal.

| Nível | Quando é o certo |
|---|---|
| ponta a ponta | o modo de falha atravessa peças, e o nível de baixo não o vê |
| integração | o modo de falha é o contrato entre duas peças |
| unidade | o modo de falha é uma regra dentro de uma peça, e o nível de cima não consegue nomear qual |

Descer de nível é o que se faz quando o de cima falha por motivo vago. Começar
embaixo por hábito produz suíte grande que não pega bug de verdade.

## Antipadrões

| Antipadrão | Por que fica verde com o código errado |
|---|---|
| assere implementação (chamou tal método, na tal ordem) | refatorar quebra o teste sem quebrar o comportamento |
| espera fixa (`sleep(100)`) no lugar de condição | passa na máquina rápida, falha na lenta, e esconde a corrida |
| `try/except` engolindo a falha dentro do teste | o teste passa quando o produto explode |
| assert sobre o mock | o produto pode nem ser chamado |
| snapshot aceito sem alguém ler | grava o bug como esperado |
| teste marcado para pular sem justificativa escrita | some da vista e ninguém volta |
| esperado calculado com o código do produto | concorda consigo mesmo |
