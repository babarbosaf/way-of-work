# Catálogo de padrões

O que o linter não pega. Cada item traz o tell e o substituto, porque padrão banido sem
alternativa vira paralisia.

Exemplos ruins vão em `código` de propósito: o linter ignora trecho de código, então o
catálogo não se acusa.

## Conteúdo

1. **Puffery.** `momento decisivo`, `prova do compromisso`, `cenário em evolução`,
   `deixou marca indelével`. Corta e escreve o que aconteceu.
2. **Nome jogado sem contexto.** Listar veículo ou ferramenta sem dizer o que foi dito.
   Escolhe um e cita a frase.
3. **Gerúndio superficial de fechamento.** `evidenciando...`, `garantindo...`,
   `refletindo...`, `demonstrando...`. Deleta ou expande com fonte real.
4. **Linguagem de folder.** `aconchegante`, `vibrante`, `revolucionário`, `renomado`,
   `imperdível`. Descreve neutro.
5. **Atribuição vaga.** `especialistas acreditam`, `relatórios do setor indicam`,
   `alguns críticos argumentam`. Nomeia a fonte ou apaga.
6. **Desafio formulaico.** `apesar dos desafios, segue crescendo`. Troca por fato.

## Linguagem

7. **Vocabulário de IA.** `crucial`, `primordial`, `robusto`, `panorama`,
   `cenário` (abstrato), `ressaltar`, `sublinhar`, `tapeçaria`, `jornada`, `interseção`,
   `sinergia`. Usa a palavra comum. `aprofundar` ficou fora da lista de propósito: em
   PT-BR é o verbo normal, e regra que grita em uso legítimo é regra que alguém desliga.
8. **Jeito pomposo de dizer "é".** `serve como`, `configura-se como`, `ostenta`,
   `apresenta como característica`. Diz "é" ou "tem".
9. **Construção `não apenas X, mas Y`.** Afirma direto o ponto.
10. **Regra de três forçada.** Três itens porque três soa bem. Usa o número real.
11. **Ciclo de sinônimos.** `protagonista`, `personagem central`, `figura principal` no
    mesmo parágrafo. Escolhe um e repete.
12. **Falso intervalo.** `de X a Y` onde X e Y não estão numa escala. Lista os itens.

## Estilo

13. **Travessão e substituto.** O linter pega o travessão. O que ele não pega é a troca
    por parêntese explicativo, meia-risca ou hífen fazendo papel de travessão. Se o
    pensamento precisa de pausa, vira vírgula ou frase nova.
14. **Dois-pontos como conector.** Válido antes de lista ou exemplo. No meio da frase não
    acrescenta nada. Deixa o ponto se sustentar sem a moldura de comparação.
15. **Negrito em excesso.** Não negrita todo nome próprio e toda sigla.
16. **Lista com cabeçalho inline redundante.** O tell é o rótulo em negrito que repete a
    linha: `**Performance:** a performance melhorou...`. Vira prosa. Rótulo em negrito
    que nomeia o item e é seguido de informação nova é legítimo, não é tell.
17. **Título em Caixa de Cada Palavra.** Usa caixa de frase.
18. **Emoji decorativo.** Fora de título e de bullet.
19. **Aspa curva.** Reta sempre.

## Artefato de conversa

20. **Frase de chatbot.** `Espero que ajude!`, `Fico à disposição`, `Claro!`,
    `Com certeza!`, `Achei o problema!`. Remove.
21. **Disclaimer de corte de conhecimento.** `embora os detalhes sejam limitados`. Busca a
    fonte ou remove.
22. **Tom sicofante.** `Ótima pergunta!`, `Você está absolutamente certo!`. Responde direto.

## Filler

23. **Frase de enchimento.** `a fim de` vira "pra". `devido ao fato de que` vira "porque".
    `é importante notar que` sai inteiro. `basicamente` ficou fora do linter de propósito:
    em PT-BR falado ele abre explicação técnica pra quem não acompanhou o detalhe, e nessa
    posição é sinal pro leitor, não enchimento.
24. **Hedging empilhado.** `poderia potencialmente talvez` vira "pode". Ressalva que
    corresponde a dúvida real não entra aqui, porque ela é informação, e apagar ela mente
    sobre o que se sabe. O vício é a ressalva sobre o que você sabe.
25. **Conclusão genérica.** `o futuro é promissor`. Escreve o plano ou o número.

## Jargão

26. **Metáfora abstrata virando substantivo.** `substrato`, `vetor`, `alavanca`,
    `arcabouço`, `superfície de API`, `primitivo` (como substantivo), `paradigma`,
    `catraca`, `norte`. Quase sempre existe a palavra concreta: `substrato` é "base",
    `vetor` é "caminho" ou "método", `catraca` é o nome real do mecanismo ou "limite que
    só aperta". Escolhe a concreta.

## Fala direta

27. **Diz o que faz, não como se sente.** `o banco fica sempre à mão`,
    `SQL que você consegue ler` nomeiam sensação. O conserto nomeia o mecanismo ou o
    número: "`.toSQL()` devolve a string exata enviada ao banco", "renomear coluna quebra
    o build". Pergunta o que a frase manda o leitor saber ou fazer, e escreve isso. Se não
    dá pra reescrever como instrução, fato ou número, corta.
28. **Frase densa.** Se o leitor precisa voltar pra entender, quebra em duas. Uma ideia
    por frase.
