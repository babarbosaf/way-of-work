# Anatomia do CONVENTIONS.md

Descreve a estrutura e o nível de profundidade do CONVENTIONS.md-alvo. O exemplo canônico
está em `exemplos/CONVENTIONS.md` (Chutaí). Consultar por seção, como nos demais.

O CONVENTIONS.md é a regra universal de construção: o que vale em qualquer tarefa do
projeto, seja qual for a funcionalidade. Stack, regras de código, branch, commit, lint,
CI e evals. Teto de 150 linhas, cobrado por `check-docs.py --molde`.

## Regra de fronteira

Espelho da `anatomia-prd.md`: **um assunto, um lugar.** O contrato de uma funcionalidade
(tabela, job, RPC, evento) mora na seção dela no PRD, e não aqui. O mapa de pastas e de
docs mora no README, e não aqui. Se uma regra só vale para uma funcionalidade, ela não é
universal.

## Dois níveis

Se o projeto vive num umbrella com um CONVENTIONS.md compartilhado (o modelo de trabalho
comum a todos os projetos), o documento do projeto **abre declarando que o estende** e registra só o que é
específico: stack, padrões e regras locais. Não re-narrar o modelo compartilhado.

## Esqueleto

```
# CONVENTIONS: <Nome do produto>

## 1. Stack
   O que roda onde, em uma tabela ou lista curta: front, back, banco, deploy, região.
   Deploy declara o modelo, não só o host: automático por push, ou manual por leva
   com validação em `localhost` (`git-workflow-and-versioning`, `ci-deploy-flow.md`).
   Segredos: onde vivem e a regra (nunca versionados, server-only quando for o caso).

## 2. Regras do projeto
   As regras obrigatórias que valem em qualquer tarefa, uma linha cada, com o racional
   quando não for óbvio. Ex.: "sem mocks: todo dado externo tem fonte real + rotina de
   atualização"; "regra de negócio em código, nunca em SQL"; "RPC de leitura respeita
   RLS".

## 3. Processo
   Branch, commit, PR, o que rodar antes de propor commit, convenção de migration.

## 4. Lint, CI e evals
   O que o CI roda em todo PR, e o `evals.yaml`: cada eval com gatilho por caminho,
   comando e corte.

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
