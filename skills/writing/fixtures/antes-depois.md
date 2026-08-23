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
