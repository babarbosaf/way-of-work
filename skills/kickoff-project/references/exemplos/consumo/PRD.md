# PRD: Bolão Copa do Mundo 2026

> **Papel deste doc.** A fonte da verdade do produto: uma seção por funcionalidade, com comportamento, contrato e edge cases. Rotas no [ROUTES.md](ROUTES.md), telas no [DESIGN.md](DESIGN.md), regra de construção no [CONVENTIONS.md](CONVENTIONS.md). Tags: `no ar` funciona como descrito; `parcialmente no ar`, a primeira linha diz a parte que funciona; `previsto` está decidido e não construído; `em aberto` nem foi decidido.

> Exemplo adaptado do blueprint de Iago de Macedo (github.com/iagodemacedo/project-blueprint).

## 1. Visão geral

Produto standalone gratuito de bolão para a Copa do Mundo FIFA 2026, voltado para o lúdico, interação social e competição entre amigos.

O produto se sustenta em três motores principais de engajamento:

1. **Palpites** que premiam tanto V/E/D quanto placar exato, com multiplicadores crescentes por fase do torneio `no ar`
2. **Grupos privados entre amigos** com ranking de Liga e estatísticas sociais do grupo `no ar`
3. **Álbum de figurinhas digital** com 154 figurinhas em 4 coleções, sistema de troca e drop diário `previsto`

```
BALLDONTLIE ──sync por minuto (§14)──▶ BANCO: jogos, jogo_detalhes          `no ar`
                                          │
JOGADOR ──palpita até o apito (§3–§5)──▶ PALPITES                            `no ar`
                                          │ apura no fim do jogo
                                          ▼
                                        PONTOS ──soma──▶ LIGA (§7) ──▶ ESTATÍSTICAS (§8)   `no ar`
                                          │
                                          └──avisa──▶ NOTIFICAÇÕES (§13)     `no ar`

JOGADOR ──entra por convite (§2, §6)──▶ GRUPO                               `no ar`
JOGADOR ──abre o pacote do dia (§9, §10)──▶ ÁLBUM ──completude──▶ ranking de álbum (§7)   `previsto`
```

## 2. Cadastro e identidade

`no ar`

### Propósito

Levar qualquer pessoa da porta até dentro de um grupo na mesma sessão. Jogar sozinho não tem graça, então a conta sem grupo é um estado de passagem, nunca um destino.

### Fluxo

Cadastro **aberto a qualquer pessoa**. Após criar a conta, todo usuário passa pela tela `/convite`, onde escolhe **entrar num grupo existente** (com um código) ou **criar o seu próprio grupo**. A reentrada de usuário existente é feita pela tela de login, que não cria conta.

Caminhos de entrada:

- **Landing / `/cadastro`:** qualquer um cria conta (email+senha ou Google/Apple)
- **Deep link `/entrar/:codigo`:** convite que já leva o código para o cadastro
- **Pós-cadastro (`/convite`):** sem grupo ainda, o usuário entra com um código OU cria um grupo novo

Ao criar um grupo, o usuário informa o **nome do grupo** e o sistema gera um **código de convite legível** que ele compartilha para os amigos entrarem. O criador vira admin do grupo.

Submit do cadastro cria a conta, faz o ingresso no grupo do convite e direciona para o onboarding (seção 11).

Login: email + senha, atalho com Google, atalho com Apple e link "Esqueci a senha" (recuperação por email).

### Regras

| Campo do cadastro | O produto exige |
|---|---|
| Email | obrigatório |
| Nome | obrigatório |
| Apelido | obrigatório; é o nome exibido nos rankings e nas estatísticas do grupo |
| Senha | obrigatória; Google e Apple dispensam |

| Quando | O produto garante |
|---|---|
| um grupo é criado | o código de convite tem 6 caracteres legíveis, sem caracteres ambíguos |
| o código é inválido, expirou, o grupo encheu ou encerrou | `/entrar/erro` mostra o motivo e orienta pedir um novo código |
| o código é válido e já existe sessão ativa | abre a sheet "Entrar no grupo X?" em vez do cadastro |

## 3. Estrutura de palpites

`no ar`

### Propósito

Dar ao palpite uma régua que premie precisão e acerto parcial, e que cresça de peso conforme a Copa avança, sem nunca punir quem erra.

