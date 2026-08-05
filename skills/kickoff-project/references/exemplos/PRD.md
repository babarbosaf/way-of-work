# PRD: Bolão Copa do Mundo 2026

## 1. Visão geral

Produto standalone gratuito de bolão para a Copa do Mundo FIFA 2026, voltado para o lúdico, interação social e competição entre amigos. 

O produto se sustenta em três motores principais de engajamento:

1. **Palpites** que premiam tanto V/E/D quanto placar exato, com multiplicadores crescentes por fase do torneio
2. **Grupos privados entre amigos** com ranking de Liga e estatísticas sociais do grupo
3. **Álbum de figurinhas digital** com 154 figurinhas em 4 coleções, sistema de troca e drop diário (v2)

## 2. Cadastro e identidade

### Modelo

Cadastro **aberto a qualquer pessoa**. Após criar a conta, todo usuário passa pela tela `/convite`, onde escolhe **entrar num grupo existente** (com um código) ou **criar o seu próprio grupo**. A reentrada de usuário existente é feita pela tela de login.

### Cadastro (aberto)

Caminhos de entrada:

- **Landing / `/cadastro`:** qualquer um cria conta (email+senha ou Google/Apple)
- **Deep link `/entrar/:codigo`:** convite que já leva o código para o cadastro
- **Pós-cadastro (`/convite`):** sem grupo ainda, o usuário entra com um código OU cria um grupo novo

Ao criar um grupo, o usuário informa o **nome do grupo** e o sistema gera um **código de convite legível** (6 caracteres, sem caracteres ambíguos) que ele compartilha para os amigos entrarem. O criador vira admin do grupo.

Estados do código de convite ao entrar:

- **Código inválido, expirado, grupo cheio ou encerrado:** mensagem orientando pedir um novo código

Campos obrigatórios no cadastro:

- Email
- Nome
- Apelido/nickname (exibido nos rankings e nas estatísticas do grupo)
- Senha

Atalhos no cadastro:

- Cadastro com Google
- Cadastro com Apple

Submit cria a conta, faz o ingresso no grupo do convite e direciona para o onboarding (seção 12).

### Login (reentrada de usuário existente)

- Email + senha
- Atalho com Google
- Atalho com Apple
- Link "Esqueci a senha" (recuperação por email)

A criação de conta fica na landing e em `/cadastro`; a tela de login é só reentrada.

## 3. Estrutura de palpites

### Tipos de palpite

**Por jogo:**
- Resultado (V/E/D)
- Placar exato
- Pergunta Plus (sistemática, ver seção 4)

**Long-term picks** (travados no dia 17/06/2026 as 23h59 hora que aconteceu o último jogo da primeira rodada da fase de grupos):

- Campeão
- Vice-campeão
- 3º lugar
- 4º lugar
- Artilheiro
- Bola de Ouro (Melhor Jogador)
- Melhor Jogador Jovem (sub 21)

### Régua de pontuação

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

> A Copa 2026 tem 48 seleções (vs. 32 das anteriores), o que introduziu uma fase extra antes das oitavas — "Round of 32", com 16 jogos. Total: 72 + 16 + 8 + 4 + 2 + 1 + 1 = 104 jogos.

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
|                               |        |

### Princípios da pontuação

- Placar exato vale aproximadamente 3x o resultado simples
- Pontuação cresce ao longo da Copa via multiplicadores
- Acerto parcial conta (saldo correto ou um dos placares)
- Long-term picks pesam, mas não decidem sozinhos a Liga
- Sem pontos negativos: errar dá zero, sem ônus

## 4. Pergunta Plus sistemática

### Modelo

Pergunta extra por jogo, validada automaticamente via provider de dados esportivos. Pool fixo definido antes da Copa, sem dependência de curadoria editorial.

### Pool para fase de grupos

- Total de gols acima de 2.5?
- Ambas as seleções marcam?
- Tem gol no primeiro tempo?
- Mais de 3 cartões amarelos no jogo?
- Algum gol depois dos 80 minutos?

### Pool para mata-mata

- Decidido no tempo normal, prorrogação ou pênaltis? (3 alternativas)
- Tem gol no primeiro tempo?
- Ambas marcam?
- Mais de 2.5 gols no tempo normal?
- Alguma expulsão no jogo?

