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

### Comportamento

Cadastro **aberto a qualquer pessoa**. Após criar a conta, todo usuário passa pela tela `/convite`, onde escolhe **entrar num grupo existente** (com um código) ou **criar o seu próprio grupo**. A reentrada de usuário existente é feita pela tela de login, que não cria conta.

Caminhos de entrada:

- **Landing / `/cadastro`:** qualquer um cria conta (email+senha ou Google/Apple)
- **Deep link `/entrar/:codigo`:** convite que já leva o código para o cadastro
- **Pós-cadastro (`/convite`):** sem grupo ainda, o usuário entra com um código OU cria um grupo novo

Ao criar um grupo, o usuário informa o **nome do grupo** e o sistema gera um **código de convite legível** (6 caracteres, sem caracteres ambíguos) que ele compartilha para os amigos entrarem. O criador vira admin do grupo.

Submit do cadastro cria a conta, faz o ingresso no grupo do convite e direciona para o onboarding (seção 11).

Login: email + senha, atalho com Google, atalho com Apple e link "Esqueci a senha" (recuperação por email).

### Contrato

| Campo do cadastro | Regra |
|---|---|
| Email | obrigatório |
| Nome | obrigatório |
| Apelido | obrigatório; é o nome exibido nos rankings e nas estatísticas do grupo |
| Senha | obrigatória; Google e Apple dispensam |

### Edge cases

- **Código inválido, expirado, grupo cheio ou encerrado:** `/entrar/erro` mostra o motivo e orienta pedir um novo código.
- **Código válido com sessão ativa:** sheet "Entrar no grupo X?" em vez do cadastro.

## 3. Estrutura de palpites

`no ar`

### Comportamento

**Por jogo:** resultado (V/E/D), placar exato e Pergunta Plus (seção 4).

**Long-term picks**, travados em 17/06/2026 às 23h59 na hora do último jogo da primeira rodada da fase de grupos: campeão, vice-campeão, 3º lugar, 4º lugar, artilheiro, Bola de Ouro (melhor jogador) e melhor jogador jovem (sub 21).

**Pontuação base (fase de grupos):**

| Tipo de palpite | Pontos |
|---|---|
| Acertou só o resultado (V/E/D) | 10 |
| Acertou resultado + saldo de gols correto | 18 |
| Acertou resultado + um dos placares correto | 22 |
| Placar exato | 35 |
| Pergunta Plus | 15 |
| Errou | 0 |

**Multiplicadores por fase:**

| Fase | Multiplicador |
|---|---|
| Fase de grupos | 1.0x |
| Round of 32 (16 jogos do primeiro mata-mata) | 1.25x |
| Oitavas (Round of 16) | 1.5x |
| Quartas | 2.0x |
| Semis | 2.5x |
| Disputa 3º lugar | 2.0x |
| Final | 3.0x |

> A Copa 2026 tem 48 seleções (contra 32 das anteriores), o que introduz uma fase extra antes das oitavas, o Round of 32, com 16 jogos. Total: 72 + 16 + 8 + 4 + 2 + 1 + 1 = 104 jogos.

**Long-term picks (pontuação fixa):**

| Palpite | Pontos |
|---|---|
| Campeão | 200 |
| Vice | 150 |
| 3º lugar | 100 |
| 4º lugar | 50 |
| Artilheiro | 150 |
| Bola de Ouro (melhor jogador) | 150 |
| Melhor Jogador Jovem (sub 21) | 150 |

Princípios da régua:

- Placar exato vale aproximadamente 3x o resultado simples
- Pontuação cresce ao longo da Copa via multiplicadores
- Acerto parcial conta (saldo correto ou um dos placares)
- Long-term picks pesam, mas não decidem sozinhos a Liga
- Sem pontos negativos: errar dá zero, sem ônus. O produto é lúdico, e punir o erro afasta o jogador casual

### Contrato

O cálculo mora na engine JS `lib/pontuacao`, com os helpers puros `agregarPontuacao` e `ordenarPosicoes` compartilhados por home, liga e perfil, que por isso mostram números idênticos. O schema dos palpites mora em `supabase/migrations/`.

### Edge cases

- **Jogo anulado / WO:** anula os palpites, ninguém pontua.
- **Mata-mata decidido nos pênaltis:** placar exato considera tempo normal + prorrogação (padrão FIFA).

