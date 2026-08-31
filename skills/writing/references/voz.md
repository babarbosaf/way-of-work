# Voz, molde de calibração

Este arquivo é o molde, e nunca a calibração. Quem veio calibrar a voz de alguém quer o
`concept_voz_<slug>.md` preenchido, na base de conhecimento.

Copie este arquivo pra sua base de conhecimento (wiki, repo de notas, o que for) e
preencha. O nome sugerido é `concept_voz_<seu-slug>.md`, pra casar com o ponteiro do seu
`AGENTS.md`. Preenchido, ele é a fonte única de voz: os agentes leem daqui, e a lista de
banidos cresce por correção ao vivo, não hardcodada em prompt.

A doutrina de escrita, brevidade e naturalidade com o porquê de cada regra, vive em
`skills/writing/SKILL.md` e vale pra todo mundo. Este arquivo é a camada de cima, o que é
seu e de mais ninguém. Por isso o preenchido nunca sobe pro repo público.

Por que separado: prompt de agente é caro e é reescrito a cada sessão, e lista de termo
banido cresce toda semana. Se ela vive no prompt, ninguém atualiza. Se vive num arquivo
que o agente lê, a correção de hoje vale amanhã.

---

## Resumo

Três a cinco linhas: quem escreve, pra quem, em que registro. Um agente que só lê esta
seção já deve acertar o tom.

> Exemplo de forma, não copie o conteúdo: "Escrita técnica em PT-BR, direta, sem floreio.
> O leitor é quem vai executar, não quem vai aprovar. Afirma e assume o custo de estar
> errado, em vez de hedge."

## Banidos

A lista que faz o trabalho. Uma linha por termo ou construção, com o substituto quando
houver, porque banido sem alternativa vira paralisia.

| banido | por quê | no lugar |
|---|---|---|
| | | |

Regra de crescimento: entra por correção real, nunca por suspeita. Se você nunca viu o
termo sair no output, ele não pertence aqui. Lista inflada deixa de ser lida.

## Brevidade

O que cortar e o que **nunca** cortar. O segundo é o que importa: código, comando,
mensagem de erro e número vão byte-a-byte, sempre.

## Naturalidade

As construções que denunciam texto de máquina no seu idioma e no seu registro. Não é a
mesma lista em toda língua: parataxe pesa em PT-BR, voz passiva pesa em inglês.

## Escrever como você

**Só preencha esta seção se algum agente escreve em seu nome.** Se ele assina como ele
mesmo, apague a seção inteira. Calibrar imitação que ninguém vai usar é dívida.

Se preencher, o material é corpus, não adjetivo. Cole trechos reais seus, mensagem,
e-mail, comentário, e deixe o agente extrair o padrão. "Escreva informal" não calibra
nada. Três mensagens suas calibram.

E declare a consequência: quem escreve indistinguível de você produz erro indistinguível
de seu. As portas de aprovação deixam de ser burocracia e passam a ser o único anteparo.

## Self-check antes de qualquer output

Uma lista numerada e curta, que o agente roda antes de responder. Cada item precisa ser
verificável em segundos. Pergunta que exige julgamento longo não sobrevive ao uso.

1.
2.
3.

## Quem lê isto

Liste os consumidores: quais agentes, em que momento, e o que cada um faz com o arquivo.
Serve pra saber o custo de mudar, e pra descobrir seção que ninguém lê.
