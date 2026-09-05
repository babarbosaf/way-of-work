# Fluxo CI / preview / deploy

## Dois modelos, e o custo escolhe

**Automático** é o default: o host observa o repo, push abre preview, merge publica.
Vale quando build é grátis ou barato.

**Manual** entra quando o host cobra por build ou por deploy. Aí o repo **não** é
ligado ao host: a validação inteira roda em `localhost`, e o ambiente público recebe
um deploy por leva, disparado à mão no fim. Ligar o repo nesse caso troca "um deploy
por leva" por "um deploy por push" sem ninguém decidir isso.

Qual dos dois vale é decisão de projeto, e mora no `CONVENTIONS.md` dele. Não se
descobre relendo ticket fechado.

## Modelo automático

```
1. Branch curto (feature/<slug>)
2. Commits atômicos (tamanho: ver o gate na SKILL.md)
3. Push → GitHub Actions roda testes + lint (free)
4. PR aberto → preview deploy automático:
   - Backend Python: Render preview environment
   - Frontend (futuro Next.js): Vercel preview deploy
   O link do preview é o artefato de review do PR de frontend, não um extra: é onde o
   desenho é visto com dado real antes do merge (ver o split frontend/backend na SKILL.md).
5. Self-review (checklist acima)
6. Merge em main → deploy automático pra prod
   - Render: redeploy automático em push pra main
   - Vercel: idem
7. Logs/observabilidade nos dashboards (Render + Vercel grátis)
```

**Setup mínimo por projeto novo:**
- `.github/workflows/ci.yml`: roda testes + lint em PR
- Render service apontando pro repo (auto-deploy em push pra main)
- Secrets em Render dashboard (não em `.env` versionado)
- `.gitignore` cobrindo `.env`, credentials, `__pycache__`, `node_modules`

**Vercel só quando frontend Next.js entrar.** Não configurar antes.
**Cloudflare Workers só se aparecer caso de edge/cron leve não-Python.** Provavelmente não.

## Modelo manual

Os passos 3, 4, 6 e 7 acima não existem. No lugar deles:

```
3. Push → nada acontece no host (repo não ligado)
4. Review sobre `localhost`, com dado real. É onde o desenho é visto antes do merge
6. Merge não publica
7. Deploy à mão, uma vez por leva, depois de validado
```

O que **não** muda: o gate de ship, os commits atômicos e o push como gate humano. O
que muda é que publicar deixa de ser efeito colateral do merge e volta a ser um ato.

**Setup mínimo:** confirmar que o host não tem o repo ligado (é o default de quem
publica por CLI, e não o de quem cria o site pelo dashboard), e escrever no
`CONVENTIONS.md` do projeto qual é o comando de publicar.