### Regras

- Sistema sorteia ou rotaciona uma pergunta do pool por jogo
- Pergunta visível até a hora do jogo iniciar. 
- Validação 100% automática via API.
- Vale 15 pts base, multiplicado pela fase

## 5. Janela de palpite

| Tipo de palpite | Abre | Fecha |
|---|---|---|
| Long-term (campeão, artilheiro, etc.) | Lançamento do app | 17/06/2026 as 23h59 hora do último jogo da primeira rodada da fase de grupo |
| Jogo da fase de grupos | 72h antes do jogo | 5 min antes do início |
| Jogo de mata-mata | Quando definidos os classificados (fim da rodada anterior) | 5 min antes do início |
| Pergunta Plus | Junto com o palpite do jogo | 5 min antes do início |

### Visualização

- "Palpite aberto" verde, com contagem regressiva nas últimas 6h
- "Palpite fechado" cinza, mostra resultado se já jogou
- "Em breve" para palpite que vai abrir depois (apenas mata-mata)
- **Tela de palpite inacessível após o início do jogo:** `/palpites/jogos/[id]` redireciona para `/ao-vivo` (jogo rolando) ou `/resultado` (jogo encerrado), inclusive em acesso direto por URL. Os cards de jogo (calendário, início, lista de jogos) apontam para o destino correspondente ao estado. O backend reforça a regra recusando salvar palpite fora da janela

### Edge cases

- **Jogo anulado / WO:** anula os palpites, ninguém pontua
- **Mata-mata decidido nos pênaltis:** placar exato considera tempo normal + prorrogação (padrão FIFA)
- **Janela aberta e jogo adiado:** janela continua aberta até o novo horário menos 5 min
- **Janela fechada e jogo adiado:** palpites permanecem válidos pro novo horário, janela não reabre
- **Esquecimento de palpite:** ganha zero pts no jogo, sem ônus adicional, streak quebra se aplicável
- **Edição de palpite:** livre quantas vezes quiser até o fechamento da janela, sem histórico público

## 6. Grupos

### Modelo no MVP

Grupos criados exclusivamente por usuário Admin via painel administrativo. Não há criação de grupos pelo usuário final no MVP.

### Estrutura

- Cada grupo tem nome, descrição opcional e limite de membros
- Cada grupo tem uma Liga (ranking por pontos acumulados)
- Múltiplos grupos por usuário, com seletor de grupo no topo da interface
- Palpite único compartilhado entre todos os grupos do usuário (faz uma vez, vale em todos)

### Painel admin (acessível apenas ao Admin)

- Criar grupo (nome, descrição, limite de membros)
- Editar grupo
- Gerar código/link de entrada
- Ver lista de membros
- Remover membro
- Encerrar grupo
- Ver métricas básicas (membros ativos, palpites feitos, completude média do álbum)

### Caminho de entrada

Qualquer usuário pode **criar um grupo** (na tela `/convite` pós-cadastro), virando admin e recebendo um código de convite legível para compartilhar. A entrada num grupo existente é por **código de convite**: deep link `/entrar/:codigo`, colando o código em `/convite` (pós-cadastro) ou em `/grupo/entrar`. Não há lista pública de grupos no MVP.

### Saída voluntária

Usuário pode sair do grupo a qualquer momento via `/grupo/info`. Ao sair:

- Pontos acumulados na Liga do grupo são removidos do ranking
- Histórico de palpites do usuário permanece (palpite é compartilhado entre grupos)
- Reentrada no mesmo grupo só é possível com novo convite do admin

### Pontos a definir antes do desenvolvimento

- Cenário de uso dos grupos admin-only (oficial nacional, afinidade, sob demanda, teste)
- Limite de tamanho do grupo (a definir conforme cenário de uso)

## 7. Liga do grupo

### Funcionamento

Ranking único do grupo, baseado em pontos acumulados durante toda a Copa. Deve ser atualizada a cada 10 minutos. 

### Cascata de critérios de desempate

Aplicada em ordem, para no primeiro critério que diferencia:

