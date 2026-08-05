# Anatomia do CONVENTIONS.md

Descreve a estrutura e o nível de profundidade do CONVENTIONS.md-alvo. O exemplo canônico
está em `exemplos/CONVENTIONS.md` (Chutaí). Consultar por seção, como nos demais.

O CONVENTIONS.md é o "como se constrói" do projeto: stack, padrões de arquitetura, regras
obrigatórias de implementação. Ele nasce da mesma entrevista que gerou o PRD — a camada
técnica das seções transversais e as convenções de construção capturadas na Fase 0 — e é
escrito depois do design, quando toda a superfície do produto já é conhecida.

## Regra de fronteira com o PRD

Espelho da regra na `anatomia-prd.md`: **o que o usuário percebe é PRD; o que só o dev
percebe é CONVENTIONS.** Aqui vive o detalhamento (tabelas, jobs, RPCs, libs, padrões de
cache, checklist de processo); no PRD fica o comportamento prometido, com link pra cá.
Não duplicar a promessa aqui, nem o detalhamento lá.

## Dois níveis

Se o projeto vive num umbrella com um CONVENTIONS.md compartilhado (o modelo de trabalho
da casa), o documento do projeto **abre declarando que o estende** e registra só o que é
específico: stack, padrões e regras locais. Não re-narrar o modelo compartilhado.

## Esqueleto

```
# CONVENTIONS: <Nome do produto>

## 1. Stack
   O que roda onde, em uma tabela ou lista curta: front, back, banco, deploy, região.
   Segredos: onde vivem e a regra (nunca versionados, server-only quando for o caso).

## 2. Regras do projeto
   As regras obrigatórias que valem em qualquer tarefa, uma linha cada, com o racional
   quando não for óbvio. Ex.: "sem mocks: todo dado externo tem fonte real + rotina de
   atualização"; "regra de negócio em código, nunca em SQL"; "RPC de leitura respeita
   RLS".

## 3..N. <Uma seção por camada técnica>
   O detalhamento das camadas transversais do PRD e dos sistemas que o produto exige.
   Tipicamente: dados e sincronização (arquitetura de cache, jobs com cadência em
   tabela), notificações (infra de entrega, anti-spam), i18n (implementação), performance
   (padrões obrigatórios com o porquê). Cada seção nomeia as peças (tabelas, functions,
   crons) e registra o padrão, não o tutorial.

## <Processo>
   Checklists curtos que evitam regressão: o que toda tela/endpoint novo precisa ter,
   convenções de migration, o que rodar antes de propor commit.

## <Índice de ADRs>
   Decisão técnica cara de reverter vira ADR em docs/adrs/ (uma decisão por arquivo,
   nunca editar ADR aceito — criar um novo que o substitui). Este índice lista ADR,
   decisão e status em tabela. Nasce vazio.
```

## Convenções

- **Padrão, não tutorial.** Cada seção registra a regra e as peças nomeadas; não ensina
  a implementar do zero. Quem lê é um agente com acesso ao código.
- **Tabela para cadência e mapa.** Jobs de sync, crons, matriz do que roda onde: tabela.
- **O código vence.** Como no DESIGN.md: padrão que mudou no código atualiza o doc no
  mesmo PR. CONVENTIONS.md descreve o estado atual, não a história (história é ADR).
- **Racional embutido.** Regra sem porquê vira cargo cult; uma linha de racional basta
  (ex.: a regra "1 página = 1 roundtrip" nasceu de um diagnóstico de 5-7s de navegação).

## Como usar o exemplo

`exemplos/CONVENTIONS.md` é o padrão-ouro, extraído do mesmo Chutaí do PRD de exemplo.
Reproduzir o nível de detalhe (nomes de função, cron exato, padrão de segurança), não o
conteúdo.
