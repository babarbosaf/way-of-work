# Changelog

Formato [Keep a Changelog](https://keepachangelog.com/pt-BR/1.1.0/);
versionamento [SemVer](https://semver.org/lang/pt-BR/).

## [Unreleased]

### Added

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

- **Anúncio de trabalho próprio** (`skills/writing/references/padroes.md`, padrões 42 a
  45): crédito abre a mensagem em vez de fechar, esforço não legitima entrega, punchline
  doutrinária fechando parágrafo, e verbo modesto no lugar do verbo de lançamento. Saíram
  da revisão de um anúncio de canal reescrito à mão, onde o texto do agente passava no
  linter e as quatro construções sobreviviam. O par 7 de `fixtures/antes-depois.md` é o
  primeiro de mensagem de chat, e não de doc.

### Fixed

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

- **Terceiro escopo de brevidade** (`skills/writing/SKILL.md`): mensagem pra uma pessoa num
  canal não é instrução densa nem texto que se lê de ponta a ponta. Vale a frase conectada,
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
