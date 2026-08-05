# Anatomia do documento de design

Descreve o design system. Exemplo canônico em `exemplos/DESIGN.md` (Chutaí, "Neon Night").

O design se DERIVA das telas que as rotas definiram. Só se sabe quais patterns de componente
o produto precisa depois de saber quais telas existem. Escrever este documento por último.

## Função

É o que garante consistência visual e mata a refação. Um bom design system faz duas coisas:
dá os tokens e patterns prontos para construir tela nova rápido, e cria guarda-corpos contra
o "AI slop" (o visual genérico e sem intenção que sai por padrão).

## Estrutura

```
# DESIGN.md — <Nome do sistema>

1. Identidade      -> nome do sistema, vibe references, dial values, modo de cor
2. Tokens          -> cores (valores exatos), tipografia (escala), radius, motion, sombras
3. Patterns de componente -> hero, card de lista, stat card, botão, pill, input, avatar,
                             icon-mark. Cada um com o pattern e o código.
4. Ícones          -> biblioteca, weights, tamanhos
5. Layout          -> padrão de página, hierarquia de sections, elementos sticky
6. Anti-slop checklist -> o que validar antes de commitar
7. Como criar tela nova -> passo a passo
8. Como criar componente novo -> quando extrair, estrutura de arquivo
9. Tooling         -> stack visual, setup, quando adicionar dependência
10. O que NÃO fazer -> lista negra do AI slop
11. Roadmap visual  -> quais telas já têm o sistema aplicado, quais faltam
```

## Identidade (seção 1)

O coração do documento. Definir:

- **Nome do sistema.** Um nome próprio ("Neon Night") ancora as decisões e dá identidade.
- **Vibe references.** 3 a 5 produtos reais cuja estética serve de norte ("Amazon Music
  dark mais cyan accent"). Isso é o que se pergunta na entrevista de design.
- **Dial values.** Variância de design, intensidade de motion, densidade visual. Traduz a
  intenção em números que orientam escolhas.
- **Modo de cor.** Dark, light, ambos. Travar cedo.

## Tokens (seção 2)

Valores exatos, em tabela. Cor com o valor real (OKLCH, hex) e o uso de cada token. Definir
a regra de acento (quantas cores de destaque, e a disciplina de variar intensidade em vez de
introduzir cor nova). Tipografia como escala nomeada (hero, section header, card title, body,
eyebrow, caption) com as classes de cada nível. Radius, motion e sombras com seus valores e a
regra de forma (o sistema é soft e pill? sharp? nunca misturar os dois numa tela).

## Patterns de componente (seção 3)

Cada pattern recorrente ganha: uma frase do que é, e o código de referência. Explicar o
pattern em prosa antes do código, para que o PM entenda a decisão sem ler o código, e o
construtor tenha o código exato. Preferir estender um pattern existente a inventar variante.

## Guarda-corpos (seções 6 e 10)

Duas listas que são o diferencial:

- **Anti-slop checklist:** o que validar antes de entregar uma tela (um único acento,
  hierarquia de forma consistente, cards não idênticos, números tabulares, motion reduzido
  respeitado, contraste mínimo).
- **O que NÃO fazer:** a lista negra explícita dos vícios do visual genérico de IA
  (gradiente roxo-rosa, fonte Inter default, sombra preta pura, três cards iguais lado a
  lado, eyebrow em toda section, e assim por diante).

## Convenções

- **O código vence.** Registrar que, quando o documento divergir do código real, o código
  é a verdade, e o doc deve ser atualizado no mesmo PR que muda tokens ou patterns.

## Quando já existe um design system

Se o usuário apontou um design system existente na Fase 0 da entrevista, ele é a fonte
primária deste documento:

1. Ler o arquivo apontado por inteiro antes de escrever qualquer coisa.
2. Nenhuma informação dele pode ser perdida: todo token, cor, fonte, pattern, regra ou
   proibição existente entra no DESIGN.md, reorganizado na estrutura acima.
3. A entrevista de design curta se reduz às lacunas: perguntar apenas o que o arquivo
   não cobre (por exemplo, dial values ou modo de cor ausentes).
4. Se algo no arquivo conflitar com as telas que as rotas exigem, apontar o conflito ao
   usuário e decidir junto, nunca descartar ou alterar silenciosamente.

## Como derivar das rotas

1. Listar os tipos de tela que as rotas produziram (hero mais lista, hero mais form, lista
   pura, dashboard de stats).
2. Para cada tipo, identificar os patterns de componente necessários.
3. Rodar a entrevista de design curta: vibe references, dial values, modo de cor, e a stack
   visual (ver `stack-default.md` para o default).
4. Escrever identidade, tokens, os patterns que as telas exigem, e as duas listas de
   guarda-corpo.