### Fluxo

O jogador palpita em duas escalas. **Por jogo:** resultado (V/E/D), placar exato e Pergunta Plus (seção 4). **Long-term picks**, travados em 17/06/2026 às 23h59 na hora do último jogo da primeira rodada da fase de grupos: campeão, vice-campeão, 3º lugar, 4º lugar, artilheiro, Bola de Ouro (melhor jogador) e melhor jogador jovem (sub 21).

A régua segue cinco princípios: placar exato vale aproximadamente 3x o resultado simples; a pontuação cresce ao longo da Copa via multiplicadores; acerto parcial conta, seja o saldo correto ou um dos placares; os long-term picks pesam sem decidir sozinhos a Liga; e não há pontos negativos, porque o produto é lúdico e punir o erro afasta o jogador casual.

> A Copa 2026 tem 48 seleções (contra 32 das anteriores), o que introduz uma fase extra antes das oitavas, o Round of 32, com 16 jogos. Total: 72 + 16 + 8 + 4 + 2 + 1 + 1 = 104 jogos.

### Regras

| Tipo de palpite | Pontos base |
|---|---|
| Acertou só o resultado (V/E/D) | 10 |
| Acertou resultado + saldo de gols correto | 18 |
| Acertou resultado + um dos placares correto | 22 |
| Placar exato | 35 |
| Pergunta Plus | 15 |
| Errou | 0 |

| Fase | Multiplicador |
|---|---|
| Fase de grupos | 1.0x |
| Round of 32 (16 jogos do primeiro mata-mata) | 1.25x |
| Oitavas (Round of 16) | 1.5x |
| Quartas | 2.0x |
| Semis | 2.5x |
| Disputa 3º lugar | 2.0x |
| Final | 3.0x |

| Long-term pick | Pontos fixos |
|---|---|
| Campeão | 200 |
| Vice | 150 |
| 3º lugar | 100 |
| 4º lugar | 50 |
| Artilheiro | 150 |
| Bola de Ouro (melhor jogador) | 150 |
| Melhor Jogador Jovem (sub 21) | 150 |

| Quando | O produto garante |
|---|---|
| home, liga e perfil mostram pontuação | os números são idênticos, porque as três consomem os helpers puros `agregarPontuacao` e `ordenarPosicoes` da engine `lib/pontuacao` |
| um jogo é anulado ou sai por WO | os palpites daquele jogo anulam, e ninguém pontua |
| um mata-mata se decide nos pênaltis | o placar exato considera tempo normal mais prorrogação, no padrão FIFA |

## 4. Pergunta Plus sistemática

`no ar`

### Propósito

Somar uma pergunta por jogo que dê o que conversar sem custar operação: o pool é fixo e a apuração é automática, porque curadoria editorial por jogo não escala em 104 jogos.

### Fluxo

O sistema sorteia ou rotaciona uma pergunta do pool fixo, definido antes da Copa. Ela fica visível até a hora do jogo iniciar, e a resposta certa se apura sozinha pelos eventos da partida em `jogo_detalhes.eventos` (seção 14).

### Regras

| Pool | Perguntas |
|---|---|
| Fase de grupos | Total de gols acima de 2.5? · Ambas as seleções marcam? · Tem gol no primeiro tempo? · Mais de 3 cartões amarelos no jogo? · Algum gol depois dos 80 minutos? |
| Mata-mata | Decidido no tempo normal, prorrogação ou pênaltis? (3 alternativas) · Tem gol no primeiro tempo? · Ambas marcam? · Mais de 2.5 gols no tempo normal? · Alguma expulsão no jogo? |

| Quando | O produto garante |
|---|---|
| o jogador acerta a Plus | vale 15 pontos base, multiplicados pela fase |
| o jogo começa | a pergunta fecha, e a validação roda 100% por API, sem ninguém apurar à mão |
| o jogo é anulado | a Plus anula junto com o palpite do jogo |

## 5. Janela de palpite

`no ar`

### Propósito

Deixar claro, a qualquer momento, se ainda dá para palpitar. Palpite que chega depois do apito vale nada, e descobrir isso só ao salvar é a pior hora de descobrir.

### Fluxo

