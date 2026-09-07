# Autoria de skill

Uma skill tem dois orçamentos diferentes, e confundir os dois é o que estraga a
organização. O `name` e a `description` ficam carregados o tempo todo, em todas as
sessões, e é só com eles que o agente decide se a skill é relevante. O corpo do
`SKILL.md` entra inteiro no contexto quando a skill dispara. O resto do diretório
custa zero até alguém abrir o arquivo.

Daí a régua: a description existe pra ser escolhida, o corpo existe pra ser lido inteiro,
e a referência existe pra ser aberta quando a rodada precisa dela.

## A régua

| Item | Limite | Falha |
|---|---|---|
| `name` | minúscula, número e hífen, até 64 chars, sem palavra reservada, igual ao diretório | bloqueia |
| `description` | até 1024 chars, terceira pessoa, o que faz mais quando usar | bloqueia, exceto o gatilho, que avisa |
| Corpo do `SKILL.md` | até 500 linhas | bloqueia acima de 500, avisa acima de 400 |
| Link relativo | tem que resolver | bloqueia |
| Profundidade de referência | um nível a partir do `SKILL.md` | bloqueia |
| Caminho | barra normal, nunca invertida | bloqueia |
| Referência acima de 100 linhas | índice no topo | avisa |
| Referência não citada pelo `SKILL.md` | entra na navegação ou sai | avisa |

`python3 scripts/check-skill.py --todas skills/` aplica tudo isso. Exit 0 limpo, 1 com
bloqueante, 2 erro de uso. A suíte é `tests/skill-lint.test.sh`.

Duas regras merecem o porquê. **Profundidade de um nível** existe porque o agente lê
arquivo referenciado dentro de arquivo referenciado por partes, com `head`, e fica com
informação pela metade sem perceber; toda referência sai do `SKILL.md`. **Índice acima de
100 linhas** existe pelo mesmo motivo: leitura parcial precisa ver o escopo do arquivo
antes de decidir se lê o resto.

## Onde cada coisa mora

| Lugar | O que é |
|---|---|
| `SKILL.md` | o fluxo, os passos, e a navegação pro resto. Quem lê só isso já executa o caminho comum |
| `references/` | o que a maioria das rodadas não abre: catálogo, checklist longo, anatomia de artefato |
| `references/exemplos/` | amostra de artefato pronto. É molde, não referência: índice enfiado no meio estragaria a amostra, e o linter isenta |
| `fixtures/` | entrada de teste. Quem consome é a suíte, não o agente, e o linter isenta da navegação |
| `scripts/` | passo com resposta única dado o input. Vem com teste vizinho |
| `assets/` | arquivo que a skill copia ou preenche, e não lê |

## Quando quebrar em arquivo novo

Quebrar tem custo: cada arquivo é uma decisão de navegação a mais, e referência que
ninguém abre é dívida. Então vale quando o corpo passou do teto, quando o conteúdo é de um
domínio que a maioria das rodadas não usa, ou quando ele é consultado por busca e não por
leitura, como catálogo e tabela de padrões. Não vale por simetria, nem pra deixar o
`SKILL.md` bonito.

Duas formas de organizar referência funcionam. Por domínio, quando as rodadas são
exclusivas entre si: `reference/finance.md` e `reference/sales.md`, e a rodada abre uma. Por
profundidade, quando é o mesmo assunto em dois níveis: o caminho comum no corpo, o caso
raro na referência.

## Grau de liberdade

Combine a especificidade com a fragilidade do passo. Passo com muitos caminhos válidos vai
em prosa e deixa o julgamento no agente. Passo com um padrão preferido vai em pseudocódigo
ou script com parâmetro. Passo frágil, em que consistência importa mais que adaptação, vai
em script com comando exato e a ordem declarada. Script na skill sempre vem com teste, e o
`SKILL.md` diz se é pra executar ou pra ler como referência, porque as duas coisas pedem
tratamento diferente.

## O que o linter não julga

Ele mede forma, não conteúdo. Fora do alcance dele: se a skill resolve um problema real, se
o passo está na ordem certa, se o exemplo é concreto, e se existem avaliações. Isso continua
sendo trabalho de quem escreve e de quem revisa. A régua oficial pede pelo menos três
cenários de avaliação por skill, escritos antes da documentação extensa, e teste com os
modelos que vão usar a skill de fato.

Nome em gerúndio também fica fora. A recomendação oficial prefere `processing-pdfs` a
`pdf-processing`, e aceita as duas; aqui o nome do diretório é o comando que se digita, e
renomear quebra o hábito de quem usa. Nome novo nasce no formato recomendado, nome existente
não muda por estética.

## Fonte

[Skill authoring best practices](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices),
que é a fonte dos limites de 500 linhas, 100 linhas, 1024 caracteres e do desenho de
progressive disclosure. Quando a doutrina oficial mudar, o linter muda com ela, e este doc
registra o que a gente decidiu por cima dela.
