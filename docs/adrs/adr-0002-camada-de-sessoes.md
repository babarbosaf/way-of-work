# ADR-0002: a camada de terminal escreve, num caminho só, quando pedida

- **Status:** aceita
- **Contexto:** `docs/specs/camada-de-sessoes/spec.md`, D-02, D-03 e D-10
- **Substitui:** ADR-0001, que está em `docs/adrs/archive/`

## O que estava em jogo

A ADR-0001, que esta substitui, fechou que a camada lê o gate e nunca escreve
nele, e recusou worker
dentro de um pane com um argumento que continua de pé: com o worker vivo lá
dentro, a camada vira pré-condição do despacho, e desligá-la muda quem trabalha.

O que mudou é o pedido. Worker invisível não tem nome, não tem estado e não tem
porta de entrada: worker parado esperando resposta é idêntico a worker
trabalhando, e a diferença só aparece no prazo estourado, com a cota já gasta.
Ver e corrigir o worker exige que ele more numa aba, e aba com nome exige alguém
escrever esse nome.

## Decisão

A camada **só lê no caminho padrão**, e existe **um** caminho de escrita, que é
nomeado e se pede: `delegate.sh --visivel <trabalho>`. Sem a flag, nenhuma linha
de código toca a ferramenta de terminal, e o despacho é byte a byte o de antes.

Os nomes da ferramenta moram num arquivo só, `scripts/herdr-adapter.sh`. Quem
quiser outro multiplexer reescreve esse arquivo, e não caça o nome espalhado.

A ADR-0001 só é substituída fora do caminho padrão: a recusa que ela escreveu
continua valendo onde foi escrita, e no caminho padrão worker não roda dentro da
tela. O que passou a existir é um modo pedido
explicitamente, onde ela não vale, e que falha nomeando a causa quando a
ferramenta ou o adaptador não estão lá, em vez de cair calado no modo antigo.

## O que foi recusado, e por quê

**Manter a fronteira de só leitura.** Custa a lista lateral inteira: a tela não
tem como adivinhar qual sessão é qual trabalho, então ou alguém escreve o nome,
ou a lista é uma pilha de linhas iguais. Empurrar só onde puxar não alcança.

**Arquitetura de plugins para multiplexers.** Há um adaptador só, e abstrair
para um caso é o corte que a casa proíbe. Quem usa outro multiplexer consome a
linha puxada e ganha status agregado, que é o que a ADR-0001 substituída já
entregava.

**Fechar aba por prazo de metadados.** A API de metadados da ferramenta expira
sozinha, e expirar apagaria a linha da sessão cujo despachante morreu, que é
exatamente a que precisa aparecer. O estado mora no rótulo da aba, que morre com
a aba, e num registro que a lib varre.

## Custo de reverter

Baixo, e continua sendo de propósito. Tirar a flag e o adaptador devolve o
sistema ao estado da ADR-0001 que esta substitui, sem tocar em cascata, cota ou
registro, porque
nenhum dos três sabe que o modo visível existe.
