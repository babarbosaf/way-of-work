# Pares antes e depois

Reescritas reais deste repo. O lado "antes" vai em bloco de código porque o linter ignora
código, então o arquivo de fixture passa no próprio linter.

Serve pra calibrar o que é reescrita boa: o depois tem que ficar mais curto ou igual, e
nunca perder informação. Se perdeu, não é reescrita, é corte.

## 1. Travessão que era vírgula

Padrão 13. O erro comum aqui é trocar por parêntese, o que só troca um vício por outro.

```
antes: O estilo em si vive nos docs — não depende do plugin.
```

depois: O estilo em si vive nos docs, não depende do plugin.

## 2. Travessão no título

Padrão 13. Título com travessão quase sempre carrega metade redundante. A contagem cabe
no corpo, não no título.

```
antes: ## Modelo de trabalho — 3 modos
```

depois: `## Modelo de trabalho`

## 3. Dois-pontos conector

Padrão 14. O que vinha depois dos dois-pontos já era a frase inteira.

```
antes: Escopo importa: fragmento é pra instrução densa, e texto longo pede frase conectada.
```

depois: Escopo importa, e é onde a regra se contradiz se você não presta atenção.
Fragmento é pra instrução densa. Texto longo pede frase conectada.

## 4. Diz o que faz, não como se sente

Padrão 27. O antes é elogio ao próprio doc, e serviria igual em qualquer repo.

```
antes: A mensagem de bloqueio ensina na hora, tornando o enforcement uma experiência
       pedagógica em vez de um obstáculo.
```

depois: A mensagem de bloqueio diz qual comando rodar no lugar.

## 5. Parataxe

Padrão da seção Naturalidade. Três frases curtas seguidas leem como máquina, mesmo estando
cada uma correta.

```
antes: Fragmento vale mais. Corta preâmbulo. Corta hedging. Corta filler.
```

depois: Fragmento vale mais que frase completa, então corta preâmbulo, hedging e filler.

## 6. Passiva sem ator

Padrão 29. A passiva esconde quem faz, e quem lê precisa saber onde mexer.

```
antes: As queries são validadas antes do deploy.
```

depois: O hook de pre-commit valida as queries antes do deploy.

## 6. Justificativa colada na regra

Padrão 32. O corte não perde informação: a regra é a mesma, e o porquê já vive na decisão.

```
antes: **A resposta é sempre a mesma frase**, e isso é requisito, não gentileza: frase
diferente para quem já tem conta transforma o formulário em oráculo de quem é cliente.
```

depois: Resposta para quem já tem conta: idêntica à de quem não tem.

## 7. Retórica antes da regra

Padrão 34. Três frases de moldura antes de dizer a única coisa que importa.

```
antes: **Link no e-mail, e nada mais.** Sem senha, sem SSO, sem código digitado. A
consequência é dura e assumida: se o e-mail não chega, ninguém entra.
```

depois: A única forma de login é via magic link.

## 8. Estado atual em doc de estado ideal

Padrão 38. O ponteiro pro código foi pro doc de gaps, e a linha aqui virou a promessa.

```
antes: A gestão vive em `/settings#members`, hoje um placeholder honesto com o gatilho
declarado na própria tela (`Configuracoes.tsx:88`).
```

depois: A gestão vive em `/settings#members`, e a tela lista quem está dentro, com papel e
estado, mais os convites pendentes.

## 9. Prosa defendendo o que a tabela já afirma

Padrões 39 e 33. A tabela logo abaixo tem a linha `Capa | o nome do relatório sobrevive à
impressão`, e o fecho só a dramatizava.

```
antes: A única saída da v0 é o PDF, e ele é o que está na tela: os cards como estão, com
os filtros aplicados naquele momento, e a capa com o nome do relatório. A folha impressa
precisa dizer de quem é e de qual relatório saiu, ou ela chega na reunião anônima.
```

depois: A única saída da v0 é o PDF. Ele funciona como um print da tela: os cards como
estão, com os filtros aplicados naquele momento, e a capa com o nome do relatório.