1. Mais placares exatos acertados na Copa toda
2. Mais palpites de torneio acertados (long-term)
3. Mais palpites totais feitos (engajamento)
4. Maior streak máximo atingido na Copa
5. Data de criação da conta (mais antiga vence)

### Visualização do desempate

Quando há empate, o ranking mostra qual critério está desempatando. Exemplo: "Empate em 1.247 pts. Iago à frente por mais placares exatos (12 vs 9)".

### Ranking de álbum (seletor na Liga)

Além do ranking de pontos, a tela da Liga tem um **seletor de tipo de ranking** (pills): **Palpites** (padrão) e **Álbum**. O ranking de Álbum ordena os membros pela **completude do álbum de figurinhas** (% de figurinhas distintas obtidas sobre o total do catálogo), no mesmo design de card do ranking de pontos — posição, avatar, "X de 154 figurinhas" com barra de progresso e o % em destaque. Tocar num membro abre o álbum dele.

Decisões:

- **Ranking puramente social, sem premiação:** completar o álbum não vale pontos na Liga — mantém a separação economia social (álbum) × competição (Liga) registrada na seção 14.
- **Desempate simples:** mais figurinhas distintas; persiste empate, ordem alfabética de apelido. Sem cascata de critérios — não há prêmio em jogo.
- **Privacidade:** o ranking expõe apenas a **contagem** por membro (RPC com gate de mesmo grupo); quais figurinhas cada um tem continua visível só pelo álbum do membro, que já tem seu próprio gate.
- **Troca instantânea:** os dois rankings chegam no mesmo payload da Liga (1 roundtrip — CONVENTIONS.md, seção 6) e o seletor alterna client-side, sem nova request.

## 8. Estatísticas do grupo

### Modelo

Sub-aba 2 da aba Grupo (`/grupo/estatisticas`). Painel de estatísticas sociais derivadas dos palpites e do álbum, atualizado automaticamente a cada jogo resolvido — não depende de conteúdo produzido pelos membros.

> **Nota de escopo:** substituiu o **Mural** (feed cronológico de eventos) em 12/06/2026. O mural dependia de eventos automáticos do sistema que nunca foram implementados e ficou sem uso. As tabelas (`mural_eventos`, `mural_reacoes`, `mural_comentarios`) foram mantidas no banco; o feed pode voltar como v2 se os eventos automáticos forem implementados.

### Blocos da tela

- **Termômetro do grupo:** total de palpites, % de acerto coletivo, placares exatos acumulados e maior streak ativo (com o dono).
- **Jogos de hoje:** quem já palpitou todos os jogos do dia e quem ainda falta (expõe só o fato de ter palpitado, nunca o conteúdo). Pendente que é o próprio usuário ganha CTA "Palpitar".
- **Cutucada:** membro pode cutucar quem ainda não palpitou (1 cutucada por dupla por dia). Vira notificação no sino do cutucado.
- **Destaques do dia:** craque do dia (mais pontos no último dia com jogos resolvidos), "na mosca" (placares exatos do dia) e "gelado" (errou todos os palpites do dia, mínimo 2).
- **Raio X dos jogos:** para cada jogo encerrado, distribuição dos palpites do grupo (1/X/2), quantos acertaram o resultado, quem cravou o placar e a lista completa de palpites revelados. Materializa a regra "após o apito final, o palpite vira público".
- **Zebra e consenso:** jogo recente em que 80%+ do grupo (mínimo 3 palpites) apostou num lado e deu outro; jogo em que o grupo inteiro acertou.
- **Álbum do grupo:** cobertura coletiva (% de figurinhas que já apareceram em algum membro), quem está mais perto de completar e a figurinha mais rara do grupo (menos donos; expõe nome e dono único — mesmo nível de visibilidade do álbum do membro).

### Privacidade

- Palpite de terceiros só é exposto depois do início do jogo (mesmo gate das RPCs de ranking).
- "Quem já palpitou hoje" expõe apenas a contagem, não o conteúdo.

### Dados

- Tudo deriva das tabelas já sincronizadas com a BallDontLie (`jogos`, via crons existentes) e das tabelas de palpites/álbum. RPC consolidada `get_grupo_estatisticas` (1 roundtrip, CONVENTIONS.md seção 6); agregação na engine JS (`lib/estatisticas-grupo`).

