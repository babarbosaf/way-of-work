# Changelog

Formato [Keep a Changelog](https://keepachangelog.com/pt-BR/1.1.0/);
versionamento [SemVer](https://semver.org/lang/pt-BR/).

## [Unreleased]

### Added

- **`scripts/bootstrap-common.sh`, a convenção compartilhada dos bootstraps.** Flags,
  pré-requisito de manifesto e banner de dry-run viviam em cópia nos dois
  `bootstrap-*.sh`, e o banner aparecia quatro vezes como literal. O dono mandou
  resolver antes da 3ª repetição, que é a régua do `AGENTS.md`: agora o `-h` de cada
  script imprime o cabeçalho dele e a linha de uso nomeia quem foi rodado, os dois
  saindo da pilha do `BASH_SOURCE`, com teste pra cada um desses modos de falhar.
- **`check-links.py` passou a cobrar caminho de script citado em code span.** O repo
  mantém dois caminhos válidos pro mesmo arquivo, o canônico dentro da skill e o symlink
  em `scripts/`, e o modo de falhar é um doc citar o curto onde o symlink não existe. O
  lint aceita qualquer um dos dois e só reclama quando nenhum resolve. Achou o primeiro
  caso na hora: `scripts/check-writing.py` era citado e não existia, e ganhou o symlink.
- **A prateleira de modelos virou dado, e o review passou a espelhar a sessão.** A
  `model-policy.json` ganhou `review_shelf.models` (lista fechada de quem pode revisar),
  `suggested_effort` (esforço por modelo, porque cada um roda no sugerido dele e não no
  máximo que aceita) e `review_pairing`, que reordena a cascata de review pela classe da
  sessão master: em Fable revisa o par de classe topo, em Opus revisa o par de classe
  forte. Antes a fila era fixa, e quem trabalhava em Fable recebia review de uma classe
  abaixo. O `delegate.sh` resolve a classe lendo o `settings.json` do `CLAUDE_CONFIG_DIR`,
  e `DELEGATE_SESSION_CLASS` sobrepõe, porque `/model` em runtime não reescreve o arquivo.
- **Backend `claude` como último degrau de toda cascata.** `claude -p` headless na mesma
  assinatura da sessão, com esforço por flag (`--effort`), então o master deixa de ser o
  único fallback e passa a ser o fallback real, depois do plano. Ele compra contexto
  isolado e não resiliência de cota: quando o balde seca, a sessão e o headless falham
  juntos. Toda invocação de backend roda sob `env -u ANTHROPIC_API_KEY`, e um teste prova
  que a chave não chega ao worker, porque com ela setada o headless cobraria da API em vez
  do plano.
- **`--tier padrao|amplo` no dispatch, e `tier:` no ticket.** Tamanho de ticket deixou de
  virar task-type novo: o tier troca só o ponto de entrada da mesma fila, resolvido como
  `.tiers[task][tier] // .tasks[task]`. A classificação é mecânica no `to-tickets`, com
  padrão até 5 arquivos próprios sem tocar contrato e amplo tocando contrato ou passando
  de 5. O `check-spec.py --tickets` cobra o campo em todo ticket cujo `delega:` tem tier na
  policy, e a métrica que recalibra o 5 é retrospectiva: ticket que estourou o timeout ou
  voltou pro master no meio era amplo.
- **`dur_s` no `delegate.log`.** O log gravava bytes e nenhum tempo, então todo número em
  `.timeouts` era cronômetro na mão. Agora cada chamada grava a duração, e os timeouts se
  recalibram com dado.
- **`design-workflow` vira roteador, e a stack de design passa a ser externa.**
  A skill deixa de carregar doutrina de craft e nomeia o dono de cada passo: plugin
  `impeccable` (`shape`, `live`, `distill`, `critique`, `audit`, `polish`, `harden`,
  `extract`, `document`), skill `shadcn` do plugin vercel para componente e tema, MCP
  `mobbin` para referência real no passo de referência, `DesignSync` para a base
  canônica. Figma sai do loop: a tentativa de usar não pegou, e referência de fora entra
  por print ou pelo Mobbin. Fica aqui só o que não tem dono externo: classificar papercut,
  fechar constraint, loop-back, veredito e registro. shadcn passa a ser a base de
  componente (primitivo do registry; nosso lado é token semântico e composto), e o
  passo de showcase, que nenhum projeto seguia, vira "isolado antes da tela real" na
  ordem do que o repo já tem.
- **Escopo por plugin no manifesto.** `escopo: project` sai como `--scope project` no
  comando de install, porque plugin que serve um repo não precisa custar contexto no
  perfil inteiro. `vercel` passa a ser o primeiro caso: 35 skills e ~4k tokens always-on
  para usar uma (`shadcn`), então ele entra no repo que tem UI, não em toda sessão.
- **O repo se instala como plugin.** `.claude-plugin/marketplace.json` e
  `.claude-plugin/plugin.json` declaram o `way-of-work` como plugin de skills, então
  máquina que não clona isto como diretório de configuração instala com
  `claude plugin marketplace add` mais `claude plugin install`. Só as skills viajam:
  hook, script e `config/` dependem de caminho e de `settings.json`, e continuam vindo do
  clone. Seis asserts em `tests/plugins.test.sh`, incluindo o que cobra que toda skill
  distribuída esteja versionada.
- **A régua de skill adota o limite do empacotador oficial.** `description` com `<` ou
  `>` passa a bloquear no `check-skill.py`, porque o `quick_validate.py` do
  `skill-creator` recusa a skill por isso; `delegate` e `remove-dumb-comments` perderam os
  placeholders em `<>` sem perder o gatilho. O parser de frontmatter parou de contar o
  indicador de bloco (`|`, `>-`) como valor, que era falso positivo em três skills, e a
  varredura passa a pular diretório que o git ignora, porque `skills/synced/` é cache do
  harness e não skill quebrada. `argument-hint` e `disable-model-invocation` ficam como
  estão: são válidas no Claude Code, e a segunda é o que mantém `/execute` fora do
  alcance do modelo.
- **`bootstrap-plugins.sh --update` e bloco `mcp` no manifesto.** `--update` puxa
  upstream do que já está instalado (`marketplace update` + `plugin update`) sem
  instalar nada; o bloco `mcp` declara servidor remoto (`url`) e local (`command`) e
  gera o `claude mcp add` no escopo `user`. `config/plugins.json` passa a declarar
  `impeccable`, `vercel`, e os MCP `shadcn` e `mobbin`.

- **Padrão de documentos, e os quatro lints que o cobram.** `docs/doc-standard.md`
  deixa de falar só de `AGENTS.md` e `README.md` e passa a reger PRD e subdocs,
  decisão, backlog e handoff, com cada regra nomeando o comando que a aplica.
  `scripts/check-docs.py` ganha os quatro modos: `--estado` (doc de estado fala do
  presente; o sinal é data em heading, não a palavra "histórico" no corpo),
  `--grafo` (todo domínio do PRD se cita de volta, link resolve, âncora existe),
  `--ciclo` (ADR e DDR vivem enquanto o status é vivo; superado vai pro `archive/`,
  e ponteiro que sobra bloqueia) e `--decay` (handoff, inbox, pool e feedback com
  prazo e teto). `scripts/check-spec.py --chain` fecha a corrente PRD, spec, ticket:
  `prd:` com âncora, aceite com `AC-NN`, `closes:` no ticket, nenhum aceite órfão,
  `harvest:` na spec entregue e a invariante de estágio único, que é item promovido
  sair do backlog sem deixar rastro. Suítes `docs-lint` e `spec-lint`.
- **Cláusula de não-adoção no `--grafo`.** Raiz sem `PRD.md` e sem `docs/prd/` é repo
  que não instancia produto, não repo com doc faltando: o check sai limpo, como o
  `--ciclo` já fazia sem árvore de decisão. Subdoc de `docs/prd/` sem índice continua
  achado, porque aí o padrão foi adotado pela metade.
- **Lente por área tocada no `peer-review.sh`.** Além da lista genérica, o prompt de
  diff ganha as perguntas da área alterada: migration puxa perda de dado, auth puxa
  autorização, contrato público puxa compatibilidade, infra puxa ambiente.

### Fixed

- **O `smoke_backends.sh` invocava worker sem remover a `ANTHROPIC_API_KEY`.** A sonda
  chama todo backend habilitado na policy, e o backend `claude` entrou nesta mesma
  rodada, então rodar a sonda cobraria três chamadas de `claude -p` da API em vez do
  plano. A guarda tinha nascido presa ao `delegate.sh`, e não à regra: agora
  `tests/delegate.test.sh` cobra `env -u ANTHROPIC_API_KEY` em todo invocador de
  backend, e não num só.
- **O `-h` dos dois bootstraps imprimia um `set -uo pipefail` solto no fim.** A faixa
  do `sed` passava uma linha do fim do cabeçalho, nos dois, desde que existem. Achado
  pelo teste novo da convenção compartilhada.
- **O log de uso não dizia qual modelo respondeu.** `USED_MODEL` era atribuída e nunca
  lida, e o campo `pool` do codex é `codex` pros quatro modelos dele, então `dur_s` não
  se atribuía a modelo nenhum, que é a pergunta que `dur_s` existe pra responder. O
  modelo entra no `detail`, string livre como o `TRILHA`, e o schema do JSONL não muda.
  Medido com worker real: `{"backend":"codex","pool":"codex","detail":"model=gpt-5.6-luna","dur_s":10}`.
- **Tier que a task não declara era fila padrão calada.** `--tier amplo --task scan`
  resolvia `.tiers.scan.amplo?`, não achava, e caía no padrão sem dizer nada: pedir
  amplo e receber padrão é a divergência que o tier existe pra evitar. Agora é erro de
  uso que nomeia os tiers da policy.

### Removed

- **`second-opinion`, `claude_api` e o backend `gemini` saíram.** O advisor cobre conselho
  e o `review` cobre spec e código, então segunda opinião delegada a modelo abaixo da
  classe do master era rebaixamento, não segunda opinião. O `claude_api` foi com o
  mecanismo genérico de `env_var`/`env_file`/`API_KEY` que existia só pra ele, porque API
  não entra em nenhum backend. Com eles saíram `docs/infra-migracao.md`,
  `docs/autonomy-loops.md` (incorporado em uma linha da `AGENTS.md`) e
  `docs/runbooks/multi-model-dispatch.md`, cujos três fatos únicos foram absorvidos pela
  `skills/delegate/SKILL.md`.
- **`caveman` sai.** Medido: ~1.4k tokens always-on, mais o bloco que o `SessionStart`
  injeta e o rastreador a cada prompt, perto de 2k por sessão. O que ele entrega no nível
  `lite` é o que o output style `Concise` já faz, e a doutrina de brevidade mora na skill
  `writing`; os níveis que justificariam o plugin derrubam artigo e esbarram no requisito
  de bom português. Os três agentes `cavecrew` duplicavam `Explore` e `general-purpose`.
  A memória que regia qual skill dele usar foi apagada no mesmo movimento.
- **Um validador de skill só.** `skill-doctor` sai por duplicar o `check-skill.py` e o
  `quick_validate.py` sem acrescentar regra. Junto dele saíram `cloudflare`, `eli5`,
  `diagram-design`, `notion`, `slack` e `linear`, instalados e desligados havia meses, e
  as entradas de escopo project que apontavam pra repositório que não existe mais.

### Changed

- **`padrao|amplo` deixou de ser literal de script.** O conjunto de tiers válidos era
  hardcoded em três lugares (a policy, o regex do `delegate.sh` e uma tupla no
  `check-spec.py`) sem nada obrigando os três a concordar, que é a lista gêmea contra a
  qual o `$comment` da própria policy avisa. Os dois consumidores agora derivam de
  `tiers.<task>` mais o `padrao` implícito.
- **A classe da sessão saiu do `case` e virou chave de policy.** `session_class()`
  casava `*fable*` e `*opus*` literalmente, um terceiro lugar onde o nome de uma classe
  morava; agora percorre as chaves de `review_pairing`, e classe nova entra editando só
  a policy.

- **Skill deixou de carregar histórico de mudança.** Data de decisão e narrativa de "o
  que morreu quando" saíram da `skills/delegate/SKILL.md`, da matriz de modelos e dos
  `$comment` da policy: skill é o estado presente do que ela é e de como funciona, e o
  histórico é o git, o `CHANGELOG.md` e o `FEEDBACK.md`. Data de **medição** ficou, porque
  é parte do fato e é o que diz quando ele decai.
- **O ticket ganhou limite negativo.** O `to-tickets` passou a pedir uma frase de "não
  toca X" dentro do `O que construir:`. O ticket é lido junto com o `AGENTS.md` do repo e
  o contrato de report do `delegate`, então ele não repete convenção; o que faltava era o
  limite que impede o worker de melhorar o que ninguém pediu.
- **D-01 mudou de sentido: plano de tarifa fixa primeiro, na ordem de qualidade.** A regra
  antiga era "custo marginal zero antes da sessão Claude", o que punha o agy grátis na
  frente de tudo. Só que a cota do agy é baixa e a do plano já está paga, então o que se
  gasta no codex e no `claude -p` é janela, não dinheiro. O agy virou válvula de excedente,
  e não degrau de volume. Em `implement` o codex segue na frente do Claude por ordem
  provisória: cascata só desce por falha, então Claude primeiro, sem gate de orçamento por
  bucket, queimaria cota Claude em todo ticket e o codex nunca seria alcançado. A ordem
  vira no mesmo commit que trouxer o gate.
- **`scan` e `boilerplate` continuam dois, agora com motivo escrito e teste.** As cascatas
  são idênticas de propósito, e o que separa os dois é uma guarda de código: em modo bulk o
  `boilerplate` exige `--reference`, senão o worker gera código sem padrão a seguir. O
  task-type é o único portador dessa intenção, porque `--paths` mais `--question` não diz
  se é varredura ou geração. Um teste passou a falhar se as duas cascatas divergirem.
- **O bypass do RTK sai do wrapper e vira contrato versionado.** O binário subiu de
  0.40.0 pra 0.49.0, e `scripts/rtk-hook-wrapper.sh` encolheu de 40 linhas para a única
  coisa que só ele faz: sair limpo quando o `rtk` não está no PATH. O regex que listava
  `cat`, `head` e `git commit` casava só o começo da linha e deixava passar `FOO=1 cat x`,
  `uv run pytest` e segmento de pipe; o RTK casa a forma peeled desde a 0.47, então a
  lista passou a morar em `config/rtk.json` e é aplicada no `config.toml` dele por
  `scripts/bootstrap-rtk.sh` (dry-run por default, `--update` puxa o upstream). `git add`
  entrou na lista por medida: `rtk git add -n .` devolvia vazio com cinco arquivos a
  stagear, um dry-run que mente. Sete asserts novos em `tests/hooks.test.sh`, incluindo o
  que cobra a igualdade entre manifesto e config ativa, e o que prova que o wrapper sem
  `rtk` no PATH não deixa o harness com rc=141. `bootstrap-plugins.sh` passa a delegar
  pro `bootstrap-rtk.sh` com as mesmas flags, então o que vem de fora atualiza num
  comando só, e a suíte de plugins ganhou mocks de `rtk` e `brew` pra não tocar a
  máquina. O doc não apodrece em silêncio: `versao_medida` no manifesto e dois asserts
  que remedem o que `docs/rtk.md` afirma (`rtk read` == `cat` em bytes, `rtk git add -n`
  vazio) derrubam a suíte quando o binário muda, e a saída diz o que remedir.
- **`specs/` e `docs/research/` saem do versionamento.** São trabalho desta máquina, não
  doutrina transferível: o que decidem já vira instrução em `docs/` e `skills/`, e o resto
  fica no git local. `docs/research/context7.md` virou `docs/context7.md`, porque o
  `AGENTS.md` o cita como instrução e ele precisa viajar com o repo. Sai também a linha do
  `specs/_TEMPLATE-spec/` no README: a doutrina viva põe spec em `docs/specs/<slug>/`, e
  nenhum script ou skill apontava mais pro template da raiz.

- **O quadrante vazio do roteamento ganhou portão.** `to-spec`, `to-tickets` e
  `execute` excluíam, cada um com essas palavras, a "tarefa que cabe numa sessão e
  vai direto pro código": as skills eram mutuamente excludentes e não coletivamente
  exaustivas, e a maior fatia do trabalho ficava sem gate. Pedido de *como*, com o
  *quê* já fechado e mais de uma forma defensável, passa a rotear pro plan mode, onde
  cada passo nomeia arquivo tocado, o que prova e o que foi descartado, e a edição
  fica travada até a aprovação. Plano que passa de 5 passos, ou que alguém quis
  salvar, é spec. A exclusão do `coaching` fechou a metade que faltava: escopo
  pequeno demais pra spec, com só a rota aberta, não vira one-pager.
- **Um template de ticket só.** O bloco do `to-tickets/SKILL.md`, que é o default de
  projeto sem tracker, não tinha `Contexto:` nem `spec:`, enquanto o de tracker tinha
  os dois: ticket de arquivo era beco sem saída pra agente frio. O conjunto de campos
  passa a ser um, com `spec:` e `closes:` obrigatórios, e o reference guarda só o que
  o tracker acrescenta.
- **PRD não é decision log.** A anatomia do PRD mandava escrever "decisões
  estratégicas registradas" com racional e data, e o PRD de exemplo ensinava a seção.
  A escolha difícil passa a virar restrição no presente, na seção que possui o
  assunto; o racional caro de reverter mora no ADR, e a deliberação mora no git.
- **`docs/higiene-docs.md` virou `docs/doc-standard.md`.** O nome antigo descrevia o
  sintoma.
- **Handoff declara quando morre.** `Morre em:` em ISO no cabeçalho, default 14 dias,
  cobrado pelo `--decay`. A regra "substitui, não acumula" era prosa, e prosa não se
  executa: a varredura achou 57 handoffs vivos em `_tmp/`, 38 deles vencidos.

### Added

- **`/execute`: do ticket à PR única.** Skill user-invoked que fecha o ciclo
  `to-spec → to-tickets → execute`. Brief transiente em `_tmp/execute/<slug>.md`
  (argumento livre ou até 4 perguntas), `resolve-context.py` que trava sem spec,
  ticket ou `verify_cmd` real, worker externo por ticket marcado (`smoke_backends.sh`
  sonda antes; sem worker, inline, nunca subagente Claude), ticket e spec atualizados
  a cada passo, `/simplify` sugerido a partir de 6 tickets com veto do dono, ticket de
  QA Manual com cenários MECE e veredito por cenário, uma PR por rodada. Regra
  atualizada em `AGENTS.md`, `git-workflow-and-versioning` e `to-tickets`: 1 ticket ou
  1 `/execute` = 1 worktree = 1 branch = 1 PR. Suíte `tests/execute-context.test.sh`.
- **Shunt de leitura: o corpus vai pro worker grátis, e só a resposta volta.** Modo
  bulk no `delegate.sh` (`--paths` mais `--question`), que monta pergunta, corpus em tag
  `<file path="...">` e contrato de saída em bullets. Medido end-to-end contra worker
  real: 53.422 bytes de corpus viraram 8.000 bytes de resposta, 85% a menos entrando na
  janela, em 42s. A fricção de montar heredoc à mão era o que mantinha esse caminho
  desligado: no `gate/delegate.log`, 211 chamadas de `review` (que o `peer-review.sh`
  dispara sozinho) contra 22 de `scan` e 3 de `boilerplate`. Desenho e medição em
  `docs/research/token-shunt.md`; tickets em `specs/token-shunt/tickets/`.
- **`--reference` obrigatório no boilerplate em modo bulk.** Sem arquivo de padrão a
  seguir, o worker gera código sem contexto que não encaixa em nada, e revisar custa mais
  que escrever à mão.
- **`hooks/bash_read_guard.py`**: o despejo de arquivo grande por Bash (`cat`, `head`,
  `tail`, `less`, `bat`, `rtk read`) apanha igual à leitura por `Read`, e roteia pro
  worker acima do degrau. Leitura apontada continua livre: pipe que filtra, `head -N`
  dentro do teto, redirect pra arquivo. Kill: `BASH_READ_GUARD_DISABLED=1`.
- **`.shunt` na `model-policy.json` e `hooks/shunt_policy.py`**: threshold de leitura sai
  de dentro do hook e vira dado, em dois degraus (`grep_max` 200, `worker_min` 500),
  porque os dois tiers têm latência muito diferente (grep local em ms, worker em 10 a
  30s). Override por sessão: `SHUNT_GREP_MAX`, `SHUNT_MIN_LINES`.
- **`bytes_in`/`bytes_out` no `gate/delegate.log`.** Sem tamanho, "quanto o shunt
  economizou" não tem resposta e o degrau se calibra por palpite.

- **`to-spec` e `to-tickets`** substituem `spec-and-plan` (arquivada em
  `skills/_archive/`). A spec fundia contrato, design e execução num arquivo só;
  agora a spec guarda o contrato e as decisões `D-NN`, e o ticket guarda o que um
  agente frio precisa pra executar: `files:` (ownership), `blocked_by:`,
  `delega:`, `verify:` e aceite em checkbox.
- **Lint de spec e ticket** (`scripts/check-spec.py`, 23 asserts em
  `tests/spec-lint.test.sh`). Checa sintoma, não tamanho: o que separa uma spec de
  270 linhas de uma de 1700 são as seções que não deviam estar lá. Achado bloqueia; `aviso:` só informa. Nos tickets, cruza os `files:` dos
  `[P]` e acusa disputa de arquivo antes do conflito acontecer.
- **Marcador `[P]` e fases** no fatiamento: `Setup`, `Foundational`, `Slices`,
  `Polish`. `[P]` só onde os `files:` não se cruzam.
- **Suíte dos hooks e do Evaluator** (`tests/hooks.test.sh`, 33 asserts;
  `tests/peer-review.test.sh`, 17). Os cinco hooks de enforcement e o
  `peer-review.sh` não tinham um assert, e são justamente o que o README oferece
  como enforcement e como segunda opinião. Payload JSON no stdin e delegate falso
  em HOME falso: nada sai pra rede, nenhum CLI de modelo é invocado.
- **Pré-requisitos no README**: o que é necessário (`python3`, `jq`), o que é
  opcional (`rtk`), o comando de instalação do context7 MCP que a doutrina exige, e
  os cinco kill switches dos hooks.
- **Guarda de caminho de trabalho privado** em `tests/agnostico.test.sh`. Um hook
  com topologia privada entrou num commit por `git add -A`, e nenhuma regra de
  identidade casava: o tell estrutural é o caminho fora do diretório de config.
- **Skill `writing`** (absorve `docs/research/escrita.md` e `templates/VOZ.md`): doutrina
  de brevidade e naturalidade, catálogo de 31 padrões anti-slop com o substituto de cada
  um (`references/padroes.md`), molde de calibração de voz (`references/voz.md`), pares
  antes/depois reais (`fixtures/`) e um linter (`scripts/check-writing.py`) que ignora
  bloco de código e aponta `arquivo:linha:regra`. Suíte própria em
  `tests/writing.test.sh`. A regra de escopo que faltava está explícita: fragmento é pra
  instrução densa, texto lido de ponta a ponta pede frase conectada.
- **Skill `kickoff-project`** (fork de [iagodemacedo/kickoff-project](https://github.com/iagodemacedo/kickoff-project),
  adaptado): fundação de projeto novo por entrevista dirigida → `PRD.md`,
  `ROUTES.md`, `DESIGN.md`, `CONVENTIONS.md`, `CLAUDE.md`, `AGENTS.md`,
  `FEEDBACK.md`, `TODOS.md`. Adaptações: fase CONVENTIONS na cascata (cisão
  PRD × conventions com regra de fronteira "usuário percebe → PRD"),
  `FEEDBACK.md` com teto e regra de promoção, seção Execução (TDD/YAGNI)
  no AGENTS.md gerado, `STRATEGY.md` opt-in, herança de fundação de design,
  molde de stack default, exemplos Chutaí com `CONVENTIONS.md` novo
  extraído do PRD.

- **Régua de autoria de skill** (`docs/skill-authoring.md`) e o lint que a aplica
  (`scripts/check-skill.py`, 23 asserts em `tests/skill-lint.test.sh`). Mede o que decide
  discovery e progressive disclosure: frontmatter que permite escolher a skill, corpo do
  `SKILL.md` até 500 linhas, referência a um nível do `SKILL.md`, índice no topo de
  referência acima de 100 linhas, link relativo que resolve. Bloqueante trava o gate;
  aviso só informa. Amostra de artefato (`references/exemplos/`, `fixtures/`) fica fora da
  régua de índice e de navegação, porque é molde e entrada de teste, não referência.
- **Índice no topo** das sete referências acima de 100 linhas em `coaching`,
  `kickoff-project`, `to-spec` e `to-tickets`. Leitura parcial (`head`) via de regra não
  alcança o fim do arquivo, e sem índice o agente não sabe o que deixou de ler.
- **Anúncio de trabalho próprio** (`skills/writing/references/padroes.md`, padrões 43 a
  46): crédito abre a mensagem em vez de fechar, esforço não legitima entrega, punchline
  doutrinária fechando parágrafo, e verbo modesto no lugar do verbo de lançamento. Saíram
  da revisão de um anúncio de canal reescrito à mão, onde o texto do agente passava no
  linter e as quatro construções sobreviviam. O par 11 de `fixtures/antes-depois.md` é o
  primeiro de mensagem de chat, e não de doc, e a numeração dos pares volta a ser
  contínua (havia dois `## 6.`).

### Fixed

- **Falha transiente de provider arma cooldown curto, em vez de virar fato na policy.**
  404, "does not exist or you do not have access", 502/503/504 e "overloaded" passam a
  armar 10 minutos (`DELEGATE_TRANSIENT_COOLDOWN_MINS`) no pool, com o backend seguindo
  habilitado. Medido em 07/set/2026: o mesmo `codex exec --model gpt-5.5` respondeu às
  19h06 e devolveu 404 às 19h31, mesma conta e mesmo diretório, com os 7 nomes de modelo
  do CLI acompanhando a janela em bloco. Duas rodadas anteriores escreveram essa janela
  como permanente e apagaram o primeiro degrau de `review`, `second-opinion` e
  `implement`. A regra agora está escrita na skill: `enabled: false` é pra decisão, nunca
  pra sondagem.
- **O timeout de review volta a ser dado da policy.** O `peer-review.sh` cravava
  `--timeout 120` e atropelava `.timeouts.review`. Medido em 07/set/2026: revisão
  adversarial de um diff de 1432 linhas no Gemini 3.1 Pro (High) leva 170s. Estourado o
  timeout, a cascata se esgota e a sessão come a review inline, que é o fallback mais caro
  do sistema; no `gate/delegate.log` isso aconteceu em 90 de 212 chamadas de `review`,
  42%. O valor na policy sobe pra 300, com margem sobre o medido.
- **Quatro bugs de parsing no `bash_read_guard`**, achados pela revisão adversarial da
  própria leva: `;`, `&&` e `||` separam comandos, então filtro num deles não libera mais
  o despejo do vizinho (e heredoc/redirect valem só pro comando em que aparecem); e o
  `-N` de `head`/`tail` e a faixa de `sed -n` são teto **por arquivo**, então
  `head -n 150 a b` conta 300 linhas e `sed -n '1,300p'` num arquivo de 900 roteia pelas
  300 da faixa, não pelas 900 do arquivo.
- **`tests/agnostico.test.sh` volta ao verde**: três ocorrências de identidade do dono
  estavam no `main`, em `docs/auto-memoria.md`, `docs/claude-code.md` e
  `skills/writing/references/voz.md`. Perfil de config agora é `$CLAUDE_CONFIG_DIR`, e o
  exemplo de voz não nomeia ninguém.
- **Worker de worktree escrevia na árvore principal do dono.** O modo worktree
  contava com o sandbox do CLI pra confinar a escrita, e no agy isso é falso: o
  `--sandbox` restringe terminal, não sistema de arquivos, e o agy nem começa no
  cwd (abre na pasta de artefato dele). Uma delegação real deixou o working tree
  do dono meio editado, com um arquivo que compilava e quebraria em runtime.
  Agora são três mecanismos juntos, e nenhum sozinho resolve: `cd` na worktree,
  `--add-dir {worktree}` (placeholder novo, substituído pelo caminho absoluto) e
  o caminho escrito no começo do prompt. O `--sandbox` sai do
  `agy.worktree_invoke`, porque era ele que bloqueava a escrita legítima. O
  protocolo de integração da skill ganhou o passo 0, `git status` na árvore
  principal, que é onde um worker fugido aparece.
- **`trunk` do `project.yaml` com comentário inline não resolvia.** `trunk: main
  # tronco` virava o ref literal `main  # tronco` e o dispatcher morria em
  `--base não resolve`. O awk agora corta comentário e espaço à direita.
- **Timeout do agy caía antes da task terminar.** O `--print-timeout` do agy tem
  default de 5 min, então task de implementação morria no meio sem erro
  atribuível. A policy passa 15 min em one-shot e 30 min em worktree.
- **Nomes de modelo do agy estavam desatualizados na policy.** A cascata pedia
  `Gemini 3.5 Flash`, que o CLI não oferece mais; conferidos contra `agy models`
  e atualizados pra 3.8/3.7/3.6. `boilerplate` passa a preferir Gemini antes de
  GPT-OSS 120B, que é o menos confiável em respeitar o diretório de trabalho.
- **Hook do RTK quebrava em quem clonasse sem o CLI.** `rtk-hook-wrapper.sh` chamava
  `rtk` sem guarda, e o hook está ligado em todo `PreToolUse:Bash`: medido rc=127 e
  `command not found` a cada comando. Agora sai limpo sem o binário, e `docs/rtk.md`
  declara que é opcional.
- **Fallback gracioso do Evaluator não rodava.** Com `set -e`, a chamada ao
  `delegate.sh` abortava `peer-review.sh` antes do bloco de fallback: cascata
  esgotada saía como exit 2 mudo, sem mensagem e sem a linha `unavailable` no
  `usage.log`.
- **Mensagem do hook de memória ensinava errado.** O bloqueio pedia `<op>` e o
  regex aceita só `create|update|delete|lint|ingest`. As ops passam a sair de uma
  tupla única que alimenta regex e mensagem, e o `AGENTS.md` nomeia as cinco.
- **`/simplify` era apresentado como regra genérica** na seção de Testes do
  `AGENTS.md`, sendo builtin do Claude Code. Quem roda outro harness lia regra que
  não tem como executar.

### Changed

- **O bloqueio de leitura roteia, em vez de ensinar a paginar.** Os dois guards passam a
  devolver o comando colável do degrau: entre `grep_max` e `worker_min`, grep mais `Read`
  paginado; acima de `worker_min`, o `delegate.sh --task scan` com os paths já
  preenchidos. Paginar reduz o pico e mantém os tokens na janela cara; rotear troca de
  janela.
- **Leitura de arquivo sai do rewrite do rtk.** `cat`, `head`, `tail`, `less`, `more` e
  `bat` viram bypass no `rtk-hook-wrapper.sh`. Medido em bytes: `AGENTS.md` 5223 vira 5222
  no `-l minimal` e no `-l aggressive`; `delegate.sh` 19432 **cresce** pra 19550 no
  `aggressive`, porque o filtro devolve vazio e o rtk cai pro bruto mais uma linha de
  warning. O default do rewrite era `-l none`, que é 0%, e o `rtk gain` creditava 6914
  chamadas a 25.3% a esse comando: o pior percentual da tabela no maior volume, escondendo
  que o caminho estava descoberto. O rtk fica onde mede bem, na saída de comando.
- **Bulk one-shot não recebe o footer de report de 3 seções**, que pede verify e lista de
  arquivos tocados numa tarefa que não roda nem toca arquivo.
- **Ordem da cascata de `second-opinion`** (`config/model-policy.json`,
  `model-ranking-matrix.md`): passa a liderar com agy Claude Sonnet 4.6
  (Thinking), depois Gemini 3.1 Pro (High), e o codex vai pro fim. Dois motivos
  medidos em 07/set/2026: Claude Opus 4.6 (Thinking) leva 902s e ainda volta
  rc=2 em headless (Sonnet fecha em 26s, Gemini em 30s), e liderar com o mesmo
  backend de `review` fazia a segunda opinião sair do modelo que já opinou.
  Pelo mesmo motivo Opus sai do 3º de `review` na matriz de ranking, e o teste
  de cooldown transiente passa a derivar a task da policy em vez de cravar
  `--task second-opinion`, que testava roteamento sem querer.
- **Deploy tem dois modelos** (`git-workflow-and-versioning`,
  `ci-deploy-flow.md`): automático por push é o default; manual por leva com
  validação em `localhost` entra quando o host cobra por build. Qual dos dois
  vale é decisão de projeto e mora no `CONVENTIONS.md` dele.
- **codex default vai pra gpt-5.5** (`config/model-policy.json`): em
  05/set/2026 o gpt-5.4 devolveu 400 nesta conta enquanto 5.5, 5.3, 5.1-codex
  e 5-codex respondiam. A matriz de ranking acompanha, e os nomes de Gemini
  Flash nela voltam a existir na policy (3.5 não existe; é 3.8).
- **Quarto escopo de brevidade** (`skills/writing/SKILL.md`): mensagem pra uma pessoa num
  canal não é instrução densa, nem texto que se lê de ponta a ponta, nem leitura de
  varredura. Vale a frase conectada,
  e o fecho que pede ação pode repetir o pedido, porque adesão ganha de economia quando
  alguém tem que fazer algo depois de ler.
- **Hedge real sai da conta do vício** (`SKILL.md` na Naturalidade e no self-check 3,
  padrão 24): ressalva que corresponde a dúvida existente é informação, e apagar ela mente
  sobre o que se sabe. O vício é a ressalva empilhada sobre o que já se sabe. Por isso
  `basicamente` fica fora do linter: em PT-BR falado ele abre explicação técnica.
- **O passo 4 aponta pro arquivo de voz preenchido**, e o `references/voz.md` abre dizendo
  que é molde. Ler o molde no lugar do preenchido calibra por inferência sem avisar
  ninguém.
- **Gate de agnosticismo** (`tests/agnostico.test.sh`): a lista de unidade de negócio ganha
  dois nomes de projeto, e o `padroes.md` perde as duas citações que nomeavam um projeto
  real.

- **Worktree e branch** (`git-workflow-and-versioning`): 1 ticket = 1 worktree =
  1 branch = 1 PR, worktree nativo (`claude -w`), SHA congelado na leva, teto de
  3 a 5, merge serializado, branch morrendo no merge. Squash-merge cega o
  `git branch --merged` (SHA novo): a varredura de órfãs passa a usar
  `gh pr list --state merged`.
- **Evaluator adversarial** (`docs/adversarial-evaluator.md`): finding vira
  ticket, nunca seção nova na spec. Spec aprovada é append-only. Era esta linha
  que inflava as specs: 43 arquivos `.round-N.md` e seções `## Resposta ao Round N`
  no corpo.
- **Design ganha constraints, variantes e dois trilhos, e para de jogar wackamole.** O fluxo
  da `design-workflow` era linear: buscava referência na base, gerava um preview, aplicava.
  Nunca escrevia as constraints, nunca gerava alternativa, nunca voltava atrás quando a
  rodada revelava constraint nova. É o processo que Alexander descreve em *Notes on the
  Synthesis of Form* com o passo 3 cortado, e sem ele cada pedido visual é atendido isolado:
  o resultado prioriza umas interações sobre outras sem ninguém ter decidido isso. Agora:
  todo pedido visual entra classificado em **trilho papercut** (fix óbvio na hora, ou linha
  `[papercut]` no `TODOS.md`, que não é executável individualmente e volta como entrada de
  constraint) ou **trilho design**, 12 passos que abrem fechando as constraints e incluem
  3 a 4 variantes fora do codebase (skill `design` pra tela, `artifact-design` pra
  componente), passe de subtração com justificativa obrigatória quando nada foi removido,
  veredito de 1 linha no `FEEDBACK.md` sobre qual variante ganhou e contra qual constraint,
  e um loop-back check explícito. Primeira versão no código real do repo passa a ser
  proibida: ela cria gravidade, e refinar o que já enxertou fácil parece mais barato que
  explorar alternativa. Referência externa deixa de ser opcional, 2 a 3 produtos que
  resolvem problema parecido, salvos em `docs/design/references/<slug>/`.
- **`DESIGN.md` ganha seção Constraints e regra de showcase, e perde o roadmap visual.**
  Tokens diziam *como* pintar e nada dizia *o que precisa caber*, então avaliar proposta
  virava questão de gosto. A nova seção 2 traz três blocos: workflows a suportar em ordem
  de frequência (é essa ordem que autoriza ou nega um "deixa X mais destacado"), estados
  obrigatórios (vazio, carregando, erro, um item, muitos itens, texto longo) e pisos
  invioláveis. Componente novo passa a nascer na rota `/showcase` com dado fake e todos os
  estados visíveis, antes de ser fiado numa tela com lógica em volta. A seção 11, Roadmap
  visual, saiu: estado de aplicação por tela é status volátil e viola a higiene de doc de
  raiz que carrega toda sessão, então vive no `TODOS.md`. `anatomia-design.md`,
  `anatomia-rotas.md` (rota `/showcase` como default) e o exemplo Chutaí acompanham.
- **PR de frontend e de backend se separam, porque o critério de verificação é diferente.**
  Backend prova por teste e CI verde basta; frontend exige preview deploy com dado real e
  olho humano, que teste não substitui. Num PR único o backend fica esperando o olho humano
  e o frontend passa escondido atrás de CI verde. Fica registrado também que polish depois
  do preview não é retrabalho: mesmo quando o agente construiu exatamente o que foi pedido,
  dado real revela o que mockup esconde (nome longo, lista vazia, número de 9 dígitos).

- **One-pager ganha `Pedido`, e para de pressupor que todo doc decide.** A doutrina tratava
  Opções e Comparação como núcleo obrigatório, e cinco docs reais medidos mostraram três formas
  distintas: uma decide entre caminhos, duas pedem que alguém diga sim. O doc que só propõe
  alinhamento existia fora da doutrina. Agora o Pedido é declarado no topo do arquivo e em voz
  alta na sessão, com dois valores e um discriminador observável, que é **quem age em seguida**:
  `escolha` quando a próxima ação é sua, `proposta` quando ela exige alguém dizer sim. Sob
  `proposta`, Opções e Comparação são dispensadas e a seção terminal troca de "escolha e
  destino" para "o que peço". A catraca inversa fecha a rota de fuga: Comparação num doc marcado
  `proposta` denuncia Pedido errado, assim como tamanho denuncia trilho errado. Cinco blocos
  novos na tabela por gatilho (Inventário medido, Como sabemos que funcionou, Tradeoff
  principal, Workarounds em pé, Resumo em uma frase), cada um com ocorrência medida em doc real
  e ligado por **condição observável** em vez de categoria de documento. Três lentes de negócio
  (Dimensionamento, Unit economics, Menor aposta com evidência), porque as 13 anteriores eram
  todas de decisão técnica ou pessoal; o teto de duas lentes por sessão fica intacto, já que o
  risco é o agente escolher a lente que soa impressionante e não a que o gatilho pede.
- **Skill `coaching` passa a ter dois trilhos e um artefato.** A versão anterior era um
  framework de 6 passos que saía só em conversa: sessão sobre o que construir terminava sem
  registro da escolha, e a decisão se perdia entre sessões. Agora o trilho é declarado em voz
  alta e corrigível. **Conversa** (pessoal, decisão, direção) sai em ações no `TODOS.md`;
  **One-pager** sai em `docs/one-pagers/<slug>.md`, aberto no início com a condição de morte
  escrita. Catraca de mão única: na dúvida pega One-pager, complexidade descoberta no meio
  promove, nada rebaixa. Teto de uma página é o sinal de trilho errado, e roteia pela tabela de
  Destino (código direto, `/spec-and-plan`, `/kickoff-project`, sistema externo, não fazer).
  Dois references novos: `references/lentes.md` (13 frameworks, cada um com o gatilho que o
  dispara e teto de dois por sessão, porque framework sem gatilho não roda) e
  `references/one-pager.md` (núcleo Problema/Requisitos/Opções/Comparação, notação
  R/opção/parte/variante que serve de trilha de auditoria, `ATUAL` como opção nomeada pra
  evoluir vencer criar, ⚠️ reprovando na comparação e Sondagem como a saída dele). Nove
  bandeiras vermelhas travam as fugas conhecidas, sendo a principal "chamo de Conversa e pulo o
  arquivo".
- **Repo público fica agnóstico de dono.** `references/stack-default.md` deixa de
  publicar uma stack específica e vira molde: seis perguntas que uma stack default
  precisa responder, mais um exemplo preenchido que serve de régua de profundidade. A
  stack que você repete de projeto em projeto vai pra `config/stack.local.md`, gitignored
  junto dos outros overlays. Saem também as referências a ADR que não existem aqui, o
  ponteiro pra spec arquivada, o nome próprio num exemplo de spec e a unidade de negócio
  num exemplo de roteamento. O teto do `FEEDBACK.md` fica em 10 em todo lugar que o
  cita, alinhado com o `AGENTS.md`.
- **`tests/agnostico.test.sh`** trava a regressão com 19 asserts: identidade, caminho de
  máquina, primeira pessoa, unidade de negócio, ponteiro morto, link markdown quebrado,
  flag de permissão suprimida e formato da LICENSE. Cada regra roda duas vezes, no repo e
  contra uma violação plantada, porque assert que nunca viu vermelho não prova nada.
- **`settings.json` versionado vira mínimo.** Fica só o que faz o repo funcionar: hooks
  de enforcement, statusline, teto de auto-compact e `ask` em `git push`. Saíram três
  flags que suprimiam confirmação de permissão, as chaves de preferência pessoal
  (modelo, effort, idioma, voz, editor, TUI, canal de update) e a lista de plugins e
  marketplaces habilitados. Quem clonou antes de agora herdava as três flags de
  permissão: confira o próprio `settings.json` ao atualizar. Preferência passa a viver
  em `settings.example.json`, um fragmento pra copiar chave por chave; plugin se instala
  por `claude plugin install`.
- **Modelo de trabalho vira 3 modos** (substitui o ciclo de 5 elos): projeto
  novo → `/kickoff-project`; feature grande → spec de 1 arquivo em
  `docs/specs/<slug>.md`; resto → direto no código com TDD. Docs vivos como
  fonte de verdade; lição roteada pra `FEEDBACK.md` (projeto) ou memória
  (global).
- **Adversarial Evaluator vira opcional.** Sem Status Block obrigatório, teto
  de rounds ou estado que bloqueia ship; recomendado quando o diff toca prod ou
  é caro de reverter. `spec-and-plan` (spec 1 arquivo, sem folder/rubric/
  ongoing-done), `git-workflow-and-versioning` (gate: testes + segurança +
  docs vivos; `/simplify` recomendado) e `capture-lessons` (roteador de 2
  destinos) reescritas de acordo.

### Removed

- `docs/way-of-working.md` (7 cadeias), `project-template/` (24 arquivos) e
  `docs/rubrics/`, substituídos pela fundação gerada pelo kickoff + docs
  vivos. References de spec-folder e roteamento modelo-v2 das skills.
- **Simplificação do modelo de trabalho** (~9k linhas cortadas). Ciclo enxuto:
  `coaching → spec-and-plan → build TDD → ship → capture-lessons`.
- `ship-review` fundida em `git-workflow-and-versioning` como checklist único
  de gate de ship; `/simplify` vira passo obrigatório (REFACTOR do TDD e eixo
  do gate).
- `spec-and-plan` lite: sai tiering de cerimônia, detecção de modelo de docs e
  vocabulário Zona 1/2; fica contrato D-NN + ACs SIM/NÃO + tasks + gates do
  Evaluator.
- `test-and-debug` vira 3 regras de teste no `AGENTS.md`.
- Doutrina de escrita consolidada em `docs/research/escrita.md`
  (caveman + anti-slop); `CONTEXT.md` e o runbook de adoção dobram no `README.md`.
- Cadeia de hooks `PreToolUse:Bash` cai de 5 pra 2 (só bloqueantes/proxy);
  nudges de commit removidos.
- Governança do `model-policy.json` removida — edição direta, git é o histórico.
- `refresh-model-rankings` (skill + cron), `higiene-repo-runner` (launchd),
  `skill-creator`, symlinks de skills desligadas, testes de hook sem runner.

## [0.1.0] - 2026-07-13

Primeira release pública do way-of-work — o modelo de trabalho com agentes de
um dev, versionado pra quem quer adotar.

### Added

- **Ciclo de desenvolvimento** como skills invocáveis: `spec-and-plan`,
  `test-and-debug`, `ship-review`, `git-workflow-and-versioning`, `delegate`,
  `handoff`, `capture-lessons`, `coaching`, `skill-creator`,
  `refresh-model-rankings`.
- **AGENTS.md como fonte única** (padrão agnóstico, lido por Codex/Cursor/etc.)
  com `CLAUDE.md` como symlink — instrução viva, sem changelog embutido.
- **Adversarial Evaluator** (`scripts/peer-review.sh`) sobre spec e diff,
  classificando achados Critical/Important/Suggestion, com rubrics scored 1-5.
- **Hooks de enforcement** (`hooks/`): grep-first em reads grandes, guarda de
  no-op, lembrete de doc atualizada (context7). A mensagem de bloqueio ensina.
- **Doc-system transferível:** `project-template/` (scaffold clonável com hub
  docs, `docs/<área>/` e `_TEMPLATE-*`) + `docs/way-of-working.md` (as cadeias
  de proveniência) + `.claude/project.yaml` (metadata machine-readable).
- **Template de spec** (`specs/_TEMPLATE-spec/`) no formato §1-§5.
- **Modos de adoção:** user-level (`~/.claude`), cloud multi-source, submodule.
- Convenção público/privado: base versionada + `*.local.json` gitignored que
  faz merge em runtime; `.gitignore` allowlist.