Cada palpite tem uma janela própria, e o estado dela aparece no card antes de o jogador abrir o palpite: **"Palpite aberto"** em verde, com contagem regressiva nas últimas 6h; **"Palpite fechado"** em cinza, mostrando o resultado se o jogo já rolou; e **"Em breve"** para o que ainda vai abrir, que só acontece no mata-mata.

Depois do início do jogo, `/palpites/jogos/[id]` redireciona para `/ao-vivo` (jogo rolando) ou `/resultado` (jogo encerrado), inclusive em acesso direto por URL, e os cards de jogo no calendário, no início e na lista apontam para o destino do estado.

### Regras

| Tipo de palpite | Abre | Fecha |
|---|---|---|
| Long-term (campeão, artilheiro, etc.) | Lançamento do app | 17/06/2026 às 23h59, hora do último jogo da primeira rodada da fase de grupos |
| Jogo da fase de grupos | 72h antes do jogo | 5 min antes do início |
| Jogo de mata-mata | Quando definidos os classificados (fim da rodada anterior) | 5 min antes do início |
| Pergunta Plus | Junto com o palpite do jogo | 5 min antes do início |

| Quando | O produto garante |
|---|---|
| chega um palpite fora da janela | o backend recusa salvar, e não só a interface esconde |
| o jogo adia com a janela aberta | ela continua aberta até o novo horário menos 5 min |
| o jogo adia com a janela fechada | os palpites permanecem válidos pro novo horário, e a janela não reabre |
| o jogador esquece de palpitar | zero pontos no jogo, sem ônus adicional; o streak quebra se aplicável |
| o jogador quer trocar o palpite | edição livre até o fechamento da janela, sem histórico público |

## 6. Grupos

`no ar`

### Propósito

Ser a roda em volta da qual o jogo acontece: o grupo é fechado por convite, porque a graça é jogar com quem se conhece, e ranking com estranho não gera conversa.

### Fluxo

Qualquer usuário **cria um grupo** em `/convite`, vira admin e recebe um código de convite legível. A entrada num grupo existente é por **código de convite**: deep link `/entrar/:codigo`, colando o código em `/convite` ou em `/grupo/entrar`. Não há lista pública de grupos.

Cada grupo tem nome, descrição opcional, limite de membros e uma Liga (seção 7). O usuário participa de vários grupos ao mesmo tempo, com seletor no topo da interface.

O admin tem painel próprio: editar grupo, gerar código ou link de entrada, ver e remover membros, encerrar grupo e ver métricas básicas (membros ativos, palpites feitos, completude média do álbum). A saída é voluntária, a qualquer momento, por `/grupo/info`.

### Regras

| Regra | Valor |
|---|---|
| Código de convite | 6 caracteres, sem caracteres ambíguos |
| Limite de tamanho do grupo | `a definir` |

| Quando | O produto garante |
|---|---|
| o usuário palpita | o palpite é único e vale em todos os grupos dele: faz uma vez, conta em todos |
| um membro sai do grupo | os pontos acumulados dele saem do ranking daquela Liga, e o histórico de palpites permanece, porque o palpite é compartilhado entre grupos |
| um membro que saiu quer voltar | só com novo convite do admin |
| o grupo é encerrado | o código deixa de valer e cai no erro de `/entrar/erro` |

## 7. Liga do grupo

### Propósito

Responder "quem está ganhando" sem deixar empate sem explicação: quando duas pessoas têm os mesmos pontos, o ranking diz por que uma está na frente.

### Fluxo

Ranking único do grupo, pelos pontos acumulados durante toda a Copa, atualizado a cada 10 minutos. `no ar`

Quando há empate, o ranking não só ordena: ele mostra qual critério está desempatando. Exemplo: "Empate em 1.247 pts. Iago à frente por mais placares exatos (12 vs 9)". `no ar`

**Ranking de álbum** `previsto`: um seletor de tipo de ranking (pills) alterna **Palpites** (padrão) e **Álbum**. O de Álbum ordena os membros pela completude (% de figurinhas distintas sobre o catálogo), no mesmo card do ranking de pontos: posição, avatar, "X de 154 figurinhas" com barra de progresso e o % em destaque. Tocar num membro abre o álbum dele.

### Regras

Cascata de desempate dos pontos, aplicada em ordem e parando no primeiro critério que diferencia: `no ar`