## 9. Álbum de figurinhas

### Estrutura

154 figurinhas distribuídas em 4 coleções temáticas, todas definidas antes do início da Copa (sem dependência de convocação oficial).

| Coleção | Figurinhas | Conteúdo |
|---|---|---|
| 1. Seleções | 48 | 1 figurinha por seleção (escudo, uniforme, cores) |
| 2. Cidades sedes | 16 | As 16 cidades sedes da Copa do Mundo |
| 3. Lendas do Mundial | 60 | 5 lendas por país, 12 nações historicamente relevantes |
| 4. Momentos Históricos | 30 | Cenas icônicas de Copas anteriores |
| **Total** | **154** | |

### Estilo visual

Ilustração estilizada gerada via IA, com identidade visual única e consistente entre as 4 coleções. Requisitos de produção:

- Estilo visual único definido como referência
- Paleta de cores consistente
- Enquadramento padrão
- Fundo padrão ou família de fundos
- Curadoria humana sobre as saídas da IA antes de publicação

### Distribuição em pacotes

Sem sistema de raridade. Todas as 154 figurinhas têm a mesma probabilidade de cair em qualquer pacote (distribuição aleatória uniforme).

Racional: o produto é colecionável e social, voltado a completar o álbum. Tornar uma lenda como Pelé mais difícil que outras figurinhas penalizaria a chance de completar a coleção sem trazer ganho de engajamento proporcional. A simplicidade também elimina toda a discussão regulatória adjacente a probabilidades públicas de drop.

### Pacotes

- **Tamanho do pacote:** 3 figurinhas
- **Drop diário base:** 2 pacotes por resgate ativo (clique manual)
- **Pacotes extras:**
  - +1 por palpitar em pelo menos 1 jogo no dia
  - +1 por palpite de resultado acertado (vencedor ou empate, não o placar exato)
  - +1 ao completar as 3 missões do dia
  - Pacotes por marcos de streak (ver seção 10: 3/7/14 dias → +1/+2/+3)

### Troca entre amigos

- Lista "Tenho" e "Quero" visível dentro do grupo
- Troca 1×1 com confirmação dupla
- Sem moeda intermediária, sem leilão
- **Indicativo de figurinha já comprometida:** ao montar uma troca, as figurinhas do lado "Você oferece" que já estão sendo oferecidas em outra troca ativa (pendente) aparecem esmaecidas e com o selo "Ofertada para [Apelido]" (`+N` quando há mais de um destinatário). É só um aviso — o usuário ainda pode selecioná-las normalmente.

### Utilidade

Colecionável puro, sem boost no jogo, sem impacto na pontuação da Liga.

### Curadoria fina

Lista item a item das 154 figurinhas (IDs `S001`–`S154`, tema de cada uma) definida em **`Sticker.md`**. Geração das imagens via OpenAI automatizada por `scripts/generate-stickers.mjs` (lê o `Sticker.md` + Estilo Mestre). Coleções 1 e 2 (seleções e cidades) vêm da API do BallDontLie; coleções 3 e 4 (lendas e momentos) são curadoria editorial.

## 10. Streak diário

### Como manter

Usuário precisa fazer pelo menos um destes no dia:
- Resgatar pelo menos um pacote do álbum
- Fazer pelo menos 1 palpite

### Reset

- 24h sem ação de manutenção zera o streak
- Fuso de Brasília (público nacional)
- Reset à meia-noite local
- Sem mecanismo de "salvar streak"

### Streak máximo histórico

Registrado no perfil mesmo depois de quebrar.

### Recompensas por milestones

| Dias consecutivos | Recompensa |
|---|---|
| 3 dias | +1 pacote bônus |
| 7 dias | +2 pacotes bônus |
| 14 dias | +3 pacotes bônus |
| 21 dias | +4 pacotes bônus |
| 30 dias | +7 pacotes bônus |

Cada milestone dispara uma única vez, não recorrente.

### Não inclui

- Multiplicador de pontos por streak
- Selos visuais por streak



## 11. Ao vivo durante o jogo

