#!/usr/bin/env bash
# Runner do /higiene-repo via launchd. Invoca claude headless varrendo todos os projetos ativos.
# Salva relatório em ~/.claude/relatorios/higiene/YYYY-MM-DD-resumo.md
# Salva log de execução em ~/.claude/relatorios/higiene/runner.log

set -euo pipefail

RELATORIOS_DIR="$HOME/.claude/relatorios/higiene"
LOG="$RELATORIOS_DIR/runner.log"
DATE_STAMP=$(date +%Y-%m-%d)

mkdir -p "$RELATORIOS_DIR"

{
  echo ""
  echo "===== $(date -Iseconds) — higiene-repo runner start ====="
} >> "$LOG"

# PATH explícito (launchd não herda PATH do shell)
export PATH="/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"

PROMPT="/higiene-repo varrer todos os projetos ativos em ~/.claude/projects/*. Modo conservador (nunca deletar sem aprovação humana — você está rodando sem usuário presente, então NUNCA delete; só liste). Gere relatório consolidado em ~/.claude/relatorios/higiene/${DATE_STAMP}-resumo.md com sumário por projeto + total de candidatos a delete + total de itens suspeitos. Não toque em projetos com mtime > 90 dias (escanteados). Salvaguardas duras conforme SKILL.md.

PASSO EXTRA — Memory GC: para cada ~/.claude/projects/*/memory/MEMORY.md, audite o inchaço do índice (ele carrega toda sessão). Reporte numa seção 'Memory GC' do relatório: (a) tamanho do MEMORY.md em linhas — sinalizar se > 40; (b) clusters de memórias órfãs do mesmo tema com >=3 itens → propor hub concept_* a criar (nomear o tema e listar as órfãs); (c) duplicatas suspeitas (mesmo arquivo linkado 2x, ou títulos quase idênticos); (d) links quebrados (aponta pra .md inexistente). NÃO edite memória — só liste as propostas de compactação pro humano aprovar depois."

# Roda claude headless. Output em arquivo separado pra debug.
OUTPUT_FILE="$RELATORIOS_DIR/${DATE_STAMP}-runner-output.txt"

if claude --print --permission-mode plan "$PROMPT" > "$OUTPUT_FILE" 2>&1; then
  echo "[$(date -Iseconds)] OK — relatório em $RELATORIOS_DIR/${DATE_STAMP}-resumo.md" >> "$LOG"
  # Notificação macOS
  osascript -e "display notification \"Relatório salvo em ~/.claude/relatorios/higiene/${DATE_STAMP}-resumo.md\" with title \"Higiene de Repos\" sound name \"Glass\"" 2>/dev/null || true
else
  EXIT=$?
  echo "[$(date -Iseconds)] FAIL exit=$EXIT — ver $OUTPUT_FILE" >> "$LOG"
  osascript -e "display notification \"Falha no runner — ver runner.log\" with title \"Higiene de Repos\" sound name \"Basso\"" 2>/dev/null || true
  exit $EXIT
fi
