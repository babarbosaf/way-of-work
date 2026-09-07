# Shunt de tokens, roteamento de I/O para worker barato

**Fonte:** https://engineering.atspotify.com/2026/9/portal-by-spotify-cut-my-claude-code-token-usage-by-90 · complementos: https://tech.autoscout24.com/blog/posts/3-techniques-to-reduce-token-consumption-claude-code-codex/ · https://www.rtk-ai.app/
**Capturado:** 2026-09-07 · **Status:** pesquisa; proposta aberta, nada implementado.

## O que o Spotify fez

Tese: "a maior parte do que um agente de código faz não é pensar, é I/O". Leitura de
arquivo grande e geração de boilerplate gastam milhares de tokens com quase zero
raciocínio. Portal roteia esse trabalho pra um worker barato (Gemini Flash) e guarda o
modelo caro pra decisão, debug e arquitetura.

Três camadas:

1. **Hooks** que interceptam. `check-file-size` bloqueia Read acima de 350 linhas
   (`SHUNT_MIN_LINES`) e redireciona pro `bulk-reader`. `check-bash-read` cobre o
   vazamento por `cat arquivo | grep`.
2. **Scripts** wrapper: `bulk-read --question "..." --paths a b c` e
   `code-write --spec "..." --reference tests/OrderTest.java --target tests/UserTest.java`.
3. **Skills** que documentam quando invocar, e a mensagem do bloqueio aponta pra skill.

Ganho medido: **~90% médio no bulk-read**, num monorepo Java, quatro cenários. O corpus
nunca entra na janela do modelo caro.

Limites que o autor reconhece, e que são os nossos também:

- **Edição não delega.** Sumário do worker não tem número de linha confiável; pra editar,
  o modelo caro ainda lê a seção.
- **Raciocínio não delega.** O worker passou batido num bug de thread-safety que o Claude
  achou em segundos com o contexto certo.
- **Latência cobra pedágio.** 10 a 30s por delegação. Abaixo do threshold, o overhead
  come a economia. Calibrar a linha é parte do desenho, não detalhe.
- **Referência é obrigatória no code-write.** Sem `--reference`, o worker gera código sem
  contexto, que não encaixa em nada.

Lição principal, e a que mais bate aqui: **enforcement ganha de roteamento consultivo.**
As primeiras regras viviam no CLAUDE.md, eram advisory, e eram ignoradas.

## O que já temos, e é mais maduro que o Portal

Roteamento como dado, não como código: `config/model-policy.json` com backends, pools,
cascata por task-type, cooldown por pool, timeouts. `delegate.sh` despacha, degrada e
loga. Modo worktree confina escrita. `references/economy-mode.md` cobre a sessão sob
pressão de consumo. Cinco task-types, e dois deles são exatamente as duas modes do
Portal: `scan` é o bulk-reader, `boilerplate` é o code-writer.

O Portal tem um worker; a policy tem quatorze modelos em dois CLIs de custo zero, mais um
degrau pago estratégico antes da sessão. A parte difícil está feita.

## O que a medição mostra

Fonte acessível se mede. Duas fontes na máquina: `gate/delegate.log` (259 linhas) e
`rtk gain` (52.104 comandos).

**A cascata roda, mas quase só pra review.**

| task-type | chamadas | unavailable |
|---|---|---|
| review | 211 | 89 (42%) |
| scan | 22 | 6 |
| implement | 21 | 2 |
| boilerplate | 3 | 0 |
| second-opinion | 2 | 0 |

`review` tem dono automático: o `peer-review.sh` chama sozinho. `scan` e `boilerplate`
dependem de alguém lembrar e montar um heredoc à mão, e o número mostra o resultado.
22 e 3. **O shunt de leitura, que é de onde vêm os 90% do Spotify, está praticamente
desligado aqui.**

Os 42% de `unavailable` em review têm causa conhecida e corrigida na PR #26 (gpt-5.4 no
topo da cascata, recusado pela conta), a conferir depois do merge.

**O compressor local que cobre a leitura economiza 25%, não 90%.**

`rtk gain`, os dois comandos de maior volume:

```
1.  rtk read    6914 chamadas   34.1M salvos   25.3%
5.  rtk grep    7770 chamadas    1.9M salvos   13.9%
```

14.684 chamadas, os dois piores percentuais da tabela. Os bons (`rtk vitest run` 85.8%,
`rtk git diff` 96.2%) são de volume baixo. O maior volume de I/O do repo passa pelo
compressor mais fraco.

**E o 25.3% não se reproduz nos arquivos deste repo.** Medido direto, em bytes:

| arquivo | raw | `-l minimal` | `-l aggressive` | `rtk smart` |
|---|---|---|---|---|
| `AGENTS.md` | 5223 | 5222 | 5222 | - |
| `CHANGELOG.md` | 17890 | 17889 | 17889 | - |
| `delegate.sh` | 19432 | 14198 | **19550** | 49 |
| `peer-review.sh` | 14609 | 11876 | **14714** | - |

