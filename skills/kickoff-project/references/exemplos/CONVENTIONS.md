# CONVENTIONS: Bolão Copa do Mundo 2026

Como este produto se constrói. O comportamento prometido ao usuário vive no `PRD.md`; aqui vive o detalhamento técnico obrigatório. Padrão que mudar no código atualiza este doc no mesmo PR.

## 1. Stack

| Camada | Escolha |
|---|---|
| Front e renderização | Next.js (App Router, React Server Components), instalável como PWA |
| Backend e dados | Supabase (Postgres gerenciado, RLS, edge functions) |
| Deploy | Netlify Functions em São Paulo (`gru`), junto do Supabase (`sa-east-1`), cada roundtrip cross-region custa ~140ms |
| Dados esportivos | API BallDontLie FIFA World Cup (https://fifa.balldontlie.io), tier GOAT |

Segredos: a key da API é server-only (`BALLDONTLIE_API_KEY`); URL do projeto e anon key ficam no Supabase Vault, nenhum segredo é versionado.

## 2. Regras do projeto

- **Sem mocks, sem dados estáticos.** Toda tela que exibe dados esportivos consome dados reais da BallDontLie, nunca constantes hard-coded. Todo dado externo precisa de (1) fonte real e (2) rotina de atualização agendada com cadência proporcional à volatilidade do dado.
- **Regra de negócio não vai para o SQL.** A RPC só agrega leituras; cálculo (ex.: pontuação/ranking pela engine `lib/pontuacao`) permanece em JS, com helpers puros compartilhados entre telas (`agregarPontuacao`/`ordenarPosicoes`), assim home, liga e perfil exibem números idênticos por construção.
- **RPCs de leitura são `SECURITY INVOKER` e `stable`.** Respeitam RLS, mesma visibilidade das queries que substituem.
- **1 página = 1 roundtrip** (seção 6). Vale para toda tela nova ou alterada.

## 3. Dados e sincronização (BallDontLie)

### Arquitetura de cache

A BallDontLie não é consultada direto pelo browser. Um conjunto de edge functions (Supabase) sincroniza a API para tabelas locais (`selecoes`, `estadios`, `jogos`, `classificacao`, `jogadores`, `jogo_detalhes`), e o app lê só do Supabase.

A tabela `jogo_detalhes` guarda os dados ricos por jogo (tier GOAT) em **1 linha por jogo com uma coluna jsonb por seção** (eventos, lineups, team_stats, shots, momentum, best_players, avg_positions, team_form) + timestamp de sync por seção. Dados display-only, escritos por replace total a cada sync (resolve VAR/gol anulado sem reconciliação por id).

### Rotinas de sincronização (pg_cron)

O sync é dividido por cadência conforme a volatilidade de cada dado:

| Function | Conteúdo | Cadência | Cron |
|---|---|---|---|
| `sync-reference` | Seleções reais (`/teams`) + estádios (`/stadiums`) | Semanal | `0 6 * * 1` |
| `sync-players` | Elenco convocado 2026 e stats por seleção (`/rosters?seasons[]=2026`) → `jogadores` | Semanal | `30 6 * * 1` |
| `sync-matches` | Jogos: estrutura, datas, sede, preenchimento do mata-mata (`/matches`) | Diária | `0 5 * * *` |
| `sync-standings` | Classificação dos grupos (`/group_standings` → `classificacao`) | Diária + 10 min na Copa | `10 5 * * *` e `*/10 * * * *` |
| `sync-live` | Placares/status ao vivo + eventos da partida (`/matches?match_ids[]=` batched + `/match_events`) → `jogos` e `jogo_detalhes.eventos` | A cada 1 min | `* * * * *` |
| `sync-jogo-detalhes` | Lineups, team stats, shots, momentum, posições médias (janela ao vivo), best players (finalizados ≤48h) e team form (agendados ≤7d) → `jogo_detalhes` | A cada 1 min | `* * * * *` |

Os dois crons de 1 min têm **guard em SQL**: o `net.http_post` só dispara se existir jogo em alguma janela, então fora de dia de jogo não há invocação de edge function nem consumo da API. `sync-standings` tem dois jobs: um diário que roda sempre (captura sorteio/ajustes na pré-Copa) e um de 10 em 10 min que passa `{ onlyDuringCup: true }` e só atua dentro da janela da fase de grupos. Assim só consomem quota da API quando faz sentido (efeito adaptativo: tranquilo na pré-Copa, frequente nos dias de partida).

**Nota de API (jun/2026):** o endpoint singular `/matches/{id}` passou a retornar 404; todo fetch usa o filtro de lista `match_ids[]` (o param `match_id` simples é ignorado pela API). Os endpoints ricos (events, lineups, stats, shots, momentum, best players, avg positions, team form) exigem o **tier GOAT**.

Agendamento via `pg_cron` + `pg_net`. A função legada `sync-balldontlie` (sync completo num job só) permanece apenas como utilitário de backfill manual.

### Pontos a definir

- Hardening: exigir um shared-secret header nas edge functions de sync (hoje protegidas só pelo `verify_jwt` com anon key pública).

## 4. Notificações (infra de entrega)

Entrega via Web Push API com o app instalado como PWA. Camada de *entrega* sobre a central de notificações, os eventos, categorias e deep links são produto e vivem no PRD (seção 15).

**Arquitetura:**

- **Tabelas:** `push_subscriptions` (endpoint + chaves por device, RLS self) e `push_enviados` (dedupe `(user, chave)`, só service role).
- **RPC `get_pushes_pendentes()`** (SECURITY DEFINER, só `service_role`): varre as fontes sistemáticas e devolve o que falta enviar, já filtrado por `notif_prefs`, janela de recência e existência de assinatura.
- **Edge function `send-push`:** lê as pendências, faz fan-out para os devices do usuário via VAPID (`web-push`), grava em `push_enviados` e remove assinaturas mortas (404/410). Agendada por `pg_cron` a cada 2 min, com guard em SQL (só invoca se houver assinatura).
- **Service worker** (`src/sw.js`): handlers `push` (mostra a notificação) e `notificationclick` (foca/abre o app no deep link).
- **Client** (`src/lib/push/client.ts`): pede permissão, assina (`pushManager.subscribe` com `NEXT_PUBLIC_VAPID_PUBLIC_KEY`) e persiste via server action.

**Anti-spam:** dedupe por **chave estável** (`push-<tipo>:<id>`) na tabela `push_enviados`. 1 push por evento por usuário. Cada fonte tem **janela de recência** (ex.: acerto só nas últimas 3h, drop nas últimas 24h, cutucada nas últimas 6h), o que também evita disparar histórico no primeiro deploy. A `tag` da notificação reusa a chave: um re-disparo substitui em vez de empilhar.

## 5. Internacionalização (implementação)

Quais idiomas e o que é traduzido: PRD, seção 17. Implementação:

- **Resolução no servidor:** via cookie `NEXT_LOCALE` (SSR), com `profiles.locale` como fonte durável cross-device. Fallback sempre para Português.
- **UI estática:** strings em catálogos `messages/{pt,es,en}.json` (next-intl). Datas, horas e tempo relativo respeitam o locale.
- **Conteúdo curado do banco** (coleções, figurinhas, missões): colunas `*_i18n` (JSONB `{pt,es,en}`) com fallback PT; nomes de seleções resolvidos por `Intl.DisplayNames`. O admin gerencia as traduções via campos ES/EN no CRUD de conteúdo.

## 6. Performance (padrões obrigatórios)

Padrões adotados após diagnóstico de navegação lenta no PWA (~5s para trocar de aba + ~2s de conteúdo): a causa era acúmulo de **ondas seriais de queries** (waterfalls) por página, layout bloqueante e ausência de cache no cliente. Estas práticas valem para **toda tela nova ou alterada**.

### Regra de ouro: 1 página = 1 roundtrip

- Cada página server-rendered busca seus dados em **uma única chamada ao banco**, uma RPC consolidada (`get_home_resumo`, `get_liga_resumo`, `get_grupo_estatisticas`, `album_bootstrap`, `get_grupo_info`…) que devolve os dados crus em `jsonb`.
- Resolução de "grupo ativo" no banco via helper `get_grupo_ativo_id()`, nenhuma página gasta uma onda só para descobrir o grupo.

### Proibido serializar queries independentes

- `await` em sequência só quando uma query **depende do resultado** da anterior. Caso contrário, `Promise.all`, incluindo `getTranslations`/`getLocale`/timezone, que não dependem de dados.
- Dedupe por render com `React.cache` em funções chamadas por mais de um componente na mesma request (`getRequestUser`, `getGrupoAtivo`, `getUserTimezone`, RPCs de manutenção idempotentes).
- Dados públicos e estáveis (catálogo do álbum) usam cache cross-request (`unstable_cache`), nunca refazer queries de catálogo por usuário.

### Shell instantâneo (layout fora do caminho crítico)

- O layout `(app)` **não bloqueia** o primeiro paint: header, bottom nav e o `loading.tsx` da página aparecem imediatamente. Gates (banimento/convite/onboarding), nome do grupo e badges rodam em componentes async dentro de `<Suspense>` (os dados continuam protegidos por RLS; gates são UX).
- Toda página de aba tem `loading.tsx` com skeleton.
- Auth no render valida o JWT **localmente** (`getClaims`, chave assimétrica + JWKS). `auth.getUser()` (roundtrip de rede) só no proxy, que é quem refresca o token.

### Cliente e infraestrutura

- **Router cache:** `experimental.staleTimes.dynamic = 30`, voltar a uma aba visitada há <30s é instantâneo. Trade-off aceito: badges/contadores até 30s defasados.
- **Service worker** (`public/sw.js`): cache-first apenas para assets imutáveis (`/_next/static`, stickers, ícones, fontes, arte das figurinhas no Storage). **HTML, RSC, APIs e sessão nunca passam pelo cache.**
- O matcher do proxy exclui assets, `sw.js` e manifest, nada que não dependa de sessão paga o roundtrip de auth.

## 7. Processo

- Migrations aplicadas via MCP devem ter o arquivo local nomeado com a **versão registrada no histórico remoto** (senão o workflow `supabase db push` quebra).
- Checklist para tela nova: (1) dados em 1 RPC ou, no máximo, 2 ondas justificadas por dependência real; (2) `loading.tsx`; (3) nada de `await` serial de queries independentes; (4) catálogos/estáticos via cache compartilhado.

## 8. Índice de ADRs

Decisão técnica cara de reverter (schema, contrato público, plataforma) vira ADR em `docs/adrs/`. Nunca editar ADR aceito: criar um novo que o substitui.

| ADR | Decisão | Status |
|---|---|---|
|. | (nenhum ainda) |. |
