# Anatomia do README.md

A porta de entrada, para quem chega, pessoa ou agente. Responde três perguntas: o que é,
onde está cada coisa, como começar. Não carrega regra: regra de agente é AGENTS, regra de
construção é CONVENTIONS, funcionalidade é PRD.

É o único doc com mapa de pastas e mapa de docs (`check-docs.py --molde`).

## Esqueleto

```
# <nome>

Uma a duas frases: o que é e para quem.

## Como funciona
   Um diagrama curto do fluxo, com a tag `no ar` ou `previsto` em cada etapa.

## Estrutura
   Tabela de pastas de primeiro nível: o que tem, estado.

## Começar
   Os comandos para clonar, rodar e testar, byte a byte.

## Documentos
   Tabela: doc, para quem, o que responde.
```

## Convenções

- **Estado final com tags,** como todo doc de estado. Nada de "hoje" contra "no alvo".
- **Até ~60 linhas.** Detalhe que cresce aqui pertence a outro doc.
