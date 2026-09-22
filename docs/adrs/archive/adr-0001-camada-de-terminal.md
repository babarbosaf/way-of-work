# ADR-0001: a camada de terminal é o herdr, e só lê

- **Status:** substituída por ADR-0002, em 22/set/2026
- **Contexto:** `docs/specs/orquestracao-delegacao/spec.md`, D-07 e AC-15

## O que estava em jogo

Com despacho assíncrono, três tasks correm em baldes de cota diferentes e nada
mostra as três juntas. A spec deixou a escolha da ferramenta de fora de propósito,
porque trocar de multiplexer depois de o roteamento depender dele é caro, e marcou
o ticket da camada como bloqueado até esta decisão existir.

## Decisão

A camada é o [herdr](https://github.com/herdrdev/herdr) (0.9.1, homebrew-core), e
ela **lê o estado do gate, nunca escreve nele**. Um pane roda o leitor do
despachante em laço; o despachante não sabe que o herdr existe.

Dois motivos pesaram mais que o resto. O herdr já tem sidebar de agente e API
local por socket Unix, que é o que eu precisaria escrever à mão em cima de tmux; e
instalar por brew deixa a versão auditável, ao contrário de `curl | sh`.

A fronteira de leitura é o que sustenta o AC-15 ao pé da letra: sem caminho de
escrita, não existe caminho de código pelo qual a camada escolha worker ou modelo,
então desligar o herdr muda o que aparece na tela e não muda quem trabalha.

## O que foi recusado, e por quê

**Worker dentro de um pane do herdr.** Era a leitura mais natural do pedido, e é
justamente o que quebra o AC-15: com o worker vivo dentro do pane, a camada passa a
ser pré-condição do despacho, e desligá-la muda o roteamento. Fica fora enquanto
worker interativo estiver fora de escopo.

**tmux com script próprio.** Mesma tela, mais código pra manter aqui, sem a
API local que o herdr entrega pronta.

## Custo de reverter

Baixo, e foi assim de propósito. O que o repo passa a ter é um leitor de estado no
despachante e um doc de referência; trocar de ferramenta reescreve o doc e não
toca no despachante. O que seria caro é a alternativa recusada, e ela é a razão de
esta decisão existir antes do código.
