# Chutaí

> Exemplo adaptado do blueprint de Iago de Macedo (github.com/iagodemacedo/project-blueprint).

Bolão social da Copa do Mundo 2026: palpites, liga entre amigos e álbum de figurinhas.

## Como funciona

```
cadastro ──► grupo (cria ou entra por código) ──► palpites          no ar
                                                     │
BallDontLie ──► sync (pg_cron) ──► jogos ao vivo ────┤               no ar
                                                     ▼
                              pontuação ──► liga do grupo            no ar
                                                     │
                     drop diário ──► álbum ──► trocas entre amigos   previsto
```

- Palpites, pontuação e liga `no ar`: V/E/D, placar exato e Pergunta Plus, com multiplicador por fase.
- Dados reais `no ar`: nenhuma tela lê constante; tudo vem da BallDontLie via cache no Supabase.
- Álbum de figurinhas `previsto`: 154 figurinhas em 4 coleções, drop diário e troca.

## Estrutura

| Pasta | O que tem | Estado |
|---|---|---|
| `src/app/` | as telas, uma pasta por rota do `ROUTES.md` | `no ar` |
| `src/lib/` | regra de negócio em JS: `pontuacao/`, `push/` | `no ar` |
| `supabase/migrations/` | schema, RPCs e RLS; o contrato grande do PRD mora aqui | `no ar` |
| `supabase/functions/` | as edge functions de sync e de push | `no ar` |
| `messages/` | catálogos de UI em pt, es e en | `no ar` |
| `docs/adrs/` | decisão técnica cara de reverter | `no ar` |

## Começar

```bash
pnpm install
pnpm dev          # localhost:3000
pnpm lint && pnpm build
```

## Documentos

| Doc | Para quem | O que responde |
|---|---|---|
| README.md | quem chega | o que é, como funciona, onde está cada coisa |
| [PRD.md](PRD.md) | quem decide o produto | cada funcionalidade: comportamento, contrato, edge cases |
| [ROUTES.md](ROUTES.md) | quem cria tela | as rotas e a navegação |
| [DESIGN.md](DESIGN.md) | quem desenha UI | tokens, patterns, anti-slop |
| [CONVENTIONS.md](CONVENTIONS.md) | quem constrói | stack, regras universais, processo, CI |