## 4. Pergunta Plus sistemática

`no ar`

### Comportamento

Pergunta extra por jogo, validada automaticamente via provider de dados esportivos. Pool fixo definido antes da Copa, sem curadoria editorial, que não escala na operação.

| Pool | Perguntas |
|---|---|
| Fase de grupos | Total de gols acima de 2.5? · Ambas as seleções marcam? · Tem gol no primeiro tempo? · Mais de 3 cartões amarelos no jogo? · Algum gol depois dos 80 minutos? |
| Mata-mata | Decidido no tempo normal, prorrogação ou pênaltis? (3 alternativas) · Tem gol no primeiro tempo? · Ambas marcam? · Mais de 2.5 gols no tempo normal? · Alguma expulsão no jogo? |

- O sistema sorteia ou rotaciona uma pergunta do pool por jogo
- A pergunta fica visível até a hora do jogo iniciar
- Validação 100% automática via API
- Vale 15 pts base, multiplicado pela fase

### Contrato

A resposta certa se apura pelos eventos da partida em `jogo_detalhes.eventos` (seção 14).

### Edge cases

- **Jogo anulado:** a Plus anula junto com o palpite do jogo.

## 5. Janela de palpite

`no ar`

### Comportamento

| Tipo de palpite | Abre | Fecha |
|---|---|---|
| Long-term (campeão, artilheiro, etc.) | Lançamento do app | 17/06/2026 às 23h59, hora do último jogo da primeira rodada da fase de grupos |
| Jogo da fase de grupos | 72h antes do jogo | 5 min antes do início |
| Jogo de mata-mata | Quando definidos os classificados (fim da rodada anterior) | 5 min antes do início |
| Pergunta Plus | Junto com o palpite do jogo | 5 min antes do início |

- "Palpite aberto" verde, com contagem regressiva nas últimas 6h
- "Palpite fechado" cinza, mostra resultado se já jogou
- "Em breve" para palpite que vai abrir depois (apenas mata-mata)

### Contrato

Depois do início do jogo, `/palpites/jogos/[id]` redireciona para `/ao-vivo` (jogo rolando) ou `/resultado` (jogo encerrado), inclusive em acesso direto por URL. Os cards de jogo (calendário, início, lista de jogos) apontam para o destino do estado. O backend recusa salvar palpite fora da janela.

### Edge cases

- **Janela aberta e jogo adiado:** janela continua aberta até o novo horário menos 5 min
- **Janela fechada e jogo adiado:** palpites permanecem válidos pro novo horário, janela não reabre
- **Esquecimento de palpite:** zero pts no jogo, sem ônus adicional; o streak quebra se aplicável
- **Edição de palpite:** livre até o fechamento da janela, sem histórico público

## 6. Grupos

`no ar`

### Comportamento

Qualquer usuário **cria um grupo** em `/convite`, vira admin e recebe um código de convite legível. A entrada num grupo existente é por **código de convite**: deep link `/entrar/:codigo`, colando o código em `/convite` ou em `/grupo/entrar`. Não há lista pública de grupos.

- Cada grupo tem nome, descrição opcional e limite de membros
- Cada grupo tem uma Liga (seção 7)
- Múltiplos grupos por usuário, com seletor de grupo no topo da interface
- Palpite único compartilhado entre todos os grupos do usuário (faz uma vez, vale em todos)

Painel do admin do grupo: editar grupo, gerar código ou link de entrada, ver e remover membros, encerrar grupo e ver métricas básicas (membros ativos, palpites feitos, completude média do álbum).

Saída voluntária, a qualquer momento, por `/grupo/info`:

- Pontos acumulados na Liga do grupo saem do ranking
- Histórico de palpites permanece (palpite é compartilhado entre grupos)
- Reentrada no mesmo grupo só com novo convite do admin

### Contrato

| Regra | Valor |
|---|---|
| Código de convite | 6 caracteres, sem caracteres ambíguos |
| Limite de tamanho do grupo | `a definir` |

### Edge cases

- **Grupo encerrado:** o código deixa de valer e cai no erro de `/entrar/erro`.

## 7. Liga do grupo

### Comportamento

Ranking único do grupo, pelos pontos acumulados durante toda a Copa, atualizado a cada 10 minutos. `no ar`

Cascata de desempate, aplicada em ordem e parando no primeiro critério que diferencia: `no ar`

