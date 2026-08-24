# Método de entrevista

Este é o motor da skill. A profundidade dos quatro documentos não sai do nada: ela é
extraída do dono do projeto por perguntas dirigidas. Conduzir a entrevista ANTES de
escrever qualquer documento.

A entrevista alimenta principalmente o PRD. As rotas e o design se derivam do PRD depois, com
entrevistas curtas e complementares (ver `anatomia-rotas.md` e `anatomia-design.md`), e o
CONVENTIONS.md consolida a camada técnica levantada aqui (ver `anatomia-conventions.md`).

## Princípios de condução

- **Um bloco de tema por mensagem.** No máximo 1 a 3 perguntas por vez. Nunca despejar
  a lista inteira de uma vez: isso trava o interlocutor e produz respostas rasas.
- **Conceitual antes de mecânico.** Primeiro entender o "por que" e o "como funciona na
  cabeça do usuário", depois cavar os números.
- **Forçar especificidade.** Toda resposta vaga ("tem uma pontuação", "atualiza de vez em
  quando") merece uma repergunta pedindo o número, a tabela, a cadência exata. Um PRD do
  nível-alvo tem tabelas de pontos, janelas de tempo com horário, limites numéricos.
- **Sempre sondar quatro coisas por feature:** as regras exatas, os edge cases, o que
  ainda não foi decidido, e o racional das escolhas. São essas quatro que separam um PRD
  de verdade de uma lista de features.
- **Devolver o que foi capturado.** Ao fechar um bloco, resumir em uma ou duas linhas o
  que ficou entendido antes de avançar. Isso corrige mal-entendidos cedo.
- **Persistir o que foi capturado.** Depois do mini-resumo de cada bloco, gravar o bloco
  em `_tmp/notas-entrevista.md` (diretório gitignored de trabalho). A entrevista sobrevive a quedas de sessão
  pelo arquivo, e o PRD se redige a partir dele, não da memória.
- **Usar opções tocáveis** (botões) quando a pergunta for um ou/ou genuíno. Texto aberto
  quando a resposta exige nuance.
- **Adaptar.** As fases abaixo são um checklist de dimensões a cobrir, não um script rígido.
  Nem todo produto tem álbum, tela ao vivo ou múltiplos idiomas. Pular o que não se aplica,
  mas nunca pular: pilares, restrições invioláveis, regras+edge cases+pontos em aberto por
  feature, fluxo de dados, e o registro de decisões.

## Fase 0, Enquadramento

Objetivo: preencher a Visão Geral e travar as premissas de plataforma e stack.

- O que é o produto em uma frase? Para quem é? Qual o objetivo primário (lúdico, receita,
  retenção, aquisição)?
- Plataforma: web, PWA mobile, app nativo, desktop?
- Stack: manter o default declarado (ver `stack-default.md`) ou trocar? Se trocar, capturar
  a stack nova, porque ela muda as seções transversais do PRD e o CONVENTIONS.md.
- Convenções de construção: além da stack, o que o dono já pratica? Estrutura de pastas,
  nomenclatura, padrões de teste, padrões de erro, regras obrigatórias ("sem mocks",
  "regra de negócio nunca em SQL"). Esse material alimenta o CONVENTIONS.md.
- Estratégia: a visão/direção do negócio merece documento próprio? Se sim, gerar um
  `STRATEGY.md` curto antes do PRD (opt-in, não default); se não, o racional estratégico
  vive na seção de decisões do PRD.
- Modelo de acesso e identidade: cadastro aberto, só convite, login social? Há papéis
  diferentes (usuário comum, admin)?
- Restrições invioláveis: existem restrições, regras, requisitos ou limitações que não
  podem ser quebrados ou ultrapassados (técnicas, legais, de negócio, de prazo, de
  orçamento, de compliance)? Registrar cada uma textualmente: elas ganham seção própria
  no PRD e são ecoadas no AGENTS.md.
- Design system existente: já existe um design system criado, ou uma fundação de design
  já existente para herdar (design system de umbrella, kit de componentes, DESIGN.md de outro
  produto)? Se sim, pedir que o usuário aponte o arquivo. Ele vira a base do DESIGN.md e nenhuma informação dele pode ser
  perdida (ver `anatomia-design.md`).

## Fase 1, Pilares

Objetivo: identificar os 2 a 4 motores principais de engajamento. Eles viram a espinha da
Visão Geral e definem quais features ganham deep-dive.

- Quais são os 2 a 4 pilares que sustentam o produto? (No Chutaí: palpites, grupos com liga,
  álbum de figurinhas.)
- Qual a relação entre eles? Um alimenta o outro? São independentes?

## Fase 2, Deep-dive por feature (loop)

Objetivo: para cada pilar (e cada feature relevante), produzir uma seção de PRD completa.
Rodar as mesmas cinco sondagens, nesta ordem. Elas espelham exatamente o padrão de seção
do PRD-alvo.

1. **Modelo.** Como funciona conceitualmente? Qual a experiência na cabeça do usuário?
2. **Estrutura.** Quais as partes, os tipos, os estados possíveis?
3. **Regras exatas.** Números, tabelas, pontuação, janelas de tempo, limites, cadências.
   Aqui é onde se força a saída de tabelas. Se o usuário titubear num número, registrar
   como ponto em aberto em vez de inventar.
4. **Edge cases.** O que acontece fora do fluxo feliz? Provocar ativamente: e se for anulado,
   adiado, empatar, o usuário esquecer, o dado não chegar, dois eventos colidirem, a janela
   fechar no meio? Um PRD forte lista esses casos por feature.
5. **Pontos a definir.** O que ainda não foi decidido e precisa ser antes do desenvolvimento?

Repetir o loop para cada feature. Fechar cada uma com o mini-resumo antes de ir pra próxima.

## Fase 3: camadas transversais

Objetivo: as seções que não pertencem a uma feature só, mas atravessam o produto inteiro.
No PRD-alvo são as seções finais (notificações, dados/sync, i18n): comportamento no PRD,
detalhamento técnico no CONVENTIONS.md (regra de fronteira). Cobrir as que se aplicam:

- **Dados e sincronização.** De onde vêm os dados? Há fonte externa ou API? Qual a cadência
  de atualização de cada tipo de dado (o que muda a cada minuto vs o que muda por semana)?
  Há política de "nada de mock, só dado real"?
- **Notificações.** Quais eventos disparam aviso? In-app (sino), push fora do app? Há
  anti-spam, janelas de recência, preferências por categoria?
- **Performance.** Há requisito de velocidade? Alguma regra de ouro (ex.: cada tela
  carrega em um roundtrip)? Isso costuma nascer de uma dor concreta já vivida. Vira
  decisão registrada no PRD e padrão obrigatório no CONVENTIONS.md.
- **Internacionalização.** Quantos idiomas? O que é traduzido e o que não é (UGC, admin)?
- **Admin.** Existe painel administrativo? O que ele cria, edita, mede?

## Fase 4, Decisões estratégicas

Objetivo: o registro que dá contexto futuro ao time. É a seção mais negligenciada e a que
mais agrega.

- Quais escolhas difíceis foram feitas de propósito? Para cada uma, qual o racional?
- O que foi deliberadamente deixado de fora, e por quê?
- Houve decisão que substituiu uma anterior? Registrar a virada.

Cada decisão vira uma linha no formato "escolha: racional em uma frase".

## Saída da entrevista

Ao fim das fases, `_tmp/notas-entrevista.md` contém o material para escrever o PRD no
nível-alvo. Seguir para a redação do PRD (`anatomia-prd.md`) a partir do arquivo, depois
derivar rotas, design e conventions em sequência.