| Ordem | Critério |
|---|---|
| 1 | Mais placares exatos acertados na Copa toda |
| 2 | Mais palpites de torneio acertados (long-term) |
| 3 | Mais palpites totais feitos (engajamento) |
| 4 | Maior streak máximo atingido na Copa |
| 5 | Data de criação da conta (mais antiga vence) |

| Quando | O produto garante |
|---|---|
| a tela pede os dois rankings | os dois chegam no mesmo payload de `get_liga_resumo` (1 roundtrip, `CONVENTIONS.md` §3), e o seletor alterna client-side, sem nova request |
| dois membros empatam no álbum | desempata por mais figurinhas distintas e, persistindo, por ordem alfabética de apelido; sem cascata, porque não há prêmio em jogo `previsto` |
| alguém completa o álbum | não ganha ponto nenhum na Liga: a economia do álbum e a competição não se misturam, e o ranking de álbum é puramente social `previsto` |
| o ranking de álbum é servido | ele expõe só a contagem por membro, com gate de mesmo grupo na RPC; quais figurinhas cada um tem continua visível só pelo álbum do membro, que tem o próprio gate `previsto` |
| um membro sai do grupo | ele some do ranking, com os pontos (seção 6) |

## 8. Estatísticas do grupo

### Propósito

Dar assunto ao grupo sem exigir que alguém produza conteúdo. Tudo aqui se deriva do que já aconteceu nos palpites, então o painel enche sozinho mesmo num grupo calado.

### Fluxo

Sub-aba 2 da aba Grupo (`/grupo/estatisticas`). Painel de estatísticas sociais derivadas dos palpites e do álbum, atualizado a cada jogo resolvido.

| Bloco | O que mostra | Estado |
|---|---|---|
| Termômetro do grupo | total de palpites, % de acerto coletivo, placares exatos acumulados e maior streak ativo (com o dono) | `no ar` |
| Jogos de hoje | quem já palpitou todos os jogos do dia e quem ainda falta; pendente que é o próprio usuário ganha CTA "Palpitar" | `no ar` |
| Cutucada | membro cutuca quem ainda não palpitou, 1 por dupla por dia; vira notificação no sino do cutucado | `no ar` |
| Destaques do dia | craque do dia (mais pontos no último dia com jogos resolvidos), "na mosca" (placares exatos do dia) e "gelado" (errou todos do dia, mínimo 2) | `no ar` |
| Raio X dos jogos | por jogo encerrado: distribuição dos palpites (1/X/2), quantos acertaram o resultado, quem cravou o placar e a lista de palpites revelados | `no ar` |
| Zebra e consenso | jogo recente em que 80%+ do grupo (mínimo 3 palpites) apostou num lado e deu outro; jogo em que o grupo inteiro acertou | `no ar` |
| Álbum do grupo | cobertura coletiva, quem está mais perto de completar e a figurinha mais rara do grupo (menos donos) | `previsto` |

### Regras

| Quando | O produto garante |
|---|---|
| a tela carrega | uma RPC consolidada `get_grupo_estatisticas` traz tudo em 1 roundtrip, e a agregação roda na engine JS `lib/estatisticas-grupo` |
| um bloco precisa de dado | ele deriva de `jogos` e das tabelas de palpites e de álbum, e nenhum bloco tem tabela própria |
| o jogo ainda não começou | o palpite de terceiros não aparece, pelo mesmo gate das RPCs de ranking; é o Raio X que materializa a regra "após o apito final, o palpite vira público" |
| "Quem já palpitou hoje" lista alguém | expõe só o fato de ter palpitado, nunca o conteúdo |
| a figurinha mais rara tem dono único | expõe nome e dono, no mesmo nível de visibilidade do álbum do membro `previsto` |

## 9. Álbum de figurinhas

`previsto`

### Propósito

Dar um motivo para voltar todo dia mesmo a quem não vai ganhar a Liga. O álbum é colecionável puro: não dá ponto, não dá vantagem, e por isso pode ser generoso sem desequilibrar a competição.

### Fluxo

154 figurinhas em 4 coleções temáticas, todas definidas antes do início da Copa, sem dependência de convocação oficial. A ilustração é estilizada e gerada por IA, com identidade única entre as coleções: estilo de referência, paleta consistente, enquadramento padrão, família de fundos e curadoria humana antes de publicar.

