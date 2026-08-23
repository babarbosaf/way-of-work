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

7. **Vocabulário de IA.** `crucial`, `primordial`, `robusto`, `aprofundar`, `panorama`,
   `cenário` (abstrato), `ressaltar`, `sublinhar`, `tapeçaria`, `jornada`, `interseção`,
   `sinergia`. Usa a palavra comum.
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
    `é importante notar que` sai inteiro.
24. **Hedging empilhado.** `poderia potencialmente talvez` vira "pode".
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
