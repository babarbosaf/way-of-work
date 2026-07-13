---
name: refresh-model-rankings
description: >-
  Atualiza o ranking vivo de modelos do workflow multi-modelo: pesquisa
  avaliações externas de código, enumera backends realmente disponíveis nos
  CLIs locais e propõe (nunca aplica) um diff em
  ~/.claude/config/model-policy.json com justificativa e fontes. Invoque quando
  o usuário pedir para atualizar/revisar o ranking de modelos, quando um modelo
  novo for lançado, ou na rotina quinzenal agendada. Também cobre a APLICAÇÃO
  de uma proposta já aprovada pelo usuário.
---

# Refresh Model Rankings

> D-03/D-08 da SPEC-2026-002: benchmark barulhento nunca reescreve política.
> Este fluxo produz uma **proposta inerte**; só a aprovação expressa do
> Benedito muda a policy.

## Fase 1 — Coleta

1. **Estado local (fonte de verdade do acionável):**
   - `agy models` — lista viva de modelos do Antigravity (um "Sonnet 6"
     apareceria aqui).
   - `codex --version` + modelo em `~/.codex/config.toml`.
   - Policy atual: `~/.claude/config/model-policy.json` (fica fora de
     `skills/` de propósito — dado compartilhado entre esta skill e
     `delegate`, que só lê; não é recurso privado de nenhuma das duas).
   - Modelo ótimo que nenhum CLI local serve **não entra** na proposta.
   - **Consumo real por bolsão**: contagem do período em
     `~/.claude/gate/delegate.log` (`jq -rs '[.[] | .pool] | group_by(.) |
     map({pool: .[0], n: length})'`) + quota report do agy (comando de quota
     do CLI, ou pedir ao Benedito o print de "Models & Quota" se rodando
     headless). Bolsão sistematicamente perto da quota semanal →
     a proposta recomenda rebalancear cascatas.
2. **Avaliação externa (WebSearch, sempre com data da consulta):**
   - LMArena / WebDev Arena (coding), Aider polyglot leaderboard,
     SWE-bench (verified), e changelogs/release notes dos CLIs
     (codex, antigravity/agy, claude code).
   - Buscar também deprecações (ex.: gemini CLI free tier — remover o backend
     legado após 2 ciclos consecutivos confirmando a morte).

## Fase 2 — Proposta (nunca aplicar direto)

1. Escrever `~/.claude/gate/model-rankings/proposal-YYYY-MM-DD.md` com:
   - **Resumo em 5 linhas**: o que muda e por quê.
   - **Diff proposto** da policy (blocos antes/depois por task-type).
   - **Justificativa por mudança** com fonte (URL + data).
   - **Sem mudança também é resultado**: se os rankings não movem nada,
     registrar "sem mudanças propostas" — ciclo conta para deprecações.
2. Adicionar linha no `~/.claude/inbox.md` (criar se ausente):
   `- [ ] **[S]** Proposta de model-policy YYYY-MM-DD — revisar e aprovar/descartar — owner: Benedito → gate/model-rankings/proposal-YYYY-MM-DD.md`
3. **Não tocar** em `model-policy.json`.

## Fase 3 — Aplicação (só com aprovação expressa)

Quando o Benedito aprovar uma proposta:
1. Aplicar o diff em `~/.claude/config/model-policy.json`; validar `jq .`.
2. Copiar a proposta aprovada para `~/.claude/config/model-policy-history/`
   (o `gate/` é gitignored; a justificativa não pode sumir do histórico).
3. Rodar a suite: `bash ~/.claude/tests/delegate.test.sh` (verde obrigatório).
4. Commit único em `~/.claude`: policy + histórico, mensagem citando a proposta.
5. Marcar a linha do inbox como feita.