1. Mais placares exatos acertados na Copa toda
2. Mais palpites de torneio acertados (long-term)
3. Mais palpites totais feitos (engajamento)
4. Maior streak máximo atingido na Copa
5. Data de criação da conta (mais antiga vence)

Quando há empate, o ranking mostra qual critério está desempatando. Exemplo: "Empate em 1.247 pts. Iago à frente por mais placares exatos (12 vs 9)". `no ar`

**Ranking de álbum** `previsto`: um seletor de tipo de ranking (pills) alterna **Palpites** (padrão) e **Álbum**. O de Álbum ordena os membros pela completude (% de figurinhas distintas sobre o catálogo), no mesmo card do ranking de pontos: posição, avatar, "X de 154 figurinhas" com barra de progresso e o % em destaque. Tocar num membro abre o álbum dele.

- **Ranking puramente social, sem premiação:** completar o álbum não vale pontos na Liga: a economia do álbum e a competição não se misturam.
- **Desempate simples:** mais figurinhas distintas; persistindo, ordem alfabética de apelido. Sem cascata, porque não há prêmio em jogo.

### Contrato

Os dois rankings chegam no mesmo payload de `get_liga_resumo` (1 roundtrip, `CONVENTIONS.md` §3), e o seletor alterna client-side, sem nova request. O ranking de álbum expõe só a **contagem** por membro, com gate de mesmo grupo na RPC.

### Edge cases

- **Quais figurinhas cada um tem** continua visível só pelo álbum do membro, que tem o próprio gate.
- **Membro que saiu** some do ranking, com os pontos (seção 6).

## 8. Estatísticas do grupo

### Comportamento

Sub-aba 2 da aba Grupo (`/grupo/estatisticas`). Painel de estatísticas sociais derivadas dos palpites e do álbum, atualizado a cada jogo resolvido, sem depender de conteúdo produzido pelos membros.

| Bloco | O que mostra | Estado |
|---|---|---|
| Termômetro do grupo | total de palpites, % de acerto coletivo, placares exatos acumulados e maior streak ativo (com o dono) | `no ar` |
| Jogos de hoje | quem já palpitou todos os jogos do dia e quem ainda falta; pendente que é o próprio usuário ganha CTA "Palpitar" | `no ar` |
| Cutucada | membro cutuca quem ainda não palpitou, 1 por dupla por dia; vira notificação no sino do cutucado | `no ar` |
| Destaques do dia | craque do dia (mais pontos no último dia com jogos resolvidos), "na mosca" (placares exatos do dia) e "gelado" (errou todos do dia, mínimo 2) | `no ar` |
| Raio X dos jogos | por jogo encerrado: distribuição dos palpites (1/X/2), quantos acertaram o resultado, quem cravou o placar e a lista de palpites revelados | `no ar` |
| Zebra e consenso | jogo recente em que 80%+ do grupo (mínimo 3 palpites) apostou num lado e deu outro; jogo em que o grupo inteiro acertou | `no ar` |
| Álbum do grupo | cobertura coletiva, quem está mais perto de completar e a figurinha mais rara do grupo (menos donos) | `previsto` |

### Contrato

RPC consolidada `get_grupo_estatisticas` (1 roundtrip), agregação na engine JS `lib/estatisticas-grupo`. Tudo deriva de `jogos` e das tabelas de palpites e de álbum; nenhuma tabela própria.

### Edge cases

- **Palpite de terceiros** só aparece depois do início do jogo (o mesmo gate das RPCs de ranking). É o Raio X que materializa a regra "após o apito final, o palpite vira público".
- **"Quem já palpitou hoje"** expõe só o fato de ter palpitado, nunca o conteúdo.
- **Figurinha mais rara com dono único:** expõe nome e dono, o mesmo nível de visibilidade do álbum do membro.

## 9. Álbum de figurinhas

`previsto`

### Comportamento

154 figurinhas em 4 coleções temáticas, todas definidas antes do início da Copa (sem dependência de convocação oficial).

| Coleção | Figurinhas | Conteúdo |
|---|---|---|
| 1. Seleções | 48 | 1 figurinha por seleção (escudo, uniforme, cores) |
| 2. Cidades sedes | 16 | As 16 cidades sedes da Copa do Mundo |
| 3. Lendas do Mundial | 60 | 5 lendas por país, 12 nações historicamente relevantes |
| 4. Momentos Históricos | 30 | Cenas icônicas de Copas anteriores |
| **Total** | **154** | |