29. **Voz ativa.** Caça `é validado`, `foi processado` e nomeia o ator. Passiva só quando
    o ator é desconhecido ou não importa.
30. **Corta o advérbio ou troca o verbo.** `roda rapidamente` vira "é rápido" ou o número.
    Advérbio sustentando verbo fraco quer dizer que o verbo está errado.
31. **Palavra comum ganha.** `utilizar` vira "usar", `alavancar` vira "usar",
    `viabilizar` vira "ajudar", `no sentido de` vira "pra". O sinônimo chique raramente é
    mais claro.

## Documento de referência

Regras que saíram das revisões de um `PRD.md` em 2026-08-31, quando o dono
reescreveu à mão as seções que o agente tinha escrito. Valem pra doc que se lê pra decidir: PRD, ROUTES,
CONVENTIONS, spec.

32. **Regra fica, causo sai.** `porque falha silenciosa é o modo de morte do que roda por
    relógio`, `foi reclamação do dono na primeira entrega real`. O enunciado da regra
    basta; a narrativa do incidente vive no FEEDBACK ou na decisão que a produziu. Doc de
    referência que carrega causo vira decision log.
33. **Número medido não é doc de referência.** Placar de comparação, data de medição,
    percentual de recall: são evidência, e evidência mora na spec ou no script que a
    produziu. O doc leva a regra que o número justificou, não o número.
34. **Termo corrente ganha de apelido.** `profiles` e não "papéis"; `workflow` e não
    "laço"; `edge case` e não "borda". O apelido poético obriga o leitor a traduzir, e
    some da busca.
35. **Jargão se glosa na primeira aparição**, inline e curto: `lastro (prova de que a
    citação foi dita)`. Sigla que aparece três vezes sem definição custa uma pergunta.

36. **Antítese como forma de enunciar.** `pega invenção, não interpretação`,
    `se mede, não se opina`, `é degrau, não repetição`. O contraste obriga o leitor a
    entender dois termos e a fronteira entre eles para extrair um fato só. Escreve a
    afirmação: "a validação de citação evita alucinação". Lista de negativas continua
    valendo quando a negativa **é** o conteúdo: "não mergeia, não faz push" define a
    fronteira de um papel.
37. **Aposto encaixado entre sujeito e verbo.** `O erro mais comum e o mais caro, uma
    leitura que a fala não sustenta, passa`. Nove palavras separam sujeito do verbo, e o
    verbo chega quando o leitor já perdeu o fio. Tira o aposto para frase própria, ou
    reescreve como condição: "Caso se identifique X, faz-se Y".
38. **Tautologia de remate.** `Por isso o rascunho é rascunho`, `regra é regra`. Soa
    conclusivo e não afirma nada. Apaga, ou diz o que a frase queria dizer.

39. **A razão entra na mesma frase que a regra**, ligada por `porque`, `pois` ou dois
    pontos. `A única fonte oficial de grafia é o nome do cadastro, pois o campo de formas
    faladas mistura erro, apelido e variação`. Razão promovida a frase própria vira
    aforismo, e aforismo em sequência é o ritmo que denuncia texto de modelo.
40. **Processo se descreve na impessoal.** `O dono é definido por correspondência exata
    no cadastro`, `retendo em arquivo separado os itens fora de escopo`. Quem executa é o
    script, e nomeá-lo em toda frase (`o agente confere`, `ele retém`) transforma
    especificação em narração. A pessoa volta quando a ação é dela: `alguém aponta`.
41. **O referente de `onde` e `que` precisa ser o substantivo anterior.** `retendo em
    arquivo separado os itens fora de escopo, onde novas regras são registradas`: o
    `onde` mira o arquivo e cai nos itens. Frase nova, ou repete o substantivo.

## Anúncio de trabalho próprio

Regras que saíram da revisão de uma mensagem de canal interno em 2026-08-31, quando o dono
reescreveu à mão o anúncio que o agente tinha redigido em nome dele. Valem pra mensagem,
comentário de PR e release note em que quem escreve é também quem fez.

42. **Crédito abre, não fecha.** Trabalho que partiu do trabalho de outra pessoa nomeia
    essa pessoa na primeira frase. Crédito no penúltimo parágrafo lê como nota de rodapé, e
    troca o protagonista da mensagem sem que ninguém tenha decidido isso.
43. **Esforço não legitima entrega.** `o que virou skill foi o que doeu na mão`,
    `reconstruí o layout do zero`, `calculei a grade no terminal`. Quem lê decide pelo que a
    coisa faz e pelo compromisso que ela atende, e a narrativa do custo pede crédito por
    dificuldade. Se a entrega precisa de legitimidade, amarra na meta, no ticket ou no uso.
44. **Punchline doutrinária fechando parágrafo.** `senão é enfeite`,
    `parece atual e não é`. Sentença de efeito que resume o que a frase anterior já disse
    soa como remate de manifesto, e é o ritmo que mais denuncia modelo em texto curto.
    Parágrafo pode acabar na informação. Parente do 38, que pega a tautologia, e do 39, que
    pega a razão promovida a frase própria.
45. **Verbo modesto ganha do verbo de lançamento.** `tentei transformar em skill, e criei`
    no lugar de `subi uma skill nova`, com a coisa mergeada e rodando. Anúncio que se
    declara acima do que entregou obriga o leitor a descontar, e o desconto vira
    desconfiança na mensagem seguinte.
