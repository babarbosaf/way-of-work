#!/usr/bin/env bash
# echo_preamble.sh — handshake de validação pra subagente Claude fresco que
# precisa operar a skill delegate sem tê-la herdado (Agent tool sem `fork`
# não herda skills da sessão — só CLAUDE.md + tools + MCP). Sem isso o
# subagente começa cego sobre task-types, exit codes, protocolo de
# integração. Padrão portado de jbaruch/sub-agent-delegation (registro Tessl).
#
# Uso:
#   echo_preamble.sh build <marker1> [marker2 ...]
#     → preâmbulo pra colar no início do prompt do subagente, pedindo eco de
#       cada marker antes de executar.
#   echo_preamble.sh check <response-file> <marker1> [marker2 ...]
#     → exit 0 se a resposta ecoou TODOS os markers; exit 1 e lista o que
#       faltou (reforçar prompt, nunca assumir que o subagente já sabia).
set -uo pipefail

die() { echo "echo_preamble: $*" >&2; exit 1; }

case "${1:-}" in
    build)
        shift
        [[ $# -ge 1 ]] || die "build precisa de ao menos 1 marker"
        echo "Antes de executar qualquer coisa, confirme nas primeiras linhas"
        echo "da sua resposta — uma linha por item, prefixada com 'ECO:' —"
        echo "que você entendeu os pontos abaixo. Não pule esse passo; a"
        echo "fonte é o que segue, não sua memória de treino."
        echo
        n=0
        for m in "$@"; do
            n=$((n+1))
            echo "$n. $m"
        done
        echo
        echo "Formato esperado: uma linha 'ECO: <resumo de 1 frase do item>'"
        echo "pra cada um dos $# pontos acima. Só depois disso, siga com a tarefa."
        ;;
    check)
        shift
        resp="${1:-}"; shift || true
        [[ -n "${resp:-}" && -f "$resp" ]] || die "check precisa de <response-file> existente"
        [[ $# -ge 1 ]] || die "check precisa de ao menos 1 marker"
        missing=0
        for m in "$@"; do
            grep -qiF "$m" "$resp" || { echo "faltando eco: $m" >&2; missing=$((missing+1)); }
        done
        if [[ $missing -gt 0 ]]; then
            echo "eco incompleto: $missing/$# marker(s) não confirmados — reforçar prompt, não assumir que o subagente sabe" >&2
            exit 1
        fi
        echo "eco completo: subagente confirmou todos os $# pontos" >&2
        ;;
    *) die "uso: echo_preamble.sh build <marker...> | check <response-file> <marker...>" ;;
esac
