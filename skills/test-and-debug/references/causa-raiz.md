# Descida até a causa raiz

Protocolo do passo 4 da porta 2. Abrir quando o loop de sinal já existe e a
primeira hipótese não resolveu.

## Conteúdo

- A regra de parada
- Sintoma contra causa
- Localizar a camada
- git bisect com o comando do loop
- Instrumentação temporária
- Falha intermitente
- Quando parar de descer

## A regra de parada

> A causa explica **todos** os sintomas observados, e removê-la deixa o teste verde.

As duas metades importam. Causa que explica todos os sintomas mas cuja remoção
não conserta nada é coincidência. Correção que deixa verde sem explicar os
sintomas é remendo, e ele volta com outra roupa em três semanas.

Causa que explica 18 de 20 falhas não é a causa. As duas que sobram são o
diagnóstico de verdade, e ignorá-las é a forma mais comum de fechar um bug duas
vezes.

## Sintoma contra causa

| Sintoma | Causa |
|---|---|
| deduplicar no resultado | a query junta duas vezes |
| 18 testes falhando na regra de acento | a saída do console não é UTF-8 |
| `SyntaxError` no Python | o symlink virou arquivo de texto no clone |
| suíte verde aqui e 0 de 36 no CI | o teste lê arquivo fora do repo |
| adicionar `sleep` faz passar | a ordem de inicialização não é garantida |
| tentar de novo funciona | o primeiro run deixou estado |

O padrão: quando a correção proposta é no lugar onde o erro **apareceu**, quase
sempre é sintoma. Causa mora onde o dado foi produzido, não onde ele foi lido.

## Localizar a camada

Ordem de busca, da mais barata pra mais cara:

1. testes que já existem, inclusive os verdes. Um verde que deveria estar
   vermelho é a pista mais rápida que existe;
2. a fronteira mais próxima da entrada: parsing, validação, desserialização;
3. a lógica no meio;
4. a integração com terceiro.

A maioria dos bugs que parecem de lógica é de fronteira: alguma coisa entrou com
formato diferente do que a assinatura promete.

## git bisect com o comando do loop

Quando a pergunta é "isso funcionava antes", o bisect responde em tempo
logarítmico e sem opinião:

```bash
git bisect start
git bisect bad                 # commit atual
git bisect good <sha-conhecido-bom>
git bisect run bash -c '<comando-do-loop>'
git bisect reset
```

O `run` exige que o comando do loop devolva 0 para bom e diferente de 0 para
ruim. Se o loop ainda não existe, o bisect não roda: por isso o passo 0 vem
antes.

Cuidado com o intervalo: um `good` que na verdade já estava ruim manda o bisect
para a metade errada da história, e o resultado parece convincente.

## Instrumentação temporária

Prefixo fixo, para poder varrer depois:

```
[DEBUG-<slug>] <o que se mede> = <valor>
```

Medir valor e tipo, não só valor: metade dos bugs de fronteira é tipo trocado que
a linguagem converte em silêncio. Antes de fechar, `grep -rn "DEBUG-" .` e
remover tudo.

Instrumentação que valeu a pena não vira comentário: vira assert no teste de
regressão.

## Falha intermitente

Ordem, e nenhum passo pula o anterior:

1. **subir a taxa de repro acima de 50%.** Rodar em laço, com carga, com a seed
   fixada, com o paralelismo no máximo. Enquanto repro for 5%, toda validação de
   correção é ruído;
2. só então formular hipótese;
3. validar a correção pelo mesmo laço que reproduzia, não por um run único.

Suspeitos, em ordem de frequência: estado compartilhado entre testes, ordem de
execução, relógio, e rede.

Teste intermitente que ninguém conserta vira teste que todo mundo ignora, e aí a
suíte inteira perde o valor de gate. Ele é bug de prioridade alta, não ruído de
fundo.

## Quando parar de descer

A descida termina quando a causa satisfaz a regra de parada. Ela também termina,
sem vergonha nenhuma, quando:

- a causa está em código de terceiro e existe contorno documentado. Registrar a
  versão exata e o comportamento medido, e o contorno vira regra no
  `CONVENTIONS.md` do projeto;
- o custo de descer mais um nível passa do custo do bug, e o dono decidiu. A
  decisão fica escrita, com o que se sabe e o que não se sabe.

O que não encerra a descida: o teste ficou verde. Verde com a causa desconhecida
é o mesmo bug esperando outra entrada.