| Coleção | Figurinhas | Conteúdo |
|---|---|---|
| 1. Seleções | 48 | 1 figurinha por seleção (escudo, uniforme, cores) |
| 2. Cidades sedes | 16 | As 16 cidades sedes da Copa do Mundo |
| 3. Lendas do Mundial | 60 | 5 lendas por país, 12 nações historicamente relevantes |
| 4. Momentos Históricos | 30 | Cenas icônicas de Copas anteriores |
| **Total** | **154** | |

O jogador resgata pacotes por ação, abre, e troca as repetidas com quem está no grupo: listas "Tenho" e "Quero" visíveis dentro do grupo, troca 1×1 com confirmação dupla, sem moeda intermediária e sem leilão.

A economia ao longo da Copa (~30 dias) cria gradiente entre níveis de engajamento sem nenhum nível ser punitivo:

| Perfil | Pacotes | Figurinhas | Comportamento esperado |
|---|---|---|---|
| Super engajado | ~260 | ~780 | Completa o álbum com folga, gera muitas repetidas para troca |
| Médio | ~140 | ~420 | Completa boa parte do álbum, depende de troca para fechar |
| Casual | ~80 | ~240 | Avança em algumas coleções, não completa |

### Regras

| Pacotes | Regra |
|---|---|
| Tamanho | 3 figurinhas |
| Drop diário base | 2 pacotes por resgate ativo (clique manual) |
| Extra por palpitar | +1 por palpitar em pelo menos 1 jogo no dia |
| Extra por acerto | +1 por palpite de resultado acertado (vencedor ou empate, não o placar exato) |
| Extra por missões | +1 ao completar as 3 missões do dia |
| Extra por streak | marcos de streak (seção 10) |

| Quando | O produto garante |
|---|---|
| um pacote é aberto | todas as 154 têm a mesma chance: não há raridade. Tornar uma lenda como Pelé mais difícil penalizaria completar a coleção sem ganho de engajamento proporcional, e a distribuição uniforme elimina a discussão regulatória sobre probabilidade pública de drop |
| o jogador completa coleções | não ganha boost no jogo nem ponto na Liga |
| o catálogo é servido | ele é público e estável, e usa cache cross-request; a lista item a item (IDs `S001` a `S154`, com o tema de cada uma) mora em `Sticker.md` |
| uma imagem precisa ser gerada | `scripts/generate-stickers.mjs` lê o `Sticker.md` e o Estilo Mestre; coleções 1 e 2 vêm da API BallDontLie, e 3 e 4 são curadoria editorial |
| o jogador monta uma troca | as figurinhas de "Você oferece" já comprometidas em outra troca pendente aparecem esmaecidas, com o selo "Ofertada para [Apelido]" (`+N` com mais de um destinatário); é só aviso, e ele ainda pode selecioná-las |

## 10. Streak diário

### Propósito

Premiar quem aparece todo dia sem dar vantagem competitiva a quem aparece: o streak paga em pacotes, nunca em pontos, para que assiduidade não vire placar. `no ar`

### Fluxo

Mantém o streak quem, no dia, resgata pelo menos um pacote do álbum ou faz pelo menos 1 palpite. O streak máximo fica registrado no perfil mesmo depois de quebrar, alimenta o critério 4 de desempate da Liga (seção 7) e desenha o calendário de `/perfil/streak`. `no ar`

### Regras

| Dias consecutivos | Recompensa em pacotes do álbum `previsto` |
|---|---|
| 3 dias | +1 pacote bônus |
| 7 dias | +2 pacotes bônus |
| 14 dias | +3 pacotes bônus |
| 21 dias | +4 pacotes bônus |
| 30 dias | +7 pacotes bônus |

| Quando | O produto garante |
|---|---|
| passam 24h sem ação de manutenção | o streak zera, e não há mecanismo de "salvar streak" `no ar` |
| o dia vira | o reset é à meia-noite no fuso de Brasília, porque o público é nacional `no ar` |
| o streak cresce | ele não dá multiplicador de pontos nem selo visual `no ar` |
| o jogador atinge um marco | ele recebe a recompensa uma única vez, sem recorrência `previsto` |
| o jogador esquece de palpitar | o streak quebra só se também não houve resgate de pacote no dia `no ar` |

## 11. Onboarding pós-cadastro

`no ar`

### Propósito