A tela do jogo (`/palpites/jogos/[id]/ao-vivo`) é rica em dados reais da BallDontLie (tier GOAT) e muda conforme o estado da partida. O client faz polling de 20s do snapshot via rota estável (`GET /api/jogos/[id]/ao-vivo`); os dados-fonte são sincronizados **minuto a minuto** pelas edge functions (ver seção 16).

**Garantia de atualização sem refresh:** a tela se mantém atualizada sozinha durante todo o jogo, mesmo se um deploy acontecer no meio da partida (a rota de snapshot sobrevive à troca de build; após falhas consecutivas o client se recupera com um reload único e transparente). Ao voltar para o app (desbloquear o celular, trocar de aba), o snapshot é rebuscado na hora, sem esperar o próximo ciclo. A troca de dados é silenciosa: nada de spinner nem re-render quando o snapshot não mudou.

### Pré-jogo (tela de palpite)

- Ficha do jogo: estádio (com capacidade), árbitro, técnicos
- Escalação **real** (titulares com formação + banco) quando publicada; antes disso, formação provável + técnico
- "Como chegam": classificação no grupo + forma recente da BDL (nota média e forma), que aparece quando a API publica o `team_form`

### Ao vivo

- Placar ao vivo com animação de gol e pênaltis
- **Pressão do jogo** (momentum minuto a minuto, gráfico de barras; some no pós-jogo)
- **Card unificado da partida** com abas — Lances (principal), Estatísticas, Chutes, Posições e Escalações — posicionado logo abaixo do placar/momentum. Troca de aba por toque ou **gesto lateral (swipe)**; abas sem dados não aparecem:
  - **Lances**: feed minuto a minuto com gols (autor, assistência, placar momentâneo), cartões, substituições, decisões do VAR (gol anulado aparece riscado), fim de tempo e disputa de pênaltis
  - **Estatísticas**: barras comparativas (posse, xG, finalizações, escanteios, passes certos etc.)
  - **Chutes**: campinho com o mapa de chutes (raio do ponto cresce com o xG)
  - **Posições**: campinho com as posições médias dos jogadores
  - **Escalações**: titulares (com formação) + banco, badges de quem entrou/saiu (cruzamento lineup × eventos de substituição), com toggle de país como segunda hierarquia dentro da aba
- **Card "Seu palpite"** unificado: junta o palpite de placar e a Pergunta Plus do jogo num só card, com o total parcial "valendo" no topo (placar + Plus já apurada) e o placar **destrinchado por nível** logo abaixo. Em vez de só um badge "valendo +X", mostra a faixa da régua atingida com o placar corrente (placar exato, resultado + um placar, resultado + saldo, resultado, ou não acertou) e os pontos abertos de cada parte. A linha da Plus preserva a pergunta, a resposta do usuário, a parcial "se terminasse agora" (vira "Real" no encerramento) e quanto está valendo. No pós-jogo o card congela como pontuação final; mesma régua e estética da seção "Sua pontuação" da tela de resultado
- **Palpites do Grupo**: somente os membros do **grupo ativo**, ranqueados pela **estimativa de pontos com o placar corrente** (placar + Pergunta Plus já apurada) — mesmo formato do pós-jogo: posição, tag "Cravou" e badge "Valendo +X"

### Pós-jogo

- Tudo do ao vivo (exceto o momentum), congelado no resultado final
- **Craque da partida** (man of the match com rating) + melhores notas do jogo
- A tela de resultado (`/palpites/jogos/[id]/resultado`) traz o link "Veja como foi a partida" junto ao placar, levando à revisão pós-jogo acima

## 12. Onboarding pós-cadastro

### Modelo

Fluxo de 6 passos exibido **uma única vez**, logo após o primeiro cadastro. Botão "Pular" disponível em todos os passos. Ao concluir ou pular, marca-se a flag `onboarded: true` na conta e direciona para `/grupo/liga`.

### Passos

1. **Palpites** — como funciona a pontuação base e os multiplicadores por fase
2. **Grupo e Liga** — explica o ranking e os critérios de desempate
3. **Pergunta Plus** — como funciona a pergunta extra por jogo
4. **Álbum** — apresenta o álbum, drop diário, missões e trocas
5. **Streak e missões** — como manter o streak e ganhar pacotes extras
6. **Boas-vindas ao grupo "X"** — finaliza chamando o nome do grupo do convite

