# Anatomia do README.md

A porta de entrada, para quem chega, pessoa ou agente. Responde três perguntas: o que é,
onde está cada coisa, como começar. Não carrega regra: regra de agente é AGENTS, regra de
construção é CONVENTIONS, funcionalidade é PRD.

É o único doc com mapa de pastas e mapa de docs (`check-docs.py --molde`).
O exemplo canônico é `exemplos/README.md` (Chutaí).

## Esqueleto

```
# <nome>

Uma a duas frases: o que é e para quem.

## Como funciona
   Um diagrama curto do fluxo, com a tag `no ar` ou `previsto` em cada etapa.
   Explicação em bullets, a tag em cada funcionalidade.

## Estrutura
   Tabela de pastas de primeiro nível: o que tem, estado.

## Começar
   Os comandos para clonar, rodar e testar, byte a byte.

## Documentos
   Tabela: doc, para quem, o que responde.

## Licença
   Só em repo público: o nome SPDX e o link pro LICENSE.
```

## Convenções

- **Estado final com tags,** como todo doc de estado. A tag vai na funcionalidade (etapa,
  linha, célula), nunca num bloco `no ar` seguido de um bloco `previsto`: é o "hoje"
  contra "no alvo" com outra roupa. `check-docs.py --estado` acusa README sem tag.
- **A frase de abertura cabe em 120 caracteres,** a mesma da descrição do repo.
- **Até ~60 linhas.** Detalhe que cresce aqui pertence a outro doc.