Ilustração estilizada gerada por IA, com identidade única entre as 4 coleções: estilo de referência, paleta consistente, enquadramento padrão, família de fundos e curadoria humana antes de publicar.

**Sem raridade.** Todas as 154 têm a mesma chance de cair em qualquer pacote. Tornar uma lenda como Pelé mais difícil penalizaria completar a coleção sem ganho de engajamento proporcional, e a distribuição uniforme elimina a discussão regulatória sobre probabilidade pública de drop.

| Pacotes | Regra |
|---|---|
| Tamanho | 3 figurinhas |
| Drop diário base | 2 pacotes por resgate ativo (clique manual) |
| Extra por palpitar | +1 por palpitar em pelo menos 1 jogo no dia |
| Extra por acerto | +1 por palpite de resultado acertado (vencedor ou empate, não o placar exato) |
| Extra por missões | +1 ao completar as 3 missões do dia |
| Extra por streak | marcos de streak (seção 10) |

**Troca entre amigos:** listas "Tenho" e "Quero" visíveis dentro do grupo, troca 1×1 com confirmação dupla, sem moeda intermediária e sem leilão.

**Colecionável puro:** sem boost no jogo e sem impacto na pontuação da Liga.

Economia esperada ao longo da Copa (~30 dias), que cria gradiente entre níveis de engajamento sem nenhum nível ser punitivo:

| Perfil | Pacotes | Figurinhas | Comportamento esperado |
|---|---|---|---|
| Super engajado | ~260 | ~780 | Completa o álbum com folga, gera muitas repetidas para troca |
| Médio | ~140 | ~420 | Completa boa parte do álbum, depende de troca para fechar |
| Casual | ~80 | ~240 | Avança em algumas coleções, não completa |

### Contrato

Lista item a item das 154 figurinhas (IDs `S001` a `S154`, tema de cada uma) em **`Sticker.md`**. Geração das imagens via OpenAI por `scripts/generate-stickers.mjs`, que lê o `Sticker.md` e o Estilo Mestre. Coleções 1 e 2 vêm da API BallDontLie; coleções 3 e 4 são curadoria editorial. O catálogo é público e estável, e usa cache cross-request.

### Edge cases

- **Figurinha já comprometida:** ao montar uma troca, as figurinhas de "Você oferece" que já estão em outra troca pendente aparecem esmaecidas, com o selo "Ofertada para [Apelido]" (`+N` com mais de um destinatário). É só aviso: o usuário ainda pode selecioná-las.

## 10. Streak diário

### Comportamento

Mantém o streak quem, no dia, resgata pelo menos um pacote do álbum ou faz pelo menos 1 palpite. `no ar`

- 24h sem ação de manutenção zera o streak `no ar`
- Fuso de Brasília (público nacional), reset à meia-noite local `no ar`
- Sem mecanismo de "salvar streak" `no ar`
- Streak máximo registrado no perfil mesmo depois de quebrar `no ar`
- Sem multiplicador de pontos e sem selo visual por streak `no ar`

Recompensas por marco, em pacotes do álbum `previsto`:

| Dias consecutivos | Recompensa |
|---|---|
| 3 dias | +1 pacote bônus |
| 7 dias | +2 pacotes bônus |
| 14 dias | +3 pacotes bônus |
| 21 dias | +4 pacotes bônus |
| 30 dias | +7 pacotes bônus |

### Contrato

O streak máximo alimenta o critério 4 de desempate da Liga (seção 7) e o calendário de `/perfil/streak`.

### Edge cases

- **Cada marco dispara uma única vez**, sem recorrência.
- **Esquecimento de palpite** quebra o streak só se não houve resgate de pacote no dia.

## 11. Onboarding pós-cadastro

`no ar`

### Comportamento

Fluxo de 6 passos exibido **uma única vez**, logo após o primeiro cadastro, com "Pular" em todos os passos. Ao concluir ou pular, direciona para `/grupo/liga`.

1. **Palpites.** Como funciona a pontuação base e os multiplicadores por fase
2. **Grupo e Liga.** Explica o ranking e os critérios de desempate
3. **Pergunta Plus.** Como funciona a pergunta extra por jogo
4. **Álbum.** Apresenta o álbum, drop diário, missões e trocas `previsto`
5. **Streak e missões.** Como manter o streak e ganhar pacotes extras
6. **Boas-vindas ao grupo "X".** Finaliza chamando o nome do grupo do convite

