---
name: writing
description: |
  Doutrina de escrita: brevidade sem perder informação e naturalidade sem cheiro de IA. Traz o catálogo de padrões anti-slop, o molde de calibração de voz e um linter que roda no arquivo antes do commit.
  Use antes de escrever ou revisar texto que outra pessoa vai ler: README, doc de doutrina, PRD, spec, mensagem de commit, corpo de PR, e-mail, post. Use também quando o usuário reclamar que o texto ficou prolixo, genérico ou com cara de IA.
  Não invoque para: código, nome de identificador, log e mensagem de erro, que vão byte-a-byte e nunca são reescritos por estilo; nem pra resposta curta de conversa.
---

# Writing

Duas metas numa tensão. Brevidade corta o quanto se fala. Naturalidade impede que o corte
deixe o texto estéril, que é o outro jeito de soar máquina.

Fontes: [caveman](https://github.com/juliusbrussee/caveman) (brevidade),
[anti-ai-slop-writing](https://github.com/jalaalrd/anti-ai-slop-writing) e
[unslop](https://www.skills.sh/cursor/plugins/unslop) (naturalidade).

## Processo

1. Escreva, ou pegue o texto que veio pronto.
2. Rode o linter: `python3 skills/writing/scripts/check-writing.py <arquivo>`. Ele pega o
   que é mecânico, e só isso: travessão, aspa curva, filler, vocabulário de IA, frase de
   chatbot, emoji decorativo em título.
3. Passe o catálogo `references/padroes.md`. É o que regex não pega, e é a maior parte.
4. Se algum agente escreve em nome de uma pessoa, calibre pelo arquivo de voz
   **preenchido**, que vive na base de conhecimento e não aqui, com o nome
   `concept_voz_<slug>.md`. O `references/voz.md` deste diretório é o molde vazio, e ler o
   molde no lugar do preenchido calibra por inferência sem avisar ninguém.
5. Rode o self-check abaixo antes de entregar.

## Brevidade

"Make mouth smaller, not brain smaller": comprimir o quanto se fala, nunca o que se sabe.

- Fragmento vale mais que frase completa. Corta preâmbulo, hedging, filler.
- Código, comando, mensagem de erro e número vão byte-a-byte. Compressão de estilo nunca
  é compressão de informação.
- Idioma original e ortografia correta, acento incluso.

Escopo importa, e é onde a regra se contradiz se você não presta atenção. Fragmento é
pra instrução densa: AGENTS.md, checklist, bullet de doc, item de tabela. Texto que
alguém lê de ponta a ponta (README, corpo de PR, post) pede frase conectada, senão cai
em parataxe, que é justamente um dos padrões do catálogo.

Mensagem pra uma pessoa num canal é o terceiro escopo, e nenhum dos dois anteriores
descreve ela. Vale a frase conectada do texto longo, mas o fecho que pede ação pode
repetir o pedido, porque adesão ganha de economia quando alguém tem que fazer algo depois
de ler.

O plugin `caveman` é opcional e aplica a brevidade no output em runtime. Instala por
`claude plugin install` e liga por `CAVEMAN_DEFAULT_MODE`. Dado o requisito de bom
português, os níveis seguros são `lite` e `full`. O estilo em si vive aqui, não depende
do plugin.

## Naturalidade

Vale sobretudo em texto longo, onde a brevidade não protege:

- **Sem parataxe.** "Frase curta. Outra. Outra." lê como IA. Conecte mostrando a relação,
  seja causa, contraste ou ressalva.
- **Sem gangorra de hedging.** Escolha um lado e afirme. Contraponto em uma frase, nunca
  com peso igual. A dúvida que você de fato tem é exceção, porque é informação: apagar
  ela mente sobre o que se sabe. O vício é empilhar ressalva em cima do que você sabe.
- **Sem tom de pep talk corporativo.** Escreva como quem já pagou o custo, frustração
  inclusa.
- **Sem parágrafo em molde idêntico.** Varie abertura e tamanho.
- **Bullets com moderação.** Nunca mais de 5 a 7 seguidos. Se cabe em frase, vira frase.
- **Sem passiva.** "foi feito" e "é considerado" soam mortos. Nomeie quem age.
- Parágrafo pode terminar seco. Nem todo pede transição.

## Não deixe estéril

Tirar padrão é metade do trabalho. Texto sem voz denuncia máquina do mesmo jeito.

- Tenha opinião. Reaja ao fato em vez de listar prós e contras em peso igual.
- Varie o ritmo. Frase curta. Depois uma que toma o tempo dela, desenvolve a ressalva e
  fecha.
- Admita complexidade. "Impressionante e um pouco perturbador" diz mais que
  "impressionante".
- Primeira pessoa quando cabe. Não é informalidade.
- Deixe entrar alguma bagunça. Estrutura perfeita parece feita por máquina.
- Seja específico. Não "isso é preocupante", mas o que exatamente vai quebrar e quando.

## Pontuação

- Travessão: nunca, e nem o substituto. Parêntese no lugar do travessão troca um vício
  por outro. Se o pensamento precisa de pausa, use vírgula ou termine a frase.
- Dois-pontos: antes de lista ou exemplo. Não como conector no meio da frase.
- Exclamação: no máximo uma a cada mil palavras. Reticências: só interrupção real.
- Ponto-e-vírgula: use, IA subusa.
- Aspa reta, nunca curva.

## Precisão

- Nunca inventar dado, estudo, estatística ou citação. Sem número real, escreva "cerca de".
- Nome real vale mais que genérico.
- Frase que serviria igual em outro projeto não diz nada sobre este. Corta.

## Self-check antes de entregar

1. Três frases seguidas do mesmo tamanho? Varie.
2. Parataxe, três curtas em sequência? Conecte.
3. Hedging em vez de posição? Escolha o lado, e deixe a dúvida real declarada como dúvida.
4. Travessão, parêntese explicativo ou dois-pontos conector no trecho? Remova.
5. Passiva sem ator? Nomeie quem age.
6. Dado que você não mediu? Remova ou marque como hipótese.
7. Soa como resposta genérica de IA? Reescreva até não soar.

## O que vive onde

| Arquivo | Pra quê |
|---|---|
| `references/padroes.md` | Catálogo de padrões anti-slop, com o substituto de cada um. |
| `references/voz.md` | Molde de calibração de voz. Preenchido vive fora do repo. |
| `fixtures/antes-depois.md` | Pares reais deste repo, pra calibrar o que é reescrita boa. |
| `scripts/check-writing.py` | O linter. Testado por `tests/writing.test.sh`, na raiz do repo. |