Explicar a régua antes do primeiro palpite. Quem descobre a pontuação depois de errar acha que o produto é injusto, e não que não leu.

### Fluxo

Fluxo de 6 passos exibido **uma única vez**, logo após o primeiro cadastro, com "Pular" em todos os passos. Ao concluir ou pular, direciona para `/grupo/liga`.

1. **Palpites.** Como funciona a pontuação base e os multiplicadores por fase
2. **Grupo e Liga.** Explica o ranking e os critérios de desempate
3. **Pergunta Plus.** Como funciona a pergunta extra por jogo
4. **Álbum.** Apresenta o álbum, drop diário, missões e trocas `previsto`
5. **Streak e missões.** Como manter o streak e ganhar pacotes extras
6. **Boas-vindas ao grupo "X".** Finaliza chamando o nome do grupo do convite

### Regras

| Quando | O produto garante |
|---|---|
| o usuário conclui ou pula | grava `onboarded: true` na conta, e o fluxo não volta sozinho |
| o usuário quer rever | `/perfil/ajuda` ("Ver tour novamente") reabre o fluxo sem alterar a flag `onboarded` |

## 12. Ao vivo durante o jogo

`no ar`

### Propósito

Segurar o jogador dentro do app durante os 90 minutos, mostrando quanto o palpite dele está valendo enquanto o jogo acontece.

### Fluxo

A tela do jogo (`/palpites/jogos/[id]/ao-vivo`) é rica em dados reais da BallDontLie e muda conforme o estado da partida. Ela se mantém atualizada sozinha durante todo o jogo; ao voltar para o app (desbloquear o celular, trocar de aba) o snapshot é rebuscado na hora, e nada de spinner nem re-render quando o snapshot não mudou.

**Pré-jogo (tela de palpite):**

- Ficha do jogo: estádio (com capacidade), árbitro, técnicos
- Escalação **real** (titulares com formação + banco) quando publicada; antes disso, formação provável + técnico
- "Como chegam": classificação no grupo + forma recente (nota média e forma), que aparece quando a API publica o `team_form`

**Ao vivo:**

- Placar ao vivo com animação de gol e pênaltis
- **Pressão do jogo** (momentum minuto a minuto, gráfico de barras; some no pós-jogo)
- **Card unificado da partida** logo abaixo do placar, com abas trocadas por toque ou **swipe**; aba sem dados não aparece:
  - **Lances**: feed minuto a minuto com gols (autor, assistência, placar momentâneo), cartões, substituições, decisões do VAR (gol anulado aparece riscado), fim de tempo e disputa de pênaltis
  - **Estatísticas**: barras comparativas (posse, xG, finalizações, escanteios, passes certos etc.)
  - **Chutes**: campinho com o mapa de chutes (raio do ponto cresce com o xG)
  - **Posições**: campinho com as posições médias dos jogadores
  - **Escalações**: titulares (com formação) + banco, badges de quem entrou e saiu, com toggle de país dentro da aba
- **Card "Seu palpite"**: junta o palpite de placar e a Pergunta Plus, com o total parcial "valendo" no topo e o placar **destrinchado por nível** (placar exato, resultado + um placar, resultado + saldo, resultado, ou não acertou) com os pontos abertos de cada parte. A linha da Plus mostra a pergunta, a resposta do usuário, a parcial "se terminasse agora" (vira "Real" no encerramento) e quanto está valendo
- **Palpites do Grupo**: só os membros do **grupo ativo**, ranqueados pela estimativa de pontos com o placar corrente, no formato do pós-jogo: posição, tag "Cravou" e badge "Valendo +X"

**Pós-jogo:**

- Tudo do ao vivo (exceto o momentum), congelado no resultado final, com o card "Seu palpite" virando pontuação final
- **Craque da partida** (man of the match com rating) + melhores notas do jogo
- A tela de resultado (`/palpites/jogos/[id]/resultado`) traz o link "Veja como foi a partida" junto ao placar

### Regras

