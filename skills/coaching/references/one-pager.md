# One-pager

O documento que registra **a escolha**: por que esta opção e não as outras. Não descreve o que
o projeto é (isso é PRD, CONVENTIONS, ROUTES, DESIGN) nem o contrato de uma feature (isso é
spec). Vem antes de ambos, e morre quando você executa.

Salvar em `docs/one-pagers/<slug>.md`, aberto assim que o trilho for declarado.

**Teto de uma página.** Estourou, o trilho estava errado: promove pra `/spec-and-plan` ou
`/kickoff-project`.

**Fronteira com doc vivo.** O one-pager **cita e aponta**, nunca duplica. Projeto que já tem
PRD: referenciar a seção, não recontar.

---

## Núcleo (sempre)

### Problema / Resultado

Bullets. Problema é o que dói hoje. Resultado é como se reconhece o sucesso, em nível alto,
sem amarrar solução.

**Disciplina de evidência.** Depois de escrever cada linha, perguntar: *quem disse isso, e
onde?*

- Rastreia até uma fala do usuário ou até um número medido: fica, com a origem citada.
- Decorre direto do que ele disse: fica, marcado como inferência, com o raciocínio à vista.
- Não rastreia até nada: **corta**. Dor plausível que ninguém sentiu é a forma mais cara de
  errar, porque ela sobrevive a todo o resto do documento.

**Menos sobre / Mais sobre** (opcional): duas listas simétricas, quando existe uma direção
plausível-mas-errada que alguém pegaria lendo só o problema. O sinal é você já ter dito na
conversa "não é sobre X". Ninguém traçou essa linha, a seção não é necessária.

### Requisitos

Numerados, com status. Teto de 9 no topo: passou disso, agrupar em R3.1, R3.2.

| Req | Requisito | Status |
|-----|-----------|--------|
| R0 | ... | Objetivo central |
| R1 | ... | Obrigatório |
| R2 | ... | Em aberto |

Status possíveis: `Objetivo central`, `Obrigatório`, `Desejável`, `Em aberto`, `Fora`.

Requisito diz **o que é preciso**, nunca se algo satisfaz. Satisfação só aparece na comparação.

### Opções

2 a 3, mutuamente exclusivas, com título que caracteriza a abordagem, não "Opção A: a solução".

**ATUAL é nome reservado** para o estado das coisas hoje. Quando o tema é evoluir algo que já
existe, descrever ATUAL como uma opção nomeada e colocá-la na comparação junto das outras. Duas
coisas saem disso: uma linha de base para medir o ganho, e a chance de a sessão terminar cedo
porque o que existe já satisfaz. Evoluir vence criar.

#### Notação

| Nível | Notação | Significa | Relação |
|---|---|---|---|
| Requisito | R0, R1, R2 | o que é preciso | membros do conjunto R |
| Opção | A, B, C, ATUAL | um caminho inteiro | escolhe **uma** |
| Parte | A1, A2 | peça da opção | **combinam** dentro da opção |
| Sub-parte | A1.1, A1.2 | detalhe da peça | combinam |
| Variante | A3-a, A3-b | jeitos de fazer a mesma parte | escolhe **uma por parte** |

A notação persiste como trilha de auditoria. Opção composta se escreve por referência:
**Opção D = A1 + B2 + A3-b**. Assim dá pra reconstruir de onde cada peça veio, três sessões
depois.

#### Partes

| Parte | Mecanismo | ⚠️ |
|-------|-----------|:--:|
| A1 | ... | |
| A2 | ... | ⚠️ |

- **Parte é mecanismo**, o que se constrói ou se muda. "Tipos não mudam" é restrição e pertence
  a R, não a uma parte.
- **⚠️** = você descreveu **o quê** mas não sabe **como**. Cedo, na exploração, é normal ter
  vários. A opção escolhida termina sem nenhum, ou com uma sondagem aberta para cada.
- **Sem tautologia.** R diz a necessidade, a parte diz o mecanismo. Copiou o texto de R para
  dentro da opção, a parte não informa nada.
- **Fatia vertical, não camada.** Agrupar "modelo de dados" numa parte separada esconde o que
  cada pedaço custa. Cada parte carrega o mecanismo **e** o dado de que ele precisa.
