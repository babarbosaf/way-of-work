---
name: delegate
description: >-
  Despacha tarefas delegáveis para workers de plano e de cota grátis (codex, agy,
  claude headless) via ~/.claude/scripts/delegate.sh, guiado por
  ~/.claude/config/model-policy.json.
  Invoque SEMPRE que: for executar task de spec com o campo `delega:` preenchido;
  precisar de varredura de codebase grande, segunda opinião de lógica/arquitetura,
  boilerplate/testes mecânicos ou review extra; quando o `read_size_guard` ou o
  `bash_read_guard` bloquearem uma leitura e mandarem pro worker; ou quando uma
  tarefa mecânica acima de 10 min não exigir o contexto da sessão. Invoque também quando o usuário
  pedir economia de consumo ("modo economia", "economiza", "otimiza o consumo",
  "tô perto do limite"), ativa o modo economia da sessão. Não invoque para:
  decisão de arquitetura, integração de código na branch principal, ou tarefa
  que depende do contexto vivo da conversa, isso é core do orquestrador.
---

# Delegate, orquestração de workers externos

> **D-01: plano de tarifa fixa primeiro, na ordem de qualidade.** O codex roda em plano de tarifa fixa e o backend `claude` é o mesmo plano
> da sessão, então os dois custam a mesma mensalidade que já foi paga, e o que se
> gasta é janela. O agy é grátis mas a cota é baixa, então ele é válvula de
> excedente, não degrau de volume. Toda cascata termina no plano Claude antes de
> esgotar, e só então o master assume (exit 2): o master é o fallback real, e não
> o único. **API nunca entra**, em nenhum backend: `delegate.sh` remove a
> `ANTHROPIC_API_KEY` de toda invocação, porque com ela setada o `claude -p`
> cobraria da API em vez do plano.

## Roteamento

A hierarquia vive em `~/.claude/config/model-policy.json`. **Nunca escolha
modelo por conta própria nem cite modelos literais**: passe o `--task` e deixe
a policy rotear. Task-types:

| task-type | quando usar |
|---|---|
| `review` | revisão adversarial de spec E de código, e é o único task-type de review. O `peer-review.sh` já dispara ele |
| `scan` | varredura/leitura de codebase ou arquivos grandes, sumarização |
| `boilerplate` | testes mecânicos, scaffolding, conversões repetitivas |
| `implement` | task comum de spec autocontida, código novo (modo worktree). Aceita `--tier` |

Não existe task-type por tamanho. O tamanho entra como `--tier padrao|amplo`, que
troca o **ponto de entrada** da mesma fila:

```bash
~/.claude/scripts/delegate.sh --task implement --tier amplo --worktree "$PWD" - < prompt
```

`PADRÃO` é até 5 arquivos próprios sem tocar contrato, e `AMPLO` toca contrato
(rota, schema, assinatura pública, migration) ou passa de 5 arquivos próprios.

Quais tiers existem é dado, não literal de script: o `delegate.sh` monta o
conjunto de `tiers.<task>` da policy mais o `padrao` implícito, e o
`check-spec.py` lê a mesma fonte. Tier que a task não declara é erro de uso, e
não fila padrão calada.
Quem classifica é o `to-tickets`, de forma mecânica, e o ticket carrega o `tier:`.
Sem `--tier`, resolve a fila padrão.

**Review espelha a classe da sessão**, em vez de ter fila fixa: sessão em Fable
revisa no par de classe topo, sessão em Opus revisa no par de classe forte. O
`delegate.sh` lê `.model` do `settings.json` do `CLAUDE_CONFIG_DIR`, e
`DELEGATE_SESSION_CLASS=fable|opus` sobrepõe, porque `/model` em runtime não
reescreve o arquivo.

Matriz completa de fallback manual (atividade × ranking de modelos, notas de
operação): `references/model-ranking-matrix.md`, consultar quando a cascata
automática não decide sozinha (fallback pós-exit-2, subagente interno,
override pedido pelo usuário).

Stage delegável dentro de um `Workflow` (pipeline/parallel): ver
`references/workflow-adapter.md`, não deixar `Workflow.agent()` spawnar
Claude direto pra tarefa que a cascata grátis resolve.

## Modo one-shot (default, sem escrita)

```bash
~/.claude/scripts/delegate.sh --task scan - <<'EOF'
<prompt>
EOF
```

Montagem do prompt do worker, ele não tem o contexto da sessão, então inclua:
1. **Objetivo em 2-3 frases** e o formato de saída esperado.
2. **Conteúdo ou paths absolutos** dos arquivos relevantes (worker roda no cwd).
3. **Regras do projeto**: cole as seções pertinentes do `AGENTS.md` do projeto.

