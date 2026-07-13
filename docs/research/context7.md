# context7 — doc de lib atualizada no contexto

**Fonte:** https://github.com/upstash/context7 · https://context7.com
**Capturado:** 2026-07-07 · **Status:** MCP instalado; gatilho amarrado em skills de código + hook PreToolUse (2026-07-08).

## O que é

MCP server (`https://mcp.context7.com/mcp`) que injeta doc atualizada e **version-specific** de libs no contexto — mata API alucinada e training data desatualizado. Gatilho no prompt: `use context7`, opcionalmente com lib id (`use library /supabase/supabase`).

## Instalação (rodar no terminal — não edito .claude.json)

API key grátis em context7.com/dashboard (rate limit maior).

Remoto (HTTP):
```
claude mcp add --scope user --header "CONTEXT7_API_KEY: SUA_KEY" --transport http context7 https://mcp.context7.com/mcp
```

Local (npx):
```
claude mcp add --scope user context7 -- npx -y @upstash/context7-mcp --api-key SUA_KEY
```

Alternativa all-in-one: `npx ctx7 setup` (OAuth + gera key + instala skill).

## Onde amarrado no fluxo

- **CLAUDE.md** (seção "Coding practices atualizadas"): consultar antes de escolher API/assinatura/versão de lib.
- **spec-and-plan / test-and-debug**: gatilho `use context7` no passo de escolha de lib/API.
- **Hook `~/.claude/hooks/context7_reminder.py`** (PreToolUse Edit|Write|MultiEdit): dispara em qualquer skill, não só spec-and-plan/test-and-debug. Avisa (stderr, não bloqueia) quando:
  - arquivo é manifesto de dependência (`package.json`, `requirements.txt`, `pyproject.toml`, `go.mod`, `Gemfile`, `composer.json`, `Cargo.toml`, `Pipfile`);
  - diff introduz linha de import/require nova que não existia no `old_string`/conteúdo anterior.
  Kill: `CONTEXT7_REMINDER_DISABLED=1`.

## Quando disparar

Escolher/atualizar lib, assinatura de API incerta, versão específica, framework que mudou desde o cutoff. Não pra lógica de negócio própria nem stdlib estável.
