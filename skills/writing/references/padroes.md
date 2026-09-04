# Catálogo de padrões

O que o linter não pega. Cada item traz o tell e o substituto, porque padrão banido sem
alternativa vira paralisia.

Exemplos ruins vão em `código` de propósito: o linter ignora trecho de código, então o
catálogo não se acusa.

## Índice

- Conteúdo (1-6)
- Linguagem (7-12)
- Estilo (13-19)
- Artefato de conversa (20-22)
- Filler (23-25)
- Jargão (26)
- Fala direta (27-31)
- Documento normativo (32-42)

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

## Documento normativo (PRD, spec, guideline)

Padrões que só aparecem em doc que manda alguém fazer alguma coisa. Todos saíram de uma
revisão do dono num sub-doc de PRD (BIP, 04/set/2026), em que o corte tirou 40% das
linhas e o doc ficou mais completo.

32. **Justificativa colada na regra.** O tell é a cauda que defende o que a frase acabou
    de afirmar: `e isso é requisito, não gentileza`, `de propósito`, `a consequência é
    dura e assumida`, `não é conveniência`. A regra basta. O porquê vive na decisão que a
    produziu (ADR, DDR, seção de decisões), e repetido no normativo ele só engorda.
33. **Aforismo no lugar do fato.** `endereço escolhido à mão produz nome-2, nome-final e
    arrependimento`. Fecha bonito, não é verificável, e não muda o que ninguém faz.
    Escreve a regra e o número.
34. **Negrito de abertura como retórica.** `**Um ato só.**`,
    `**Três papéis, e a distância entre eles é pequena.**` Rótulo em negrito que anuncia
    tom em vez de nomear o item. Diferente do padrão 16: lá o rótulo repete a linha, aqui
    ele encena. Começa pela regra.
35. **Pergunta aberta empilhada no fim da seção.** Bloco de "pontos a definir" com cinco
    perguntas sem dono nem prazo apodrece, e some da vista. Decide o que dá pra decidir,
    e o que sobra vira `a definir` na célula exata da tabela, onde quem for implementar
    esbarra.
36. **Restrição pendurada na cauda.** O tell é a informação principal chegar depois da
    vírgula, como aposto: `O workspace nasce pelo convite de fundação, e é o único
    caminho`. A cauda carrega a regra inteira, e a oração principal só ocupa espaço.
    Quando a cauda é o que importa, ela vira o sujeito: `O único caminho para o workspace
    nascer é o convite de fundação`. Vale pra toda variante do rabo: `, e é obrigatório`,
    `, e não tem exceção`, `, e só ele`. Teste: cobre a cauda com o dedo. Se o que sobra
    não é a regra, a frase está montada de trás pra frente.
37. **Data, código de spec e número de decisão em frase normativa.** `(decisão de
    04/set/2026, spec 2026-011 D-11)`, `revisto em 04/set`, `DDR-0013` no meio de uma
    regra. Ou a regra vale agora, e a data não muda nada, ou ela não vale, e a frase não
    deveria estar lá. Rastreabilidade vive no git, na spec e no ADR. A exceção é a seção
    cujo assunto **é** o histórico (decisões registradas, changelog), onde a data é o
    conteúdo.
38. **Estado atual dentro de doc de estado ideal.** `file.tsx:88`, nome de função,
    `hoje é um placeholder`, num doc cujo cabeçalho promete descrever o alvo. Ponteiro pro
    código pertence ao doc de gaps ou ao de convenções. Doc que mistura os dois envelhece
    a cada commit.

39. **Prosa que repete a tabela vizinha.** Em doc que mistura prosa e tabela, a frase que
    abre ou fecha a tabela reafirmando uma célula dela. `Dois objetos, e o segundo só
    existe dentro do primeiro`, logo acima de uma tabela cuja coluna já diz `sem teto
    dentro do relatório`. A tabela é a parte normativa, e a prosa em volta existe pra
    dizer o que não cabe em célula. Teste: apaga a frase; se nenhuma informação sumiu da
    tabela, ela não era necessária.
40. **Negativa que reafirma o positivo.** `um número inteiro deles, nunca uma fração`,
    `obrigatório, e não opcional`, `só o admin, mais ninguém`. A segunda metade traduz a
    primeira ao contrário e não acrescenta caso nenhum. A negativa merece o lugar quando
    exclui algo que o leitor colocaria ali por conta própria, como `o dia é o do fuso do
    cliente, nunca o do servidor`.
41. **Regra reafirmada fora da seção dona dela.** `quem criou não ganha poder nenhum
    sobre o que criou`, escrito na seção de filtros, quando a seção de modelo já
    estabeleceu que o relatório não tem dono. Cada regra tem uma seção dona, e ecoá-la
    adiante faz o leitor procurar a diferença que não existe entre as duas formulações.
    Aponta a seção, ou confia nela.

42. **Frase de efeito no lugar da frase simples.** A antítese que fecha bonito:
    `prompt_version é auditoria, não chave de cache`, `o gargalo é a latência, não o
    dinheiro`, `o que ele afirma é determinístico, e o que ele gera é a conversa`,
    `decisão humana não é desfeita por máquina`. Diferente do padrão 40, onde a
    segunda metade só traduz a primeira ao contrário: aqui as duas metades dizem
    coisas diferentes, e ainda assim a forma pesa mais que o conteúdo, porque o
    leitor precisa desmontar a figura pra achar a instrução. Escreve o que a coisa
    faz: `o prompt_version serve para auditar; nada o consulta para decidir
    reprocessar`. Teste: se a frase caberia num slide de abertura, ela não é uma
    regra ainda.
