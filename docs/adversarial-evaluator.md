# Adversarial Evaluator

Reviewer LLM independente revisa specs e diffs do Claude (segunda opinião
adversarial). **Ferramenta opcional, não gate:** não existe Status Block
obrigatório, teto de rounds nem estado que bloqueia ship. Usar quando o dono
pedir, ou oferecer quando o diff/spec **toca prod ou é caro de reverter**
(schema, migração de dados, contrato público, auth). O dono decide.

## Invocação

```bash
~/.claude/scripts/peer-review.sh spec <path-to-spec.md> [--findings <prev.md>] [--model auto|codex|gemini]
~/.claude/scripts/peer-review.sh diff [git-ref] [--findings <prev.md>] [--spec <spec.md>] [--model ...]
```

- `--model auto` (default) = cascata `codex → gemini → exit 2`
- `--model codex` ou `--model gemini` = força um reviewer específico, sem fallback
- Bypass do classifier interno: `echo "$PROMPT" | codex exec -` ou `gemini -p "$PROMPT"`

**Tamanho não captura risco.** Mudança de schema, migração de dados ou rename
consumido downstream é alto-risco mesmo pequena (perda de dado silenciosa,
quebra de consumidor que unit/CI leve não pegam). Bons candidatos a review.

**Contexto injetado automaticamente:** primeiras 40 linhas do CLAUDE.md do
projeto; em spec mode, o PRD do sistema (ou `idea_ref:` do frontmatter); em
diff mode, os ACs da spec se `--spec` for passado; findings do round anterior
se `--findings` for passado.

## Cascata de reviewers

1. **codex.** Primário. Requer `codex` CLI no PATH.
2. **gemini.** Segundo. Requer `gemini` CLI (`npm i -g @google/gemini-cli`).
3. **subagente Claude adversarial de contexto fresco.** Quando 1 e 2
   indisponíveis (`exit 2`). Prompt red-team explícito: "Você é um revisor
   cético. Tente REFUTAR esta spec/diff. Liste apenas problemas reais
   classificados em Critical/Important/Suggestion; default a Critical quando em
   dúvida sobre segurança ou perda de dado."
4. **inline Claude.** Piso do piso (ex. session limit). Mesmo viés do agente
   principal; cada finding cita `file:line` real, não inferência.

Reportar sempre **quem realmente produziu o output**, nunca apresentar
findings como se um reviewer indisponível tivesse rodado. `rc≠0` com output
truncado = "não rodou", nunca "ok".

### Cooldown e probe

Cooldown por reviewer em `~/.claude/gate/cooldown.<model>` (override
`PEER_COOLDOWN_MINS`, default 60; limpo no primeiro sucesso). O script checa
`command -v` antes de invocar. Reviewer ausente desce a cascata sem latência.
Workspace não-git é normal pra review de spec (codex roda com
`--skip-git-repo-check`); diff mode precisa de git no cwd.

## Resultado

Findings saem no **stdout**, classificados em Critical/Important/Suggestion.
Destino do registro:

- **Diff com PR:** comentário na PR, co-localizado com o diff.
- **Spec:** resumo dos findings + o que mudou por causa deles, ao fim da
  própria `spec.md`.
- **Critical encontrado:** apresentar com a evidência crua e propor opções
  (corrigir e seguir, re-rodar review no patch, redesenhar). A decisão é do
  dono. O review não bloqueia nada sozinho.

Re-run incremental: `printf '%s' "$ROUND1_FINDINGS" | peer-review.sh spec <path> --findings -`
(o reviewer foca em verificar os fixes).

## Referências

- `~/.claude/scripts/peer-review.sh`: implementação
- `~/.claude/gate/usage.log`: JSONL de uso (metadados, sem conteúdo)