Markdown: 1 byte. Shell no `aggressive`: **cresce**, porque o filtro devolve vazio e o rtk
cai pro conteúdo bruto mais uma linha de warning (`filter produced empty output ...,
showing raw content`). O único ganho real é comentário de shell no `minimal`, 27%, e o
default do rewrite é `-l none`, que é 0%.

`rtk smart` entrega 49 bytes, 99.7%, mas é sumário de duas linhas: serve pra triagem,
não pra editar.

**O bloqueio de leitura é assimétrico, e o buraco é o caminho default.**

`read_size_guard.py` bloqueia `Read` acima de 200 linhas. O mesmo arquivo por Bash passa:

```
$ echo '{"tool_name":"Bash","tool_input":{"command":"cat skills/delegate/scripts/delegate.sh"}}' \
    | bash scripts/rtk-hook-wrapper.sh
{"hookSpecificOutput":{...,"updatedInput":{"command":"rtk read skills/delegate/scripts/delegate.sh"}}}
```

Reescrito, sim, pra um comando que devolve os mesmos 19432 bytes. O caminho honesto
(`Read`) apanha; o caminho silencioso (`cat`) passa e reporta economia que não existe.
Modo auto do harness instrui ler com `cat`, `head` e `sed -n`, então o caminho silencioso
é o default.

E a mensagem do bloqueio ensina a paginar na sessão ("Grep primeiro, depois Read com
offset+limit"). Paginar reduz o pico, não muda de janela: os tokens continuam entrando no
contexto caro. A skill `delegate` e o task-type `scan` não são citados.

## Os quatro buracos

1. **Bash read não tem guard.** O guard casa só `Read`, e o rewrite do rtk no lugar dele
   é win falso.
2. **Bloqueio ensina, não roteia.** Advisory dentro de um block. É a lição 3 do Spotify,
   pela metade.
3. **`scan` e `boilerplate` custam fricção de heredoc.** Sem açúcar de linha de comando,
   não são chamados. 22 e 3 chamadas provam.
4. **O shunt não se mede.** `delegate.log` grava task, backend, status e pool. Não grava
   tamanho. Não existe resposta pra "quanto o scan economizou", e sem isso o threshold é
   opinião.

## Proposta

Ordem por retorno sobre diff. Nada aqui inventa camada nova: os cinco movimentos são
extensão do `delegate` e do guard que já existem.

**1. Threshold como dado, dois degraus.** `shunt` na `model-policy.json`, com override
por env (`SHUNT_MIN_LINES`). Dois números, porque temos dois tiers com latências
diferentes, o que o Portal não tem: abaixo de `grep_max` (~200 linhas) resolve inline;
entre `grep_max` e `shunt_min` grep mais offset; acima de `shunt_min` (~500) vai pro
worker, onde 10 a 30s de latência já se pagam. Hoje o 200 está hardcoded no hook.

**2. `bash_read_guard`, antes do rtk na cadeia.** Casa `cat|head|tail|sed -n|less` sobre
arquivo acima do threshold, sem pipe que já filtra (`| grep`, `| head` de leitura
apontada passam, como o `check-bash-read` do Portal). Kill switch próprio. Mesmo
threshold do Read: um arquivo grande custa igual pelos dois caminhos.

**3. A mensagem do bloqueio vira comando colável.** Nos dois guards, no lugar de "grep
primeiro", o comando pronto:

```
delegate.sh --task scan --paths <a> <b> --question "<pergunta>"
```

**4. Açúcar de `--paths`/`--question` no `delegate.sh`, e `--reference` no boilerplate.**
O script monta o prompt que hoje se escreve à mão: arquivos em tag XML, instrução de
saída em bullets sem prosa, temperatura baixa onde o backend aceita. É o que mata a
fricção do buraco 3. No `boilerplate`, `--reference` obrigatório, que é a lição direta do
`code-write`: sem arquivo de referência, o worker gera código que não encaixa no projeto.

**5. Medir no log.** `bytes_in` e `bytes_out` na linha de `scan` e `boilerplate` do
`delegate.log`. Com isso o threshold do movimento 1 se calibra com número, e o próximo
ciclo compara o shunt contra os 25.3% do `rtk read`.

Fora dos cinco, um subtrair: o rewrite de `cat` pra `rtk read -l none` não economiza nada
e cria a impressão de que economiza. Ou passa a `-l minimal` (27% real em shell, 0% em
markdown), ou sai do wrapper e deixa o guard fazer o trabalho. Manter `rtk` no que ele é
bom: saída de comando (`test`, `git diff`, `lint`), 85 a 96%.

## O que fica de fora

- **Editar não delega.** O worker não devolve número de linha confiável. O shunt responde
  pergunta e gera arquivo novo; edição cirúrgica continua na sessão.
- **Sumário não substitui leitura pra decisão.** `rtk smart` e worker sumarizando servem
  pra triagem e pra localizar. Bug de concorrência quem acha é o modelo caro com o trecho
  certo na mão.
- **Subagente não é grátis.** Cada um abre janela própria. Serve pra isolar output
  verboso, não como hábito. A D-01 já ordena: worker grátis antes de subagente.
- **PR #27 é pré-condição.** Escalar `implement` e `boilerplate` depende da worktree
  confinar de verdade, que é o que ela corrige.
