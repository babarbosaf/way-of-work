#!/usr/bin/env bash
# Ponte para o resolvedor de política de modelo, que mora na skill dona dele.
#
# Aqui não pode ser symlink. No Windows o clone escreve o link como arquivo de
# texto com o caminho dentro, e o bash executa esse texto como comando. O shim
# resolve o caminho relativo a si mesmo e faz exec, então vale nos dois
# sistemas sem duplicar lógica.
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$DIR/../skills/delegate/scripts/model-policy-effective.sh" "$@"