| Quando | O produto garante |
|---|---|
| a tela está aberta | o client faz polling de 20s do snapshot pela rota estável `GET /api/jogos/[id]/ao-vivo`, e os dados-fonte chegam minuto a minuto pelas edge functions da seção 14 |
| uma aba do card não tem dados | ela não aparece, em vez de aparecer vazia |
| um jogador entra ou sai | a badge de substituição sai do cruzamento entre lineup e os eventos de substituição |
| há deploy no meio da partida | a rota de snapshot sobrevive à troca de build, e após falhas consecutivas o client se recupera com um reload único e transparente |
| o VAR anula um gol | ele aparece riscado no feed, e o replace total de `jogo_detalhes` a cada sync resolve o placar sem reconciliar por id |

## 13. Notificações

### Propósito

Trazer o jogador de volta na hora certa sem virar incômodo: cada aviso corresponde a uma ação que ainda dá para tomar, e nenhum evento avisa duas vezes. `no ar`

### Fluxo

O sino no header de cada aba abre `/notificacoes`, a tela única com o histórico cronológico. Fora do app, o aviso vai por **Web Push** com o app instalado como PWA: o sino deriva o feed ao vivo para o app aberto, e o push avisa no device mesmo com o app fechado. `no ar`

| Evento | Categoria em `notif_prefs` | Destino do deep link | Estado |
|---|---|---|---|
| Palpite fechando em ~1h, sem palpite | `lembrete_palpite` | `/palpites/jogos/:id` | `no ar` |
| Resultado / acertou palpite | `resultado_jogo` | `/palpites/jogos/:id/resultado` | `no ar` |
| Cutucada recebida | `cutucada` | `/palpites/jogos` | `no ar` |
| Convite recebido (sessão ativa) | | sheet de confirmação → `/grupo/liga` | `no ar` |
| Drop diário disponível | `drop` | `/album/drop-diario` | `previsto` |
| Oferta de troca recebida | `troca` | `/album/trocas/:id` | `previsto` |
| Ranking e marco de streak | | | `previsto` |

| Peça | Papel |
|---|---|
| `push_subscriptions` | endpoint e chaves por device, RLS self |
| `push_enviados` | dedupe por `(user, chave)`, só service role |
| RPC `get_pushes_pendentes()` | SECURITY DEFINER, só `service_role`: devolve o que falta enviar, já filtrado por `notif_prefs`, janela de recência e existência de assinatura |
| edge function `send-push` | fan-out VAPID (`web-push`) pros devices do usuário, grava em `push_enviados`, remove assinatura morta (404/410); `pg_cron` a cada 2 min, com guard em SQL (só invoca se houver assinatura) |
| `public/sw.js` | handlers `push` (mostra) e `notificationclick` (foca ou abre no deep link) |
| `src/lib/push/client.ts` | pede permissão, assina com `NEXT_PUBLIC_VAPID_PUBLIC_KEY`, persiste via server action |

### Regras

| Quando | O produto garante |
|---|---|
| a conta é nova | todas as categorias já vêm ligadas, e o usuário desliga o que não quer em `/perfil/notificacoes` |
| o app vai pedir permissão do browser | pede por gesto explícito, num toggle "Receber notificações push" por dispositivo, nunca sozinho |
| um evento acontece | no máximo 1 push por evento por usuário, sem agrupar eventos |
| uma fonte procura o que enviar | ela só olha eventos recentes (acerto nas últimas 3h, drop nas últimas 24h, cutucada nas últimas 6h), então ninguém recebe histórico antigo |
| o mesmo push dispara de novo | ele substitui em vez de empilhar, porque a chave de dedupe é estável (`push-<tipo>:<id>`) e a `tag` da notificação reusa a chave |
| uma chave falta em `notif_prefs` | conta como ativa |
| o device é iOS ou iPadOS | exige 16.4+ e o app adicionado à tela de início (standalone); em aba normal do Safari não funciona, e a UI comunica isso. Android, Chrome, Edge, Firefox e desktop não têm essa amarra |
| é o primeiro deploy | a janela de recência impede disparar o histórico acumulado |
| o usuário não habilitou push | o canal alternativo é `a definir` |

## 14. Dados e sincronização (BallDontLie)

`no ar`

### Propósito

Servir dado esportivo real sem que o browser dependa de um fornecedor externo estar de pé, e sem gastar cota da API em minuto que não tem jogo.

### Fluxo

Toda tela esportiva (seleções, estádios, jogos, placares, chaveamento) mostra dado real da API BallDontLie FIFA World Cup, lido de um cache local; o browser nunca consulta a API. A regra de construção por trás está no `CONVENTIONS.md` §2.

