# PRD: Prateleira

> **Papel deste doc.** O que o produto faz, funcionalidade por funcionalidade. Regra de
> construção no `CONVENTIONS.md`, telas no `DESIGN.md`. Tags: `no ar` funciona como
> descrito; `parcialmente no ar`, a primeira linha diz a parte que funciona; `previsto`
> está decidido e não construído; `em aberto` nem foi decidido, e nomeia quem decide.
>
> **As seções são o ciclo do comprador, na ordem em que ele o percorre**, e depois os
> mecanismos que todas as fases usam.

## 1. Visão geral

Uma extensão de Chrome que trabalha dentro do portal do distribuidor, para o comprador de
uma rede de lojas que precisa reservar lote de mercadoria em vários fornecedores no mesmo
dia. Quem usa é o comprador, uma pessoa por vez, com o login dela.

O produto existe porque a conta no portal do distribuidor é **individual**: não há conta
da rede, e cada comprador entra com o próprio usuário. Isso decide a arquitetura inteira.
Nada roda num servidor, nada guarda credencial, e a extensão só age dentro da sessão que
a pessoa já abriu.

- **Ler é automático, reservar é humano.** A consulta de disponibilidade roda numa fila
  sem vigilância. A reserva compromete dinheiro da rede e sempre espera uma pessoa.
- **O que o portal diz é a verdade.** A extensão reconcilia a própria soma contra o total
  que o portal informa, e para quando eles divergem.
- **Uma loja por vez, na ordem que o comprador definiu.** A fila é ordenada por ele, e não
  por prioridade que o produto inventou.

```
COMPRADOR ──prepara a fila (§2)──▶ FILA DE LOJAS                          `no ar`
                                     │
                                     ▼
                                  CONSULTA (§3) ──lê o painel do portal──▶ DISPONIBILIDADE
                                     │                                        `no ar`
                                     │ reconcilia contra o total do portal
                                     ▼
                                  MOTOR (§4) ──roda a fila sem vigilância──▶ PLANILHA
                                     │                                        `no ar`
                                     ├──confere o que voltou (§5)──▶ CONFERÊNCIA  `previsto`
                                     ▼
                                  RESERVA (§6) ──espera uma pessoa──▶ COMPROMISSO  `previsto`
```

## 2. Preparo

`no ar`

### Propósito

Deixar o comprador pronto para rodar sem que ele precise repetir nada: a fila fica
montada, e a credencial nunca sai do navegador dele.

### Fluxo

O comprador instala a extensão descompactada, abre o painel e cadastra a rede. Depois
cola a lista de lojas, uma por linha, e amarra cada loja ao código que o distribuidor usa
para ela. A extensão guarda esse vínculo, e ele é o que permite consultar sem ninguém
redigitar código a cada rodada.

A credencial não é cadastrada em lugar nenhum. O comprador entra no portal do
distribuidor pelo navegador, como sempre fez, e a extensão trabalha dentro da sessão que
ele abriu.

Por último ele ordena a fila arrastando as lojas. A ordem é dele, e persiste entre
sessões.

### Regras

| Quando | O produto garante |
|---|---|
| a extensão precisa acessar o portal | ela usa a sessão que a pessoa abriu, e nunca pede, guarda ou transmite usuário e senha |
| o comprador cola a lista de lojas | uma loja por linha, e linha que não casa com nenhum código do distribuidor entra marcada como pendente, em vez de ser descartada em silêncio |
| uma loja não tem código amarrado | ela não entra na fila, e o painel diz qual falta |
| o comprador fecha o navegador | a fila e os vínculos persistem; só a sessão do portal morre |
| a rede ainda não foi cadastrada | o painel abre no cadastro, e não numa fila vazia sem explicação |

## 3. Consulta

`no ar`

### Propósito

Trazer a disponibilidade real de um lote sem que o comprador leia o painel do
distribuidor com o olho, que é onde o erro de digitação nasce.

### Fluxo

Com o portal aberto numa loja, o comprador dispara a consulta. A extensão lê o painel de
disponibilidade da página, extrai os lotes por categoria e monta a linha daquela loja.

Antes de devolver qualquer número, ela soma o que extraiu e compara com o total que o
próprio painel exibe. Bateu, a linha vale. Não bateu, ela não devolve número nenhum: para
e diz que a leitura não fecha.

O resultado sai pronto para colar numa planilha, separado por tabulação, com as
categorias sempre na mesma ordem.

### Regras