### Reabertura

O onboarding pode ser revisto a qualquer momento via `/perfil/ajuda` ("Ver tour novamente"), sem alterar a flag `onboarded`.

## 13. Economia de pacotes (calibração esperada)

Projeção de figurinhas geradas por perfil de usuário ao longo da Copa (~30 dias):

| Perfil | Pacotes estimados | Figurinhas geradas | Comportamento esperado |
|---|---|---|---|
| Super engajado | ~260 | ~780 | Completa o álbum com folga, gera muitas repetidas para troca |
| Médio | ~140 | ~420 | Completa boa parte do álbum, depende de troca para fechar |
| Casual | ~80 | ~240 | Avança em algumas coleções, não completa |

A distribuição cria gradiente entre níveis de engajamento sem nenhum nível ser punitivo.

## 14. Decisões estratégicas registradas

Para contexto futuro do time, decisões importantes tomadas durante o desenho:

- **Sem pontos negativos:** filosofia de produto lúdico, não punir o erro
- **Álbum colecionável puro, sem boost:** separa a economia social (álbum) da competição (Liga)
- **Sem sistema de raridade nas figurinhas:** todas as 154 figurinhas têm a mesma probabilidade de drop. Raridade penalizaria a chance de completar o álbum (uma figurinha do Pelé não pode ser mais difícil que as outras) e eliminaria a discussão regulatória adjacente a probabilidades públicas de drop
- **Criação de grupos aberta:** qualquer usuário cria um grupo (virando admin) e recebe um código de convite legível para compartilhar. Substitui a decisão anterior de grupos admin-only/convite-only — reduz fricção de entrada e permite crescimento orgânico
- **Cadastro aberto:** qualquer pessoa cria conta; logo após, escolhe entrar num grupo (com código) ou criar o seu. Evita gargalo de depender de um convite para começar
- **Onboarding skippable:** 6 passos contextuais pós-cadastro, mas sempre puláveis e reabríveis depois. Não bloquear o usuário ansioso para começar
- **Saída voluntária do grupo permitida:** usuário não fica refém do grupo. Ao sair, pontos saem do ranking mas histórico de palpites permanece. Reentrada exige novo convite
- **Pergunta Plus sistematizada via API:** evita dor operacional de curadoria editorial por jogo
- **Lendas em ilustração estilizada via IA:** balanço entre identidade visual e risco jurídico
- **Idiomas PT/ES/EN como preferência por usuário:** internacionalização da experiência do jogador (mercados México e EUA), espelhando o modelo de fuso horário — preferência persistida, sem roteamento por URL. Admin e UGC não são traduzidos. Ver seção 17
- **Performance percebida como requisito, não polimento:** cada tela carrega seus dados em **um roundtrip ao banco** (RPC consolidada) e o shell do app nunca bloqueia atrás de queries. Padrão adotado após diagnóstico de trocas de aba de ~5-7s no PWA. Padrões obrigatórios: CONVENTIONS.md, seção 6

## 15. Notificações

### Porta de entrada

Sino no header de cada aba abre `/notificacoes` (tela única com histórico cronológico). Push notifications fora do app levam para a tela específica do evento (deep links).

### Deep links de push (MVP)

| Evento | Tela de destino |
|---|---|
| Palpite fechando em 1h | `/palpites/jogos/:id` |
| Drop diário disponível | `/album/drop-diario` |
| Fulano quer trocar com você | `/album/trocas/:id` |
| Cutucada recebida | `/palpites/jogos` |
| Convite recebido (sessão ativa) | Sheet de confirmação → `/grupo/liga` |

### Push notifications (Web Push / PWA)

Entrega via **Web Push API**, com o app instalado como PWA. Camada de *entrega* sobre a central de notificações (o sino deriva o feed ao vivo para o app aberto; o push avisa no device mesmo com o app fechado).

**Decisões:**

