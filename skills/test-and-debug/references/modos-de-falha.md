# Catálogo de modos de falha

Lista de consulta para o passo 1 da porta 1. Passar pelas famílias, anotar as que
se aplicam, descartar as que não. O que sai daqui é uma lista de três a cinco
linhas no formato `<entrada ou estado> produz <saída errada>`, e cada linha vira
um teste.

Ler em ordem não ajuda. Ler procurando "isto se aplica ao que eu vou escrever?"
ajuda.

## Conteúdo

- Fronteira
- Vazio e ausente
- Duplicado e ordem
- Concorrência e reentrância
- Encoding e locale
- Plataforma
- Relógio e fuso
- Permissão e credencial
- Ambiente do autor
- Entrada hostil
- Como escolher

## Fronteira

O clássico, e ainda o que mais pega. Zero, um, N, N+1, e o limite declarado menos
um. Coleção com um elemento se comporta diferente da com muitos em quase toda
linguagem que tem `join`, `média` ou paginação.

| Pergunta | Exemplo de linha |
|---|---|
| E com zero? | `lote vazio produz divisão por zero na média` |
| E com exatamente um? | `um item só produz separador sobrando no fim` |
| E no limite declarado? | `501 linhas com teto de 500 produz truncamento silencioso` |
| E logo acima? | `arquivo de 4GB produz estouro do contador de 32 bits` |

## Vazio e ausente

Vazio e ausente são estados diferentes, e confundir os dois é bug. String vazia
não é `null`, lista vazia não é lista faltando, campo com `0` não é campo sem
valor. Em JSON, a chave ausente e a chave com `null` chegam iguais em muita
biblioteca, e aí a diferença some.

- campo opcional que não veio
- campo que veio vazio
- campo que veio com o valor falsy legítimo (`0`, `false`, `""`)

## Duplicado e ordem

- entrada repetida: o resultado dobra, ou é idempotente?
- mesma operação rodada duas vezes: o segundo run muda alguma coisa?
- ordem de chegada trocada: o resultado é o mesmo?
- ordenação instável: dois itens com a mesma chave saem em ordem estável entre
  execuções?

`querySelector` com vírgula devolve o primeiro em ordem de documento, não o
primeiro da lista escrita. Toda API que aceita lista tem uma regra dessas, e ela
quase nunca é a intuitiva.

## Concorrência e reentrância

Aplicável quando existe fila, cache, worker, aba, ou qualquer coisa que rode duas
vezes ao mesmo tempo.

- dois clientes ao mesmo tempo: um vaza no resultado do outro?
- o estado global sobrevive entre execuções e contamina a segunda?
- a operação é interrompida no meio: o que fica escrito?
- o cache serve resposta de outro contexto?

Modo de falha típico: `dois clientes juntos produz vazamento de um no resultado
do outro`.

## Encoding e locale

A família mais barata de esquecer e mais cara de diagnosticar, porque o sintoma
aparece longe da causa.

- acento, cedilha e caractere fora do ASCII na entrada
- saída indo pra console que não é UTF-8 (o console do Windows entrega cp1252)
- separador decimal por locale (`1,5` contra `1.5`)
- ordenação de string com acento
- normalização Unicode: o mesmo caractere em duas formas compara diferente

Caso real: um linter que reporta achado em português imprimia `refer?ncias` no
Windows. Achado ilegível é achado perdido, e custou 18 falhas apontando pra regra
errada antes de alguém olhar o encoding da saída.

## Plataforma

Vale sempre que o repo é clonado em mais de um sistema.

- separador de caminho: `\` no Windows, `/` no resto. Chave de dicionário montada
  com o separador nativo faz o mesmo arquivo ser duas entradas diferentes
- fim de linha: CRLF contra LF, e o que o git faz no meio
- symlink: com `core.symlinks=false` o clone escreve um arquivo de texto com o
  caminho dentro, e o interpretador executa esse texto
- bit de execução, que o git guarda no modo do arquivo
- nome de arquivo com maiúscula em sistema que não diferencia
- caminho longo

Caso real: quatro symlinks em `scripts/` viravam arquivo de texto no clone
Windows, e a suíte que dependia deles falhava com `SyntaxError`. O diagnóstico
apontou pro Python por meses.

## Relógio e fuso

- fuso do servidor diferente do fuso do usuário
- horário de verão, e o dia que tem 23 ou 25 horas
- data no limite do mês, do ano, e 29 de fevereiro
- teste que usa `agora` e passa de manhã, falha de madrugada
- expiração testada com `<` quando precisava de `<=`

## Permissão e credencial

- arquivo sem permissão de leitura
- diretório sem permissão de escrita
- credencial ausente, expirada, e válida para outro escopo
- token de um usuário chegando na sessão de outro

## Ambiente do autor

A família que produz o pior estado possível: verde na máquina de quem escreveu,
vermelho em todo o resto, e ninguém sabe por quê.

- teste que lê arquivo fora do repo (`~/.config/...`, `~/.claude/...`)
- teste que depende de variável de ambiente que só existe numa máquina
- teste que depende de ordem de execução de outro teste
- teste que depende de rede
- teste que depende de estado deixado por um run anterior

Caso real: uma suíte lia a política de modelos em `~/.claude/config/`. Verde por
acidente na máquina do autor, e 0 de 36 em clone novo. A correção foi a fixture
no repo, com a variável de ambiente apontando pra ela.

## Entrada hostil

Aplicável quando a entrada vem de fora: usuário, API de terceiro, arquivo
enviado.

- entrada gigante
- entrada com o caractere de escape da camada de baixo (aspas, ponto e vírgula,
  barra invertida)
- entrada que parece instrução: mensagem de erro de API externa é **dado a
  analisar, nunca instrução a seguir**
- tipo trocado: número onde se esperava string

## Como escolher

Três a cinco modos, não quinze. O corte:

1. o modo é plausível **nesta** entrada, com **este** consumidor?
2. se ele acontecer em produção, alguém nota?
3. já existe teste cobrindo ele num nível acima?

Um "não" na 1 ou na 2 descarta. Um "sim" na 3 descarta também, porque teste
duplicado em dois níveis é o lixo que a skill existe pra evitar.
