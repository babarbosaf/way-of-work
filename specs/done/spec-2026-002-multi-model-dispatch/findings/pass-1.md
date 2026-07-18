# Pass 1 — Adversarial Evaluator (2026-07-05)

Reviewer: claude-adversarial (fallback — codex quebrado, gemini CLI morto pro free tier)

## Critical

1. **Confinamento de escrita da worktree afirmado, não mecanizado.** Worker roda com auto-aprovação; worktree é só um diretório — path absoluto/`cd` escreve fora (inclusive em `~/.claude/scripts`, executado toda sessão). Viola AC-02. Correção: nomear mecanismo real (sandbox nativo do CLI: `codex --sandbox workspace-write`, `agy --sandbox`) e/ou declarar risco residual de escrita (hoje a tabela só admite leitura além da worktree).

## Important

1. Exit code 4 do delegate sem tradução no peer-review — tabela de mapeamento explícita necessária (peer-review externaliza só 0/2).
2. ACs sem fonte de verificação: "não perde nenhuma instrução" (T9) e "nada sensível rastreado" (T1) — definir procedimento (diff de contexto carregado; checklist × `git ls-files`).
3. Fallback hardcoded codex→agy = segunda fonte de hierarquia em modo degradado — exigir fallback ruidoso (stderr + log JSONL + inbox).

## Suggestions

1. `gate/model-rankings/` é gitignored — proposta aprovada some do histórico; copiar proposta aceita pra pasta versionada junto do commit da policy.
2. Task-types `boilerplate`/`implement` sem journey que os exercite — cobrir ou marcar reserva.
3. Critério de remoção do gemini legado vago — fixar "2 ciclos de refresh consecutivos".
