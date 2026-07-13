# Fluxo CI / preview / deploy

```
1. Branch curto (feature/<slug>)
2. Commits atômicos (~100 linhas, máx 300)
3. Push → GitHub Actions roda testes + lint (free)
4. PR aberto → preview deploy automático:
   - Backend Python: Render preview environment
   - Frontend (futuro Next.js): Vercel preview deploy
5. Self-review (checklist acima)
6. Merge em main → deploy automático pra prod
   - Render: redeploy automático em push pra main
   - Vercel: idem
7. Logs/observabilidade nos dashboards (Render + Vercel grátis)
```

**Setup mínimo por projeto novo:**
- `.github/workflows/ci.yml` — roda testes + lint em PR
- Render service apontando pro repo (auto-deploy em push pra main)
- Secrets em Render dashboard (não em `.env` versionado)
- `.gitignore` cobrindo `.env`, credentials, `__pycache__`, `node_modules`

**Vercel só quando frontend Next.js entrar.** Não configurar antes.
**Cloudflare Workers só se aparecer caso de edge/cron leve não-Python.** Provavelmente não.