| Quando | O produto garante |
|---|---|
| a soma das categorias diverge do total do painel | recusa a leitura com a diferença nomeada, e não devolve número parcial; número errado numa planilha de compra não tem como ser percebido depois |
| o painel serve uma categoria que o produto não conhece | ela aparece na saída com o nome que o portal deu, nunca agregada num "outros" |
| a página ainda está carregando | a consulta espera o painel, e não lê meia tabela |
| o comprador dispara a consulta fora do portal | recusa dizendo em que página ela funciona |
| a saída é copiada | vai separada por tabulação, com as categorias em ordem fixa, para colar em planilha sem reordenar coluna |
| o portal muda a marcação da página | a extração para de encontrar o painel e falha nomeando isso; ela nunca adivinha um seletor parecido |

## 4. Motor de fila

`no ar`

### Propósito

Rodar a fila inteira sem vigilância, e deixar rastro suficiente para que quem voltou do
café saiba o que aconteceu enquanto não estava olhando.

### Fluxo

O comprador manda rodar. O motor percorre a fila na ordem dele, uma loja por vez: navega
até a loja no portal, espera o painel, consulta, guarda a linha, e vai para a próxima.

O painel mostra o progresso enquanto isso, com a loja corrente e o que já saiu. Ao fim, o
comprador tem a planilha inteira e um resumo do que falhou.

Se a sessão do portal cair no meio, o motor para na loja em que estava. Ele não tenta
reautenticar, porque reautenticar exigiria a credencial que ele deliberadamente não tem.

### Regras

| Quando | O produto garante |
|---|---|
| a sessão do portal expira no meio da fila | o motor para na loja corrente, diz qual foi, e retoma dali depois que a pessoa entrar de novo |
| uma loja falha | a fila continua nas demais, e a loja falha entra no resumo com o motivo |
| o comprador fecha a aba durante a rodada | o que já saiu está guardado, e a rodada retoma da loja seguinte |
| a rodada termina | o resumo diz quantas lojas passaram, quantas falharam e por quê, e esse resumo sobrevive ao fechamento do painel |
| o portal responde devagar | o motor espera o painel por loja, com prazo próprio, em vez de contar tempo fixo |
| duas rodadas são disparadas ao mesmo tempo | a segunda recusa, porque duas rodadas na mesma sessão embaralham a navegação do portal |

## 5. Conferência

`previsto`

### Propósito

Deixar o comprador comparar o que ele pediu com o que o portal devolveu, antes de a
planilha virar decisão de compra.

### Fluxo

Terminada a rodada, o comprador abre a conferência. Ela mostra, lado a lado, a lista de
lojas que ele montou e o que voltou de cada uma, marcando o que está faltando e o que
veio diferente do esperado.

Nada aqui escreve no portal: a conferência só lê o que a rodada guardou.

### Regras

| Quando | O produto garante |
|---|---|
| uma loja da fila não tem linha de resultado | aparece marcada como faltando, com o motivo da rodada |
| a mesma loja foi consultada duas vezes | mostra a leitura mais recente, com a hora, e não as duas somadas |
| o comprador exporta da conferência | sai o mesmo formato da consulta, para que a planilha não mude de forma entre as duas telas |

## 6. Reserva

`previsto`

### Propósito

Transformar a consulta em compromisso de compra, que é a única coisa que o produto faz
que custa dinheiro, e por isso a única que nunca acontece sozinha.

### Fluxo

Reservar lote no portal é escrita: muda o estado da conta do comprador e compromete
mercadoria. O comprador seleciona o que quer reservar e a extensão monta o lote.

Antes de qualquer envio, ela mostra um antes e depois: o que está reservado hoje, o que
ficará reservado, e a diferença. A pessoa confirma esse lote, e só então a extensão
escreve.

Cada lote é confirmado separadamente. Confirmar um não autoriza o seguinte.

### Regras

| Quando | O produto garante |
|---|---|
| a extensão vai escrever no portal | espera confirmação explícita de uma pessoa, depois de exibir o antes e depois daquele lote |
| a rodada sem vigilância encontra algo reservável | não reserva: o motor de fila só lê, e o caminho de escrita nunca roda dentro dele |
| a pessoa confirma um lote | a autorização vale para aquele lote, e o próximo pede confirmação de novo |
| a escrita falha no meio de um lote | o painel diz o que foi e o que não foi escrito, item a item, porque "falhou" sem detalhe obriga a conferir tudo à mão no portal |
| o comprador cancela no preview | nada é enviado, e o estado no portal fica como estava |
| o produto escolhe sozinho quais lotes entram | `a definir`, e quem decide é o comprador-chefe da rede: antes disso é preciso responder se o critério vale para a rede inteira, para cada loja ou para cada categoria, e a resposta muda a tela e o armazenamento |