Exit codes: `0` ok (resposta no stdout) · `2` cascata esgotada → **você assume
a tarefa inline** e segue; nunca re-tente em loop.

`--async` despacha e devolve o identificador na hora, em vez de segurar a sessão
pelo tempo do worker; `--status <id>` consulta depois, e mostra o estado, o
código de saída e o caminho do material que o worker produziu. Vale nos dois
modos, e quem quer ver tudo o que está correndo agora usa `--tasks`.

## Modo bulk, o script monta o prompt

Pergunta sobre arquivo grande não precisa de heredoc, e não deve precisar: a
fricção de montar o prompt à mão é o que mantinha esse caminho desligado (no
`gate/delegate.log`, 211 chamadas de `review`, que o `peer-review.sh` dispara
sozinho, contra 22 de `scan` e 3 de `boilerplate`).

```bash
~/.claude/scripts/delegate.sh --task scan \
  --paths src/Service.py src/Handler.py \
  --question "o que esse serviço faz, e quem chama o Handler?"
```

O script monta pergunta, corpus em tag `<file path="...">` e o contrato de saída
(bullets, sem prosa, com path e linha). **O corpus não entra na sua janela**, só
a resposta. `--paths` e `--question` andam juntos; um sem o outro é erro de uso,
e path inexistente morre antes de invocar worker.

Em `--task boilerplate` esse modo exige `--reference`:

```bash
~/.claude/scripts/delegate.sh --task boilerplate \
  --paths src/user_service.py \
  --reference tests/test_order_service.py \
  --question "escreva os testes de user_service seguindo esse padrão"
```

Sem arquivo de referência o worker gera código sem contexto, que não encaixa em
nada, e revisar custa mais que escrever à mão. O modo heredoc não mudou, e
`delega: boilerplate` de spec antiga continua valendo.

**Quando o degrau manda pro worker:** os guards de leitura (`read_size_guard`,
`bash_read_guard`) bloqueiam acima de `.shunt.worker_min` da policy e já
devolvem o comando pronto, com os paths preenchidos. Colar é a rota certa. Abaixo
do degrau, a rota é grep mais Read paginado, e não o worker: a delegação cobra 10
a 30s de latência, que abaixo da linha come a economia.

**O que o shunt não faz:** editar. O worker não devolve número de linha
confiável, então achar a seção é dele e mexer nela é seu. E raciocínio denso
continua aqui: sumário barato acha onde, não acha por quê.

## Modo worktree (tasks de spec)

Consumidor principal é o `/execute`: ele resolve a leva, chama este modo por
ticket marcado e integra na branch da rodada. Avulso, o protocolo abaixo vale igual.

**O marcador `delega: <type>` é vinculante e decidido no planejamento** (Fase 2
do to-tickets carimba TODO ticket: delegável ou orquestrador). No build:
task marcada → despacha; task sem marcador → executa inline, sem reavaliar.
Degradar é sempre permitido (worker indisponível ou task marcada se revelou
acoplada → assumir inline, com nota na spec); **promover não** (nunca delegar
task não-marcada por conta própria, se parecer delegável, é gap do plano:
aponte pro usuário decidir). Spec anterior a esta convenção = retrofit único
do plano, não avaliação task-a-task no build.

Para despachar uma task:

```bash
~/.claude/scripts/delegate.sh --task implement --worktree <repo-dir> - <<'EOF'
Task: <título e descrição da task, copiados da spec>
Critérios de aceite: <ACs da task>
Contexto: <trechos do AGENTS.md + arquivos que a task toca>
Restrições: edite apenas os arquivos da task; rode os testes se existirem.
EOF
```

O worker roda numa worktree em branch `delegate/<slug>`; a branch de trabalho
nunca é tocada. O output reporta `branch:`, `worktree:` e o diff stat.

**A confinação é a worktree, e não o sandbox do worker.** O `--sandbox` do agy
restringe terminal, não sistema de arquivos, e o agy não começa no cwd: ele abre
na pasta de artefato dele. Um worker que não sabe onde está sai caçando a raiz do
repo, acha a **árvore principal** e escreve lá. Foi assim que uma delegação
deixou o working tree do dono meio editado, com um arquivo que compilava e
quebraria em runtime. Por isso o `delegate.sh` faz três coisas juntas: `cd` na
worktree, `--add-dir {worktree}` no comando, e o caminho absoluto escrito no
começo do prompt. Nenhuma das três sozinha resolve.

