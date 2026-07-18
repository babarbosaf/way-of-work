#!/usr/bin/env bash
# Instala a skill/plugin de design recomendada (impeccable) quando o projeto
# mantém DESIGN.md. Rodar 1x depois de clonar/scaffoldar o projeto.
# Apagou DESIGN.md porque não tem front-end? Apague este script também.
set -euo pipefail

if [ ! -f "DESIGN.md" ]; then
  echo "DESIGN.md não existe neste projeto — nada a instalar. Apague este script." >&2
  exit 0
fi

if ! command -v claude >/dev/null 2>&1; then
  echo "Claude Code CLI não encontrado no PATH. Instale antes de rodar este script." >&2
  exit 1
fi

claude plugin marketplace add pbakaus/impeccable
claude plugin install impeccable@impeccable --scope project

echo "impeccable instalado (scope: project). Rode /impeccable init na próxima sessão."