### Contrato

Concluir ou pular grava `onboarded: true` na conta.

### Edge cases

- **Reabertura:** `/perfil/ajuda` ("Ver tour novamente") reabre o fluxo sem alterar a flag `onboarded`.

## 12. Ao vivo durante o jogo

`no ar`

### Comportamento

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

### Contrato

O client faz polling de 20s do snapshot pela rota estável `GET /api/jogos/[id]/ao-vivo`. Os dados-fonte chegam minuto a minuto pelas edge functions da seção 14. As badges de substituição cruzam lineup com os eventos de substituição.

### Edge cases

- **Deploy no meio da partida:** a rota de snapshot sobrevive à troca de build; após falhas consecutivas o client se recupera com um reload único e transparente.
- **Gol anulado pelo VAR:** aparece riscado no feed, e o replace total de `jogo_detalhes` a cada sync resolve o placar sem reconciliar por id.

## 13. Notificações

### Comportamento

O sino no header de cada aba abre `/notificacoes`, a tela única com o histórico cronológico. `no ar`

Push fora do app, via **Web Push** com o app instalado como PWA: o sino deriva o feed ao vivo para o app aberto, e o push avisa no device mesmo com o app fechado. `no ar`

- **Default opt-out:** todas as categorias já vêm ligadas para o usuário novo, e ele desliga o que não quer em `/perfil/notificacoes`. A permissão do browser é sempre pedida por gesto explícito (um toggle "Receber notificações push" por dispositivo).
- **Anti-spam:** no máximo **1 push por evento por usuário**, sem agrupar eventos, e cada fonte só olha eventos recentes (acerto nas últimas 3h, drop nas últimas 24h, cutucada nas últimas 6h): ninguém recebe histórico antigo.

| Evento | Categoria em `notif_prefs` | Destino do deep link | Estado |
|---|---|---|---|
| Palpite fechando em ~1h, sem palpite | `lembrete_palpite` | `/palpites/jogos/:id` | `no ar` |
| Resultado / acertou palpite | `resultado_jogo` | `/palpites/jogos/:id/resultado` | `no ar` |
| Cutucada recebida | `cutucada` | `/palpites/jogos` | `no ar` |
| Convite recebido (sessão ativa) | | sheet de confirmação → `/grupo/liga` | `no ar` |
| Drop diário disponível | `drop` | `/album/drop-diario` | `previsto` |
| Oferta de troca recebida | `troca` | `/album/trocas/:id` | `previsto` |
| Ranking e marco de streak | | | `previsto` |

### Contrato

| Peça | Contrato |
|---|---|
| `push_subscriptions` | endpoint e chaves por device, RLS self |
| `push_enviados` | dedupe por `(user, chave)`, só service role |
| RPC `get_pushes_pendentes()` | SECURITY DEFINER, só `service_role`: devolve o que falta enviar, já filtrado por `notif_prefs`, janela de recência e existência de assinatura |
| edge function `send-push` | fan-out VAPID (`web-push`) pros devices do usuário, grava em `push_enviados`, remove assinatura morta (404/410); `pg_cron` a cada 2 min, com guard em SQL (só invoca se houver assinatura) |
| `public/sw.js` | handlers `push` (mostra) e `notificationclick` (foca ou abre no deep link) |
| `src/lib/push/client.ts` | pede permissão, assina com `NEXT_PUBLIC_VAPID_PUBLIC_KEY`, persiste via server action |

A chave de dedupe é estável, `push-<tipo>:<id>`, e a `tag` da notificação reusa a chave: re-disparo substitui em vez de empilhar. Chave ausente em `notif_prefs` conta como ativa.

### Edge cases

- **iOS/iPadOS** exige **16.4+** e o app **adicionado à tela de início** (standalone); em aba normal do Safari não funciona, e a UI comunica isso. Android, Chrome, Edge, Firefox e desktop funcionam sem essa amarra.
- **Primeiro deploy:** a janela de recência impede disparar histórico acumulado.
- **Canal alternativo para quem não habilitou push:** `a definir`.

## 14. Dados e sincronização (BallDontLie)

`no ar`

### Comportamento