**No modo worktree o worker do plano roda comando, e no modo sem escrita não.**
Sem isso o bloco de verificação do report dele é promessa: o harness recusa todo
binário fora de um allowlist mínimo, a sessão é headless e não tem quem aprove,
então `bash tests/...` voltava negado. A permissão vale só onde existe árvore
isolada pra estragar, e a confinação continua sendo a worktree.

**Protocolo de integração (obrigatório, nunca pular):**
0. `git status` na **árvore principal**. Worker que escapou aparece aqui, e
   descobrir isso depois de rodar teste custa muito mais.
1. `git diff main...delegate/<slug>`, revisar o diff inteiro; qualquer arquivo
   fora do escopo da task = rejeitar a branch.
2. Rodar o `verify_cmd`/testes da task na worktree.
3. Verde e no escopo → integrar (merge/cherry-pick conforme o fluxo do repo),
   marcando a task como delegada nas notas da spec.
4. Limpar: `git worktree remove <worktree>` e `git branch -d delegate/<slug>`.
   Órfãs: `delegate.sh --gc <repo-dir>`, que na mesma passada fecha a aba de
   sessão dirigida parada além do prazo, gravando a tela antes. Sem sessão
   registrada ele não chega a varrer nada.
5. Ruim mas recuperável → re-delegar com feedback no prompt (1 retry máx);
   ruim de novo → assumir a task inline.
6. **Report de fechamento (tech-lead, sucinto).** Pós-integração, emitir
   pra sessão orquestradora captar em 4 linhas (executor reportando pro tech-lead):
   ```
   feito: <o que mudou, observável>
   como: <abordagem em 1 frase>
   verify: <verify_cmd rodado + resultado>
   findings: <N> (issues #...)   # finding do worker vira issue via triage, não some
   ```
   Sem prosa extra. Fecha a issue da task (`ready-for-agent → done`) no tracker.

**Follow-up sem remontar do zero:** `--continue <slug>` reusa a
worktree/branch já criada em vez de abrir uma nova, útil pra retry com
feedback (passo 5) ou round 2 de review/debug na mesma branch:

```bash
~/.claude/scripts/delegate.sh --task implement --worktree <repo-dir> --continue <slug> - <<'EOF'
Feedback da revisão anterior: <o que ficou fora do escopo ou quebrou>
EOF
```

Slug inexistente → erro claro (nunca cria uma nova silenciosamente). Uma
worktree reaproveitada via `--continue` nunca é apagada automaticamente pelo
script, mesmo se a cascata esgotar nessa chamada, limpeza continua manual
(passo 4) ou via `--gc`.

## Ver as tasks em curso

`delegate.sh --tasks` lista o que está rodando agora, uma linha por task, com
identificador, balde de cota, tipo de task e branch. É leitura pura: nenhum
caminho dela toca policy, cota ou worker. Um pane do herdr rodando isso em laço
é a camada de terminal, e o passo a passo dela está em
`references/camada-terminal.md`.

## Delegação interna, subagentes Claude (tier `session`)

Workers externos não são a única saída: o **Agent tool aceita override de
`model` (`sonnet`/`opus`/`haiku`) e `effort` (`low`→`max`) por chamada**, dá
pra rodar Fable low na sessão e despachar um subagente Sonnet medium ou Opus
high pra uma tarefa pontual, com contexto isolado. Custa plano Claude, então
pela D-01 entra DEPOIS dos workers grátis. Use quando:

- a tarefa precisa do harness Claude (tools do repo, MCP, skills) que os CLIs
  externos não têm;
- a cascata externa esgotou (exit 2) mas a tarefa merece mais qualidade ou
  contexto isolado do que "assumir inline";
- review adversarial de contexto fresco (o fallback do peer-review já faz isso).

Calibre o modelo à tarefa como faria na policy: mecânico → haiku/sonnet low;
denso → sonnet medium; crítico → opus high. Nunca subagente caro pra tarefa
que um worker grátis resolve.

**Subagente `Agent` fresco (sem `fork`) não herda skills da sessão**, se ele
precisa saber operar `delegate`/`model-policy.json`, ver
`references/subagent-echo-preamble.md` (preâmbulo explícito + eco de
validação, `scripts/echo_preamble.sh`).

## Modo economia (sessão inteira)

