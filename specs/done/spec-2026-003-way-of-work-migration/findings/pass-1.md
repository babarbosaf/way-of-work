# Findings — pass 1 (Adversarial Evaluator, spec)

Reviewer: codex (cascata `--model auto`). Verდict: `critical_aberto` → resolvido in-place (patch sem round 2, decisão típica; usuário revisa).

## CRITICAL

**C1 — História sensível acoplada ao mesmo `.git` que ganha origin público.**
D-07 (branch fresca) reduz risco no publish mas não elimina: o mesmo `.git` mantém refs privadas e passa a apontar pra remote público. Qualquer `git push --all`, push de tag, branch errada ou refspec default alterado re-vaza história com dado de negócio. Débito irreversível.
→ **Fix:** publicar de **checkout limpo em scratch** (`git init` em tmp só com o tree sanitizado; commit único; push). `~/.claude` nunca ganha origin público derivado da história rica. Revisto: D-07, S1, S6.

## IMPORTANT

**I1 — `model-policy.local.json` merge assumido, não entregue.**
`delegate.sh:32` carrega só `model-policy.json`; não há loader de `.local`. D-03 prometia comportamento sem entregável, e não cobria "arquivo ausente" em clone limpo.
→ **Fix:** slice nova S2a implementa merge (jq deep-merge local sobre base, tolera ausência) + teste. D-03 atualizado.

**I2 — History gate prova 1 token.**
S5 usava `git log -p -S'exitlag'` — cobre um token, uma branch. AC fala "árvore NEM história" com todos os tokens.
→ **Fix:** S5 roda o pattern completo (`exitlag|comercial-estrela|holding-imob|personal-os|/Users/beneditobarbosa`) em `--all` no repo publicado.

**I3 — "Hooks resolvem em clone limpo" não provado por `bash -n`.**
`bash -n` = só sintaxe shell; não cobre hooks Python, execução real via `$HOME`, shebang/perms.
→ **Fix:** AC rebaixado ao provável (scripts parseiam + paths via `$HOME`, sem path absoluto); S5 adiciona `python3 -m py_compile` nos hooks Python. Promessa de execução observável removida.

## SUGGESTIONS

- **S1 — self-contained/submodule é how-to, não validado e2e.** → §1 marca "opção documentada, não validada nesta spec".
- **S2 — definir "dado pessoal" e "placeholder genérico".** → §2 ganha bloco Definições.
- **S3 — S6 fixa ref exata de publish, sem push implícito de tags/refs.** → absorvido pelo fix C1 (scratch = repo novo, só `main`, sem tags).

## Descoberta colateral do verify_cmd (inventário F1 subcontado)

O `verify_cmd` rodado pelo reviewer achou ~10 arquivos, não os 4 da prosa. Novos: `docs/adversarial-evaluator.md:50`, `docs/runbooks/multi-model-dispatch.md:20-21`, `hooks/templates/README.md:8,17`, `skills/spec-and-plan/SKILL.md:25`, `references/triage.md:37`, e `tests/delegate.test.sh` (wired a exitlag + literal `sk-test-123`). → S3 passa a tratar "o que o grep retorna" como fonte, não a hand-list; `sk-test-123` → token claramente fake.
