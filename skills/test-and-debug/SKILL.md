---
name: test-and-debug
description: |
  Escreve o teste que falha antes do código e desce até a causa raiz quando algo quebra: lista de modos de falha antes do RED, loop de sinal determinístico antes do debug, hipóteses falsificáveis uma por vez, e o filtro que barra teste tautológico antes dele nascer.
  Invoque quando o usuário for implementar comportamento novo, reportar bug ou teste falhando, descrever resultado inesperado ("retorna X quando devia Y", "parou de funcionar", "tá dando erro"), pedir para investigar, debugar ou achar a causa, quando uma suíte ficar vermelha, e quando alguém propuser apagar testes em lote.
  Não invoque para: rodar suíte que já existe, fechar commit ou versão (`git-workflow-and-versioning`), escrever spec (`to-spec`), ou script descartável que não entra no repo.
---

> Teste escrito depois do código reafirma o código, inclusive quando o código está errado.
> Debug sem loop de sinal é chute com sotaque técnico.

Duas portas. Comportamento novo entra pela primeira, bug entra pela segunda, e as
duas terminam no mesmo lugar: suíte verde com o vermelho provado.

## Conteúdo

- Porta 1, comportamento novo
- Porta 2, bug
- O que não vira teste
- Gate barato antes do caro
- Onde isso entra no fluxo
- Verification

## Porta 1, comportamento novo

### 1. Modos de falha, antes de qualquer teste

Três a cinco linhas, no formato `<entrada ou estado> produz <saída errada>`,
escritas **antes de olhar a implementação**. Quem lista depois lista o que o
código já trata.

```
lote vazio           produz divisão por zero na média
dois clientes juntos produz vazamento de um no resultado do outro
nome com acento      produz linha ilegível no console do Windows
```

Essa lista é o contrato, e é ela que vira teste. O catálogo de famílias por onde
passar (fronteira, vazio, duplicado, ordem, concorrência, encoding, plataforma,
relógio, permissão, ambiente do autor) está em
[references/modos-de-falha.md](references/modos-de-falha.md).

### 2. RED, e o vermelho certo

Um teste por modo de falha. Rodar, e **ler a mensagem de falha**: ela precisa
nomear o modo da lista. `ImportError`, `SyntaxError`, erro de digitação no nome
do fixture ou `AssertionError` sem valor não são o vermelho certo; são o teste
ainda não testando nada. Ajustar até a falha dizer o que se espera que quebre.

Esse é o passo que quase todo mundo pula, e é a única defesa contra o teste que
fica verde com a implementação errada.

### 3. GREEN mínimo

O menor código que apaga o vermelho. Nada a mais: o que sobra sem teste é feature
especulativa com outro nome.

### 4. REFACTOR

Simplificar com a suíte verde, sem acrescentar comportamento. No Claude Code o
passo é o builtin `/simplify` (`docs/claude-code.md`); em outro harness, na mão.

## Porta 2, bug

### 0. Loop de sinal, antes de investigar

Sem um comando determinístico que responda **com bug** ou **sem bug** em menos de
30 segundos, o resto é chute. Três níveis, nessa ordem de preferência:

1. teste que falha (vira o de regressão depois);
2. script de repro, um comando com input controlado;
3. loop diferencial: versão boa e versão atual lado a lado, mesmo input, e o diff
   é o sinal.

Falha intermitente sobe a taxa de repro acima de 50% antes de qualquer hipótese.
Debugar com 5% de repro mascara a causa e valida a correção errada.

### 1. Reproduzir, e conferir que é a falha certa

Confirmar pelo loop que a falha é a que o usuário descreveu, e não uma vizinha.
Registrar os passos exatos e o ambiente: versão, sistema, variável de ambiente
que importa.

### 2. Regressão antes da correção

O teste que reproduz o bug nasce **antes** do fix, e passa pelo mesmo crivo do
passo 2 da porta 1: a mensagem de falha nomeia o sintoma real.

### 3. Hipóteses falsificáveis, uma por vez

Três a cinco hipóteses, cada uma com predição testável, ranqueadas por
probabilidade vezes custo de testar. Barata e provável primeiro. "Se for cache
velho, limpar o cache antes faz o teste passar" é hipótese; "acho que é o cache"
não é. Cada hipótese descartada é progresso; "vamos ver o que sai" não é.