Ativa quando o usuário sinaliza pressão de consumo. "modo economia",
"economiza", "otimiza o consumo", "seja eficiente nesta sessão", "tô perto do
limite (5h/semanal)". Detalhe completo: `references/economy-mode.md`.
Resumo: rotear agressivamente pros workers grátis tudo que couber num
task-type, Claude fica só com decisão/integração/síntese, cascata esgotada
cai pra fallback interno mais barato (nunca opus/fable sem pedido explícito).

## Falhas e higiene

- **Falha observada nunca edita a policy.** Provider que devolve 404, "does not
  exist or you do not have access", 502/503/504 ou "overloaded" está numa janela
  ruim, e janela ruim passa: o dispatcher arma um **cooldown curto** (10 min,
  `DELEGATE_TRANSIENT_COOLDOWN_MINS`) e o backend segue habilitado. Medido em
  07/set/2026: o mesmo `codex exec --model gpt-5.5` respondeu às 19h06 e deu 404
  às 19h31, mesma conta e mesmo diretório, com os 7 nomes de modelo do CLI
  acompanhando a janela em bloco. Duas rodadas anteriores escreveram essa mesma
  janela na policy como fato permanente ("esta conta não tem Codex"), e o efeito
  foi apagar o primeiro degrau de `review` e de `implement`.
  `enabled: false` é pra **decisão** (custo, segurança, política de conta com
  fonte), nunca pra sondagem. Sondagem mede a hora em que rodou.
- Worker indisponível/rate-limited entra em cooldown automático (60 min), o
  dispatcher já pula pro próximo da cascata (ordem da matriz); não gerencie
  cooldown manualmente. Cooldown é por **pool** (`backend:pool`, ex.
  `agy:gemini` vs `agy:claude_gpt`), não por backend inteiro, um pool ruim
  não derruba os outros do mesmo CLI. Não há cap diário fixo: a prioridade
  vem só da ordem da cascata na policy, e degradar só acontece quando o
  worker realmente rejeita (rate limit real) **ou** devolve `rc=0` com
  stdout vazio (falha silenciosa do provider, mesmo tratamento do rate
  limit: cooldown, cascata desce, nunca desabilita o pool na policy porque
  tier costuma resetar sozinho, ex. semanal).
- **Sandbox read-only** (one-shot, e worktree no codex): comando que escreve fora
  do repo (`uv sync` grava `~/.cache/uv`, instalar deps, fetch de rede) falha com
  `Operation not permitted (os error 1)`, não erro real da task. Não delegar
  gate/CI que sincroniza (retorna FAIL espúrio); rodar inline. Delegar só
  leitura e análise sobre conteúdo já no repo, tipo scan e review.
- Timeout default vem da policy por task-type (`.timeouts`); `--timeout` só
  pra override pontual.
- Aviso de "policy inválida" no stderr = modo degradado ruidoso; corrigir a
  policy (`jq . model-policy.json`) é prioridade sobre a tarefa em curso.
- Kill switch: `DELEGATE_DISABLED=1` (o `peer-review.sh` cai no fallback
  adversarial do Claude).
- **Pré-requisito one-time:** `codex` logado (`~/.codex/auth.json`), `agy`
  logado, `jq` instalado, e `~/.claude` como repo git.
- **Timestamp do `delegate.log` é UTC**, três horas à frente de São Paulo.
- **Sangria de quota se resolve fatiando prompt, não contando despacho.** A cota
  costuma ser proporcional a tokens, então um scan por subsistema custa menos que
  um scan do repo inteiro, com o mesmo número de chamadas.
- Log de uso (metadados): `~/.claude/gate/delegate.log`, com `bytes_in`/`bytes_out`
  por chamada. É com ele que o degrau do `.shunt` se calibra; sem tamanho, o
  threshold é palpite. Cada linha traz também `material`, o caminho do que o
  worker deixou no disco: o transcript da sessão dele quando ele grava uma, e o
  output capturado quando não grava. Caminho, nunca conteúdo, então diagnosticar
  uma falha é abrir o arquivo que a linha aponta, sem caçar entre mil sessões de
  nome opaco.
- **Eval de conformidade real** (sem mock, contra os CLIs de verdade):
  `scripts/smoke_backends.sh [--task <type>]`, sonda cada modelo/pool
  habilitado na policy com prompt trivial, confirma resposta não-vazia, e já
  arma/limpa os cooldowns reais que o dispatcher usa (roda antes de uma
  sessão que vai delegar pesado, pra não descobrir pool morto no meio de uma
  task). `delegate.test.sh` é todo mockado, não pega isso.
- Atualização da hierarquia: editar `model-policy.json` direto (git é o
  histórico), mas nunca no meio de uma delegação em curso.