Toda tela esportiva (seleções, estádios, jogos, placares, chaveamento) mostra dado real da API BallDontLie FIFA World Cup, lido de um cache local; o browser nunca consulta a API. A regra de construção por trás está no `CONVENTIONS.md` §2.

| Dado | Frescor prometido |
|---|---|
| Placar, eventos e detalhes da partida | a cada 1 minuto durante os jogos |
| Classificação dos grupos | a cada 10 minutos na fase de grupos; diária fora dela |
| Seleções, estádios e elencos | semanal |

O cache `jogadores` alimenta a tela de elenco por seleção (`/inicio/copa/selecao/[id]`) e os pickers de torneio (artilheiro, bola de ouro, jovem revelação). A base é **só os convocados para a Copa 2026**: cobre as 48 seleções e o vínculo jogador↔seleção, e jogador histórico não é armazenado.

### Contrato

| Peça | Contrato |
|---|---|
| tabelas locais | `selecoes`, `estadios`, `jogos`, `classificacao`, `jogadores`, `jogo_detalhes` |
| `jogo_detalhes` | 1 linha por jogo, uma coluna jsonb por seção (eventos, lineups, team_stats, shots, momentum, best_players, avg_positions, team_form) e timestamp de sync por seção; replace total a cada sync |

| Function | Conteúdo | Cron |
|---|---|---|
| `sync-reference` | seleções (`/teams`) e estádios (`/stadiums`) | `0 6 * * 1` |
| `sync-players` | elenco convocado e stats (`/rosters?seasons[]=2026`) → `jogadores` | `30 6 * * 1` |
| `sync-matches` | estrutura, datas, sede, mata-mata (`/matches`) | `0 5 * * *` |
| `sync-standings` | classificação dos grupos → `classificacao` | `10 5 * * *` e `*/10 * * * *` |
| `sync-live` | placar, status e eventos → `jogos` e `jogo_detalhes.eventos` | `* * * * *` |
| `sync-jogo-detalhes` | lineups, stats, shots, momentum, posições (ao vivo), best players (≤48h), team form (≤7d) | `* * * * *` |

Agendamento por `pg_cron` + `pg_net`. `sync-balldontlie`, o sync completo num job só, serve só a backfill manual. Id de endpoint, tier exigido e gotcha da API moram no código do conector, em `supabase/functions/`, não aqui.

### Edge cases

- **Fora de dia de jogo** os dois crons de 1 min não disparam: o guard em SQL só chama a edge function se existir jogo em alguma janela, então não há consumo da API.
- **Pré-Copa:** o job diário do `sync-standings` roda sempre e captura sorteio e ajustes; o de 10 min passa `{ onlyDuringCup: true }` e só atua na fase de grupos.
- **Proteção das edge functions de sync:** `verify_jwt` com anon key; o header de shared-secret no lugar dele está `a definir`.

## 15. Internacionalização (idiomas)

### Comportamento

Três idiomas na experiência do jogador: **Português** (base), **Espanhol** e **Inglês**, para a base de usuários no México e nos EUA além do Brasil. `no ar`

- **Preferência por usuário:** persistida como o fuso horário, detectada no 1º acesso (idioma do navegador) e ajustável em Configurações. Sem prefixo de idioma na URL. Fallback sempre para Português. `no ar`
- Datas, horas e tempo relativo respeitam o idioma escolhido. `no ar`
- **Traduzido:** toda a experiência do jogador (navegação, início, A Copa, calendário, palpites, torneio, álbum, grupo, perfil, streak, regras, notificações). `no ar`
- **Não traduzido:** área administrativa (ferramenta interna, em PT) e conteúdo gerado por usuário (apelidos, nomes de grupos, nomes de jogadores e cidades vindos da API).
- Roteamento por URL (`/es`, `/en`), idiomas RTL e formatação de números por locale. `previsto`

### Contrato

| Peça | Contrato |
|---|---|
| locale | cookie `NEXT_LOCALE` no SSR, com `profiles.locale` como fonte durável cross-device |
| UI estática | `messages/{pt,es,en}.json` (next-intl) |
| conteúdo curado | colunas `*_i18n` (JSONB `{pt,es,en}`) com fallback PT, editadas nos campos ES/EN do CRUD admin; nome de seleção por `Intl.DisplayNames` |

### Edge cases

- **Tradução ausente** numa coluna `*_i18n` cai no PT, nunca em campo vazio.