### 4. Descer até a causa raiz, com regra de parada

A regra de parada, que é o que separa causa de sintoma com sorte:

> A causa explica **todos** os sintomas observados, e removê-la deixa o teste verde.

Causa que explica 18 de 20 falhas não é a causa. "Deduplicar no resultado" é
sintoma; "query errada" é causa. Protocolo de descida, `git bisect` com o comando
do loop, instrumentação temporária e o caso intermitente estão em
[references/causa-raiz.md](references/causa-raiz.md).

### 5. Corrigir, e varrer o resto

Achada a causa, procurar o mesmo padrão no resto do repo antes de fechar. Causa
raiz costuma ter irmãos, e o segundo custa a metade do primeiro se for agora.

### 6. Guardar

Regressão verde, suíte verde, instrumentação temporária removida. Lição
cross-projeto vai pra memória via `capture-lessons`, nunca inline no código.

## O que não vira teste

A garantia contra lixo é gate de nascimento, não faxina depois. **Antes de um
teste entrar, três perguntas:**

1. Quebre a linha que ele testa. Fica vermelho?
2. O valor esperado é a resposta do produto, ou foi calculado com o código do
   próprio produto?
3. Ele dirige o produto pela pergunta que o produto responde de verdade, ou por um
   stub que devolve o que o teste queria?

Um "não" em qualquer uma é teste que fica verde com o código errado. Ele não
entra.

Mais três travas, que é o que segura o volume:

- **Um teste por modo de falha, não por função.** A lista do passo 1 é a lista de
  testes. Sem modo, sem teste.
- **O teste mora no nível mais alto que ainda falha pelo motivo certo** e roda
  rápido o bastante pro loop. Unit é pra onde se desce quando o nível de cima não
  consegue nomear o modo de falha, não o ponto de partida.
- **Teste morre um de cada vez, com a pergunta respondida.** Nunca em lote, nunca
  por fan-out de subagente. Deleção em massa troca cobertura medida por cobertura
  suposta, e quem propõe a faxina raramente é quem mediu.

Um teste é apagado quando assere implementação e não comportamento, quando duplica
modo já coberto num nível acima, ou quando reprova a pergunta 1. Apagar conta como
progresso.

Nome de teste, hermeticidade, fronteira de mock e fixture:
[references/escrita-de-teste.md](references/escrita-de-teste.md). O dialeto do
projeto (framework, onde o arquivo mora, `verify_cmd`, corte de cobertura) fica no
`CONVENTIONS.md` dele, que é padrão e não tutorial.

## Gate barato antes do caro

Um arquivo de teste antes da suíte. A suíte antes do cenário. Local antes de clone
novo. Cada degrau só roda se o de baixo passou.

E o contrapeso: quando o diff toca arquivo que o git guarda por modo ou caminho
(symlink, bit de execução, `.gitattributes`, fim de linha), **verde local não
conta**. Só clone novo conta.

## Onde isso entra no fluxo

| Momento | Quem chama |
|---|---|
| Ticket entrando em build | `execute`, Fase 2, antes do código; a lista de modos de falha vai no comentário de abertura do ticket |
| Task indo pro worker | `delegate`, no prompt, e RED e GREEN em commits separados pra integração poder conferir |
| Fechando commit | `git-workflow-and-versioning` cobra a evidência: o vermelho existiu, e a regressão nasceu antes do fix |

## Verification

- [ ] Lista de modos de falha escrita antes do primeiro teste, e cada modo tem um teste
- [ ] A mensagem do RED nomeia o modo de falha, não um erro de importação ou de digitação
- [ ] Bug: loop de sinal determinístico existe antes da primeira hipótese
- [ ] Bug: regressão commitada antes da correção
- [ ] Causa raiz explica todos os sintomas, e removê-la deixa o teste verde
- [ ] Cada teste novo passa nas três perguntas do gate de nascimento
- [ ] Instrumentação temporária removida (`grep -rn "DEBUG-" .`)
- [ ] Suíte completa verde, e clone novo quando o diff toca modo ou caminho no git
