# CONVENTIONS: Bolão Copa do Mundo 2026

> Exemplo adaptado do blueprint de Iago de Macedo (github.com/iagodemacedo/project-blueprint).

A regra universal de construção: vale em qualquer tarefa, seja qual for a funcionalidade. O contrato de cada funcionalidade (tabela, RPC, cron, edge function) mora na seção dela no `PRD.md`. Padrão que mudar no código atualiza este doc no mesmo PR.

## 1. Stack

| Camada | Escolha |
|---|---|
| Front e renderização | Next.js 16 (App Router, React Server Components), instalável como PWA; UI em `DESIGN.md` |
| Backend e dados | Supabase (Postgres gerenciado, RLS, edge functions) |
| Deploy | Netlify Functions em São Paulo (`gru`), junto do Supabase (`sa-east-1`), cada roundtrip cross-region custa ~140ms |
| Dados esportivos | API BallDontLie FIFA World Cup (https://fifa.balldontlie.io), tier GOAT |

Segredos: a key da API é server-only (`BALLDONTLIE_API_KEY`); URL do projeto e anon key ficam no Supabase Vault, nenhum segredo é versionado.

## 2. Regras do projeto

- **Sem mocks, sem dados estáticos.** Toda tela que exibe dados esportivos consome dados reais da BallDontLie, nunca constantes hard-coded. Todo dado externo precisa de (1) fonte real e (2) rotina de atualização agendada com cadência proporcional à volatilidade do dado.
- **Regra de negócio não vai para o SQL.** A RPC só agrega leituras; o cálculo fica em JS, em helpers puros compartilhados entre telas, para que duas telas nunca mostrem números diferentes (ex.: a pontuação, PRD §3).
- **Dependência nova só quando o que já está na stack não cobre.** Pacote visual segue o `DESIGN.md` §10.
- **RPCs de leitura são `SECURITY INVOKER` e `stable`.** Respeitam RLS, mesma visibilidade das queries que substituem.
- **1 página = 1 roundtrip** (seção 3). Vale para toda tela nova ou alterada.

## 3. Performance (padrões obrigatórios)

A navegação lenta no PWA (~5s para trocar de aba + ~2s de conteúdo) vinha do acúmulo de **ondas seriais de queries** (waterfalls) por página, layout bloqueante e ausência de cache no cliente. Estas práticas valem para **toda tela nova ou alterada**.

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

## 4. Processo

- Migrations aplicadas via MCP devem ter o arquivo local nomeado com a **versão registrada no histórico remoto** (senão o workflow `supabase db push` quebra).
- Checklist para tela nova: (1) dados em 1 RPC ou, no máximo, 2 ondas justificadas por dependência real; (2) `loading.tsx`; (3) nada de `await` serial de queries independentes; (4) catálogos/estáticos via cache compartilhado.

## 5. Lint, CI e evals

| O quê | Quando | Corte |
|---|---|---|
| lint, typecheck e testes | todo PR, no CI | verde |
| `check-docs.py --estado --molde` e `check-writing.py` | PR que toca doc de raiz | limpo |
| `evals.yaml` | cada eval declara `paths:`, `cmd:` e `threshold:`; o CI roda só os tocados | o `threshold` do eval |

## 6. Índice de ADRs

Decisão técnica cara de reverter (schema, contrato público, plataforma) vira ADR em `docs/adrs/`. Nunca editar ADR aceito: criar um novo que o substitui.

| ADR | Decisão | Status |
|---|---|---|
|. | (nenhum ainda) |. |
