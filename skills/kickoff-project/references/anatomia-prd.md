# Anatomia do PRD

Descreve a estrutura e o nível de profundidade do PRD-alvo. O exemplo canônico completo
está em `exemplos/PRD.md` (Chutaí). Consultar o exemplo por seção quando precisar ver o
padrão na prática, em vez de carregar o arquivo inteiro toda vez.

O PRD é o documento-raiz. As rotas, o design e as conventions se derivam dele.

## Regra de fronteira com o CONVENTIONS.md

**O que o usuário percebe é PRD; o que só o dev percebe é CONVENTIONS.** O comportamento
(a notificação chega em até 1h, o dado é sempre real, o app abre instantâneo) fica no PRD.
O como (a edge function, o cron, a RPC, a lib de i18n, o padrão de cache) vai para o
CONVENTIONS.md. Onde o PRD encostar em técnica, fecha com um link para a seção
correspondente do CONVENTIONS.md, nunca duplica o detalhamento. Decisão estratégica de
teor técnico permanece na seção de decisões do PRD (decisão é produto); só o detalhamento
migra.

## O que faz um PRD deste nível

Não é uma lista de features. Cada feature é arquitetada. O que diferencia:

- **Padrão de seção repetido.** Cada feature segue: modelo conceitual, depois estrutura,
  depois as regras em tabela, depois edge cases explícitos, e quase sempre um bloco de
  "pontos a definir".
- **Edge cases por feature.** Fluxo feliz é o mínimo. O valor está nos casos de borda
  listados: o que anula, o que adia, o que empata, o que acontece no esquecimento.
- **Pontos a definir.** Honestidade sobre o que ainda não foi decidido. Melhor registrar
  a lacuna do que inventar um número.
- **Decisões estratégicas registradas.** Uma seção que loga as escolhas difíceis com o
  racional de cada uma, incluindo o que foi deixado de fora e por quê. Dá contexto ao time
  futuro.
- **Seções transversais.** Ao fim, as camadas que atravessam o produto (notificações,
  sincronização de dados, i18n) descritas em nível de comportamento: o que o usuário vê,
  quais eventos existem, o que é ou não coberto. O detalhamento de arquitetura de cada uma
  vive no CONVENTIONS.md, linkado ao fim da seção (regra de fronteira acima).
- **Nível de leitura duplo.** Um PM que não lê código consegue seguir a prosa; um dev
  consegue executar a partir dela. Descrever arquitetura (tabelas, jobs, rotinas, cadências)
  conceitualmente, nomeando as peças, sem exigir que o leitor leia código.

## Esqueleto

```
# PRD: <Nome do produto>

## 1. Visão geral
   Uma a duas frases do que é e para quem. Depois os 2 a 4 pilares de engajamento
   em lista, cada um com uma frase.

## 2..N. <Uma seção por feature / pilar>
   Padrão interno de cada seção:
   ### Modelo           -> como funciona conceitualmente
   ### Estrutura        -> partes, tipos, estados
   ### Regras / tabelas -> números exatos em tabela (pontuação, janelas, limites)
   ### Edge cases       -> casos fora do fluxo feliz
   ### Pontos a definir -> o que falta decidir

## <Restrições invioláveis>
   Regras, requisitos e limitações capturados na Fase 0 que não podem ser quebrados
   nem ultrapassados. Uma linha por restrição, com o racional quando houver.

## <Decisões estratégicas registradas>
   Lista de "escolha: racional". Inclui o que foi deixado de fora.

## <Seções transversais>
   Notificações, Dados e sincronização, Internacionalização, Admin. Cada uma no nível
   de comportamento (eventos, escopo, promessas ao usuário), com tabela quando fizer
   sentido, fechando com link para a seção correspondente do CONVENTIONS.md.
   Performance e demais padrões puramente técnicos não ganham seção no PRD: vivem no
   CONVENTIONS.md, citados na seção de decisões estratégicas quando forem requisito.
```

A numeração é contínua. As seções transversais entram como seções numeradas ao fim.

## Convenções

- **Tabelas para toda regra numérica.** Pontuação, multiplicadores, janelas de tempo,
  limites, cadências de sync. Nunca deixar número solto no meio da prosa quando cabe tabela.
- **Referenciar rotas por path** (`/palpites/jogos/:id`), mesmo antes do documento de rotas
  existir. Isso amarra PRD e rotas.
- **Nota de escopo** quando algo mudou ou foi removido: registrar a data e o que aconteceu
  (ex.: "substituiu o Mural em 12/06/2026"). Manter memória das viradas.
- **Blockquotes para contexto factual** que ajuda a entender uma regra (ex.: por que a Copa
  2026 tem uma fase a mais).

## Como usar o exemplo

`exemplos/PRD.md` é o padrão-ouro. Ao escrever uma seção nova, abrir a seção equivalente
do exemplo e reproduzir o nível de detalhe, não o conteúdo. O exemplo é de um bolão de
futebol; o produto em mãos pode ser qualquer coisa. O que se copia é a disciplina:
modelo, estrutura, tabela de regras, edge cases, pontos a definir.