- **Repetiu, extrai.** Mesma lógica em duas partes vira parte própria, e as outras apontam
  para ela ("A2: ... → chama A1"). Vale para software e para processo.

### Comparação

| Req | Requisito | Status | ATUAL | A | B |
|-----|-----------|--------|-------|---|---|
| R0 | ... | Objetivo central | ❌ | ✅ | ✅ |
| R1 | ... | Obrigatório | ✅ | ✅ | ❌ |

**Notas:** só as reprovações, uma linha cada.

Regras:
- Binária. Só ✅ ou ❌, sem meio-termo e sem comentário na célula.
- **⚠️ reprova.** ✅ é afirmação de conhecimento: dizer que a opção satisfaz o requisito exige
  saber o mecanismo. Descreveu o desejo, não sabe construir, é ❌.
- Requisito sempre por extenso, nunca abreviado.
- Passou em tudo e ainda parece errado: **falta um requisito**. Nomear como novo R e rodar de
  novo. Esse requisito costuma ser o mais importante do documento, porque era o implícito.

**Comparação escopada.** Para decidir entre variantes de uma parte, mesma tabela, só as
variantes daquela parte nas colunas, e só os requisitos que aquela parte toca nas linhas.

### Escolha e destino

A opção, em uma linha o porquê, e para onde vai: código direto, `/spec-and-plan`,
`/kickoff-project`, executar no meio certo, ou não fazer.

---

## Sondagem

A saída do ⚠️. Investigação curta que troca "não sei como" por "sei os passos". Sem ela, a
regra de que ⚠️ reprova vira beco sem saída.

Vale abrir sondagem quando o ⚠️ está numa opção que você **quer** escolher. ⚠️ em opção que já
perdeu por outro motivo não merece trabalho.

```markdown
## Sondagem A2: [título]

**Contexto:** por que precisamos saber isso.
**Objetivo:** o que queremos aprender.

| # | Pergunta |
|---|----------|
| A2-P1 | ... |
| A2-P2 | ... |

**Pronto quando:** conseguirmos descrever [o entendimento].
```

- **Pergunta sobre mecânica**, nunca sobre esforço. "Onde fica a lógica de X?", "o que precisa
  mudar para Y?", "que restrições afetam Z?". Fora: "isso é difícil?", "quanto tempo leva?",
  e sim/não que não revela mecanismo.
- **Pronto quando** descreve o **entendimento**, não a conclusão. "...conseguirmos descrever os
  passos para integrar X" ✅. "...conseguirmos decidir se vale" ❌: decisão vem depois da
  sondagem, com a informação na mão.
- **Investigar antes de propor.** A sondagem às vezes revela que o sistema já faz aquilo.
- Sondagem longa vai para arquivo próprio, `docs/one-pagers/<slug>-sondagem-A2.md`, e o
  one-pager só linka. O teto de uma página continua valendo.

---

## Blocos por gatilho

Entram só quando o gatilho dispara. Nenhum é obrigatório.

| Bloco | Origem | Entra quando |
|---|---|---|
| **Regras exatas** | PRD | a escolha tem números, limites, cadências. Tabela, não prosa. |
| **Casos de borda** | PRD | existe borda que muda a escolha, não toda borda imaginável |
| **Pontos a definir** | PRD | sobrou coisa aberta que não impede decidir |
| **Mapa de lugares** | ROUTES | tem navegação ou estrutura: telas, páginas, seções |
| **Stack e padrões** | CONVENTIONS | a escolha amarra técnica |
| **Superfície visual** | DESIGN | **só nomear e chamar `design-workflow`.** Nunca detalhar aqui. |
| **Referências** | pesquisa | houve pesquisa: links, repos, produtos comparáveis, doc de lib |

---

## Comunicação durante a sessão

- **Tabela inteira, toda rodada.** Requisitos, partes, comparação. Resumo esconde detalhe e
  tira a decisão do dono.
- **🟡 no que mudou**, no começo da célula. O usuário não deve ter que diferenciar de cabeça.
- Uma pergunta ou bloco por mensagem. Nunca despejar a lista.
