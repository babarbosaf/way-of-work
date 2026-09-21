#!/usr/bin/env bash
# Guarda do hook do RTK. Só existe por um motivo: o RTK é opcional, e sem o CLI
# no PATH o `rtk hook claude` do settings.json daria `command not found` e rc=127
# em todo Bash de quem clona este repo.
#
# O bypass de comando (cat/head/tail/git commit/gh pr create) NÃO mora mais aqui:
# é `[hooks] exclude_commands` no config.toml do próprio RTK, materializado por
# scripts/bootstrap-rtk.sh. O regex que vivia neste arquivo casava só no começo
# da linha e deixava passar `FOO=1 cat x`, `uv run pytest` e segmento de pipe; o
# RTK resolve os três desde a 0.47 (peeled command form). Ver docs/rtk.md.

set -u

if ! command -v rtk >/dev/null 2>&1; then
  # Drena o payload antes de sair: hook que fecha o stdin sem ler faz o harness
  # tomar EPIPE no meio da escrita (rc=141 no lado de quem escreve).
  cat >/dev/null 2>&1 || true
  exit 0
fi

exec rtk hook claude
