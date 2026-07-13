# Caixa de ferramentas — instrumentação e técnicas

**Debugger > logging** (preferência): debugger interativo (pdb, debugpy, Chrome devtools) revela estado completo sem poluir código. Use logging só quando: bug em prod sem debugger possível, sistema async com timing crítico, ou repro só dispara em ambiente real.

**Convenção de logs temporários:** sempre prefixo único `[DEBUG-<hash4>]` (ex: `[DEBUG-a4f2]`). Razão: cleanup garantido por `grep -r "\[DEBUG-" .` ao fechar. Sem prefixo, log temporário vira permanente por esquecimento.

**Bisect:** `git bisect start && git bisect bad HEAD && git bisect good <commit-ok>`. Se o loop do passo 0 é script: `git bisect run ./repro.sh` automatiza a busca.

**Differential loop:** `git worktree add ../sandbox-old <commit-ok>` → roda input idêntico nas duas árvores → diff o output. Especialmente útil em regressão silenciosa (output muda mas não quebra).

**Bug flaky:** loop pra subir taxa de repro:
```bash
for i in {1..100}; do ./loop.sh && echo "PASS" || echo "FAIL"; done | grep -c FAIL
```
Se <50% repro, fixar seed/timing antes de debugar.

**Perf bug:** medir baseline ANTES de mexer (timing, mem, cpu). Sem baseline, "ficou mais rápido" é placebo. Use `time`, `hyperfine`, profiler do runtime.

## Boas práticas de teste

- **Arrange-Act-Assert**: estruture todo teste assim
- **Teste estado, não interações**: assert no resultado, não em chamadas de método
- **DAMP > DRY** em testes: cada teste legível sozinho
- **Real > fake > stub > mock**: prefira implementações reais
- **Uma asserção por conceito**: foco estreito
- **Mocke só boundaries externas**: HTTP, APIs de terceiros — nunca lógica interna

### Pirâmide sugerida

```
       [E2E — 5%]
     manual ou staging

   [Integration — 15%]
   com mocks de HTTP externo

  [Unit — 80%]
  funções puras em isolamento
```

## Princípio fundador — "Automate or escalate"

**Validação manual do usuário é último recurso, não etapa padrão.** Toda vez que você terminar um build e for tentado a escrever "agora o usuário testa em DM/UI", pare e pergunte:

1. **Posso chamar a função pura?** Handler isolado com mocks prod-like → unit/contract test.
2. **Posso simular a borda externa?** Invocar a borda com payload válido (POST no endpoint, assinatura de webhook simulada, fila local) → integration test.
3. **Posso bater no prod e ler o que voltou?** Smoke automatizado: chama endpoint público, lê logs estruturados via API, valida payload → post-deploy smoke.
4. **Só sobra resposta humana?** (julgamento estético, "isso entrega valor?", verificação visual subjetiva) → aí sim, smoke manual.

Razões pra forçar automação:
- Manual não escala: N comandos × M cenários = N×M toques humanos por release. Insustentável.
- Manual atrasa: ciclo BUILD → "espera o usuário testar" → SHIP introduz horas de latência sem necessidade.
- Manual é amnésico: se o bug volta em 3 meses, ninguém lembra de re-rodar aquele caso. Teste automatizado é memória permanente.
- Manual confunde validação técnica com validação de valor. Técnico (canal limpo, contrato OK) tem que ser 100% automatizado; valor (resolve o problema?) pode ser humano.

**Anti-padrão a derrubar:** "smoke test pós-deploy: rodar manualmente cada handler". Reescreva como: "script de smoke que invoca cada handler com input sintético + assert no output e nos logs estruturados".

**Quando a borda externa é genuinamente difícil de simular** (assinatura de webhook, OAuth callback, webhook de terceiro com IP whitelist), invista no harness uma vez e reuse — não defere infinitamente pra "testa na mão".