Seis edge functions enchem esse cache em cadências diferentes, agendadas por `pg_cron` mais `pg_net`. O `sync-balldontlie`, que é o sync completo num job só, serve só a backfill manual.

| Function | Conteúdo | Cron |
|---|---|---|
| `sync-reference` | seleções (`/teams`) e estádios (`/stadiums`) | `0 6 * * 1` |
| `sync-players` | elenco convocado e stats (`/rosters?seasons[]=2026`) → `jogadores` | `30 6 * * 1` |
| `sync-matches` | estrutura, datas, sede, mata-mata (`/matches`) | `0 5 * * *` |
| `sync-standings` | classificação dos grupos → `classificacao` | `10 5 * * *` e `*/10 * * * *` |
| `sync-live` | placar, status e eventos → `jogos` e `jogo_detalhes.eventos` | `* * * * *` |
| `sync-jogo-detalhes` | lineups, stats, shots, momentum, posições (ao vivo), best players (≤48h), team form (≤7d) | `* * * * *` |

### Regras

| Dado | Frescor prometido |
|---|---|
| Placar, eventos e detalhes da partida | a cada 1 minuto durante os jogos |
| Classificação dos grupos | a cada 10 minutos na fase de grupos; diária fora dela |
| Seleções, estádios e elencos | semanal |

| Quando | O produto garante |
|---|---|
| uma tela pede dado esportivo | ele vem das tabelas locais `selecoes`, `estadios`, `jogos`, `classificacao`, `jogadores` e `jogo_detalhes` |
| um sync de detalhe roda | `jogo_detalhes` guarda 1 linha por jogo, com uma coluna jsonb por seção (eventos, lineups, team_stats, shots, momentum, best_players, avg_positions, team_form) e timestamp de sync por seção, em replace total |
| a tela de elenco ou um picker de torneio carrega | o cache `jogadores` cobre só os convocados para a Copa 2026, nas 48 seleções, e jogador histórico não é armazenado |
| o dia não tem jogo | os dois crons de 1 min não disparam, porque o guard em SQL só chama a edge function se existir jogo em alguma janela; não há consumo da API |
| ainda é pré-Copa | o job diário do `sync-standings` roda sempre e captura sorteio e ajustes, e o de 10 min passa `{ onlyDuringCup: true }` e só atua na fase de grupos |
| alguém chama uma edge function de sync | ela exige `verify_jwt` com anon key; o header de shared-secret no lugar dele está `a definir` |
| um id de endpoint, tier ou gotcha da API muda | mora no código do conector, em `supabase/functions/`, e não neste documento |

## 15. Internacionalização (idiomas)

### Propósito

Atender a base do México e dos EUA no idioma dela sem partir o produto em três: a preferência é do usuário, e o Português segura tudo que ainda não foi traduzido. `no ar`

### Fluxo

Três idiomas na experiência do jogador: **Português** (base), **Espanhol** e **Inglês**. A preferência se persiste como o fuso horário, é detectada no 1º acesso pelo idioma do navegador e se ajusta em Configurações, sem prefixo de idioma na URL. `no ar`

| Peça | Papel |
|---|---|
| locale | cookie `NEXT_LOCALE` no SSR, com `profiles.locale` como fonte durável cross-device |
| UI estática | `messages/{pt,es,en}.json` (next-intl) |
| conteúdo curado | colunas `*_i18n` (JSONB `{pt,es,en}`), editadas nos campos ES/EN do CRUD admin; nome de seleção por `Intl.DisplayNames` |

### Regras

| Quando | O produto garante |
|---|---|
| o jogador escolhe um idioma | toda a experiência dele traduz: navegação, início, A Copa, calendário, palpites, torneio, álbum, grupo, perfil, streak, regras e notificações `no ar` |
| uma data, hora ou tempo relativo aparece | respeita o idioma escolhido `no ar` |
| o texto é administrativo ou veio do usuário | não traduz: a área admin é ferramenta interna em PT, e apelido, nome de grupo e nome de jogador ou cidade vindos da API ficam como estão `no ar` |
| falta a tradução numa coluna `*_i18n` | cai no Português, nunca em campo vazio `no ar` |
| o jogador acessa por URL de idioma | roteamento `/es` e `/en`, idiomas RTL e formatação de números por locale `previsto` |