- **Default opt-out:** todas as categorias já vêm **ligadas** para o usuário novo (chave ausente em `notif_prefs` conta como ativa). O usuário desliga o que não quer em `/perfil/notificacoes`. A permissão do browser, porém, é sempre pedida por gesto explícito (um toggle "Receber notificações push" por dispositivo).
- **Eventos sistemáticos cobertos (1ª rodada):** palpite fechando em ~1h (não palpitou), resultado/acertou palpite, drop diário disponível, oferta de troca recebida, cutucada recebida. Cada um mapeia a uma categoria de `notif_prefs` (`lembrete_palpite`, `resultado_jogo`, `drop`, `troca`, `cutucada`).
- **Anti-spam (promessa):** no máximo **1 push por evento por usuário**, e cada fonte só olha eventos recentes (ex.: acerto nas últimas 3h, drop nas últimas 24h, cutucada nas últimas 6h) — ninguém recebe histórico antigo. Mecânica de dedupe e entrega: CONVENTIONS.md, seção 4.

**Restrição de plataforma (iOS):** Web Push no iOS/iPadOS exige **16.4+** e o app **adicionado à tela de início** (standalone) — não funciona em aba normal do Safari. A UI comunica isso quando o device não suporta. Android/Chrome/Edge/Firefox/desktop funcionam sem essa amarra.

> Infra de entrega (tabelas, RPC, edge function, service worker): CONVENTIONS.md, seção 4.

### Pontos a definir

- Agrupamento de múltiplos eventos num único push (digest) — hoje é 1 push por evento.
- Fallback via WhatsApp para usuários sem push habilitado.
- Eventos adicionais (mudança de ranking, marcos de streak) numa 2ª rodada.

## 16. Dados e sincronização (BallDontLie)

### Política de dados (regra do projeto)

**Sem mocks, sem dados estáticos.** Toda tela que exibe dados esportivos (seleções, estádios, jogos, placares, chaveamento) consome **dados reais da API BallDontLie FIFA World Cup**, nunca constantes hard-coded. Todo dado externo tem fonte real e rotina de atualização agendada, com cadência proporcional à volatilidade do dado.

### Frescor prometido ao usuário

- Placar, eventos e detalhes da partida: atualizados **a cada 1 minuto** durante os jogos.
- Classificação dos grupos: a cada 10 minutos durante a fase de grupos; diária fora dela.
- Seleções, estádios e elencos: semanais (mudam pouco).

O app nunca consulta a API esportiva direto do browser: lê de um cache local sempre atualizado. Arquitetura de cache, rotinas de sincronização e notas de API: CONVENTIONS.md, seção 3.

### Uso dos jogadores

O cache `jogadores` alimenta dois pontos do produto — a tela de elenco por seleção (`/inicio/copa/selecao/[id]`, acessível ao clicar numa seleção em "A Copa") e os pickers de torneio (artilheiro, bola de ouro, jovem revelação). A base é **exclusivamente os convocados para a Copa 2026**, que garante cobertura das 48 seleções e o vínculo jogador↔seleção. Jogadores históricos que não estão nesta Copa não são armazenados — não há uso para eles no produto.

## 17. Internacionalização (idiomas)

O produto suporta **três idiomas** na experiência do jogador/palpitador: **Português** (base), **Espanhol** e **Inglês**. Motivação: base de usuários no México e nos EUA, além do Brasil.

### Modelo

- **Preferência por usuário:** o idioma é uma preferência persistida, espelhando o padrão do fuso horário. Detectado no 1º acesso (idioma do navegador) e ajustável em Configurações. Sem prefixo de idioma na URL. Fallback sempre para Português.
- Datas, horas e tempo relativo respeitam o idioma escolhido.

### Escopo

- **Traduzido:** toda a experiência do jogador (navegação, início, A Copa, calendário, palpites, torneio, álbum, grupo, perfil, streak, regras, notificações).
- **Não traduzido:** área administrativa (ferramenta interna, permanece em PT) e conteúdo gerado por usuários — UGC (apelidos, nomes de grupos, nomes de jogadores/cidades vindos da API).
- **Fora do escopo atual:** roteamento por URL (`/es`, `/en`), idiomas RTL e formatação de números por locale (passo futuro).

> Implementação (catálogos, resolução no servidor, conteúdo curado do banco): CONVENTIONS.md, seção 5.
