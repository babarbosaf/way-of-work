#!/usr/bin/env bash
# run-all.sh: a suíte inteira num comando só, que é o que o `verify_cmd` do
# `.claude/project.yaml` aponta. Antes disto cada sessão repetia o loop à mão, e
# loop à mão esquece o `|| exit 1`: a suíte saía verde com arquivo vermelho dentro.
#
# Escopo: todo `tests/*.test.sh` mais o checador de link. Os lints de doc de raiz
# (`check-docs.py --estagio --decay`) ficam fora de propósito, porque eles cobram
# `TODOS.md` e `INBOX.md`, que são gitignored e locais: backlog sujo não é código
# vermelho, e travar o gate nele impediria fechar ticket.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 2

falhou=()
for t in tests/*.test.sh; do
  [[ "$(basename "$t")" == "run-all.sh" ]] && continue
  echo "== $t"
  bash "$t" || falhou+=("$t")
done

echo "== tests/check-links.py"
python3 tests/check-links.py || falhou+=("tests/check-links.py")

if (( ${#falhou[@]} )); then
  printf '\nVERMELHO em %d arquivo(s):\n' "${#falhou[@]}"
  printf '  %s\n' "${falhou[@]}"
  exit 1
fi
echo
echo "suite verde"
