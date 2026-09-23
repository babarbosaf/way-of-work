---
status: vigente
prd: PRD.md#1-visão-geral
---

# CONVENTIONS: way-of-work

> **Papel deste doc.** O como se constrói: stack, padrões de implementação e
> regras obrigatórias. Depende do [`PRD.md`](PRD.md), que carrega o
> comportamento e o contrato de cada domínio.

## 1. Stack

| Camada | O que roda | Por quê |
|---|---|---|
| Scripts | bash 3.2, o que vem no macOS | reescrever pra bash 5 exigiria dependência que a máquina nova não tem |
| Hooks e lints | python3 da distribuição, sem pacote externo | hook que precisa de `pip install` não roda na primeira sessão |
| Dado estruturado | `jq` | fusão de policy e leitura de saída de ferramenta |
| Testes | bash puro, sem framework | a suíte roda em qualquer terminal, sem instalar nada |

Só `python3` e `jq` são necessários. O resto do que o repositório declara
(`context7`, `rtk`, plugins) é opcional, e a ausência de cada um tem consequência
escrita na tabela de pré-requisitos do README.

**Segredo nunca é versionado.** O `.gitignore` é allowlist: ignora tudo (`*`) e
libera por `!` arquivo a arquivo. Arquivo novo que precisa subir entra nessa
lista no mesmo commit, senão ele não existe pra quem clona.

## 2. Regras do projeto

- **Nome de ferramenta externa mora num arquivo só**, o adaptador dela (hoje o
  multiplexer, em `scripts/herdr-adapter.sh`), e um assert da suíte varre os
  demais scripts pra provar isso. Trocar de ferramenta é reescrever um arquivo.
- **Policy é dado, nunca julgamento na hora.** Cascata, cota, prazo, teto de
  prompt e elegibilidade vivem em `config/model-policy.json`. Script que crava
  número próprio diverge do outro ponto de chamada sem ninguém ver, e a suíte
  cobra a ausência de duração cravada.
- **Override pessoal funde, não substitui.** `config/*.local.json` é gitignored e
  entra por `jq -s '.[0] * .[1]'`. Todo consumidor lê a policy fundida. Quem lê a
  base onde o veredito mora no override discorda do outro lado sem avisar.
- **Estado de fora se lê com três resultados, não dois.** Vazio, cheio e
  ilegível. Tratar ilegível como vazio já apagou todos os registros de sessão
  numa varredura, e o gêmeo do mesmo bug criava grupo duplicado a cada abertura.
- **Log grava caminho, nunca conteúdo.** Vale pro log de despacho e pro de
  sessão.
- **Nada de nome de cliente no repositório**, nem em fixture. Cobra:
  `tests/agnostico.test.sh`.

## 3. Shell

- `set -uo pipefail` é o default. `set -e` só onde o script é uma sequência
  linear sem condicional, porque em script com ramo ele mata o caminho normal.
- **`local` só dentro de função.** Em escopo global falha em runtime e o script
  segue, então o caminho feliz precisa de assert de stderr vazio pra pegar isso.
- **Último comando condicional decide o rc do script.** Varredura que não achou
  nada sai 1 sem um `exit 0` explícito, e todo gancho encadeado lê a varredura
  saudável como falha.
- **`exec` pula o `trap` de limpeza** e troca o pai do processo chamado. Onde o
  pai importa, ou onde há temporário pra apagar, não se usa.
- **Valor que vai pro shell de outra máquina vai citado e escapado.** O que a
  ferramenta de terminal recebe é texto, não uma lista de argumentos, então aspa
  simples dentro do valor precisa de tratamento.
- **Caminho vindo de fora se valida na porta.** Nome que vira componente de
  arquivo recusa barra, `..` e hífen inicial, e o consumidor final sanitiza de
  novo, porque registro editado à mão não pode escrever fora da pasta.

## 4. Testes

A suíte são 11 arquivos `tests/*.test.sh` mais o verificador de links, rodados
por `tests/run-all.sh`. Nenhum toca a rede ou uma CLI real. O que precisa de
binário externo usa stub no `PATH`, e o único cenário que abre sessão de verdade
declara como se pula.

Padrão de arquivo: `TMP=$(mktemp -d)` com `trap` de limpeza, contadores `PASS` e
`FAIL`, e as funções `ok` e `fail`. Cada bloco abre com `echo "== assunto =="`.

- **Suíte isola o estado que ela varre.** `DELEGATE_GATE_DIR` aponta pro
  temporário, senão os testes apagam registro real de quem os roda.
- **RED se prova por mutação.** Assert que passou de primeira ou é um comportamento
  que já existia, ou é vacuoso. Provar significa quebrar o código de propósito e
  ver o assert ficar vermelho.
- **Fixture não pode tornar a condição sempre verdadeira.** Um fixture que parte
  do epoch faz qualquer prazo finito vencer, e o assert do prazo deixa de medir o
  prazo.
- **O assert espia a peça que a guarda muda.** Observar uma que fica calada de
  qualquer jeito não separa a guarda existir da guarda não existir.

## 5. Processo

Antes de propor commit:

- [ ] `git status --short` na árvore principal, inclusive depois de `git mv` ou
      `git rm`, que deixam resíduo em stage e produzem commit misto.
- [ ] `bash tests/run-all.sh` em execução própria, nunca encadeada a um filtro de
      saída: o filtro devolve zero com a suíte vermelha.
- [ ] Lint do que foi tocado: `check-docs.py` pra doc de raiz, `check-spec.py`
      pra spec e ticket, `check-writing.py` pra texto que outra pessoa lê,
      `check-skill.py` pra skill.
- [ ] Mensagem que explica o porquê. O diff já mostra o quê.
- [ ] Parar antes do push.

Commit de correção se revisa dobrado, e se procura o gêmeo. Numa revisão
adversarial de três rodadas desta base, todo achado alto estava no que tinha
acabado de ser tocado.

## 6. Índice de ADRs

| ADR | Decisão | Status |
|---|---|---|
| [0002](docs/adrs/adr-0002-camada-de-sessoes.md) | a camada de terminal escreve, num caminho só, quando pedida | aceita |
| [0001](docs/adrs/archive/adr-0001-camada-de-terminal.md) | a camada de terminal só lê | substituída pela 0002 |

## Relacionado

- [`PRD.md`](PRD.md) consome deste doc a regra universal de construção; o
  contrato de cada domínio mora na seção dele no PRD.
