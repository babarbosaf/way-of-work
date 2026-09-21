#!/usr/bin/env bash
# Convenção compartilhada dos bootstrap-*.sh: flags, pré-requisito e banner de
# dry-run. É sourced, nunca executado direto.
#
# O caller declara antes de sourcear:
#   PROG       nome que abre as mensagens de erro
#   MANIFEST   caminho default do manifesto (--manifest= sobrescreve)
#   HELP_ATE   última linha do cabeçalho que o -h imprime
#
# e depois chama `bootstrap_args "$@"` e `bootstrap_prereq`, que devolvem APPLY e
# UPDATE em 0/1 e o MANIFEST resolvido.
#
# Existe porque o terceiro bootstrap iria copiar a mesma dúzia de linhas de novo,
# e o modo de falhar é uma flag nova entrar num e não no outro.

# ${BASH_SOURCE} é uma pilha, e o último elemento é o script que o usuário rodou,
# não este arquivo. Índice calculado em vez de [-1], que é bash 4.3+.
_bootstrap_caller() { echo "${BASH_SOURCE[${#BASH_SOURCE[@]} - 1]}"; }

bootstrap_args() {
  APPLY=0
  UPDATE=0
  local arg caller
  caller=$(_bootstrap_caller)
  for arg in "$@"; do
    case "$arg" in
      --apply) APPLY=1 ;;
      --update) UPDATE=1 ;;
      --manifest=*) MANIFEST="${arg#--manifest=}" ;;
      -h|--help) sed -n "2,${HELP_ATE}p" "$caller"; exit 0 ;;
      *) echo "uso: $(basename "$caller") [--apply] [--update] [--manifest=PATH]" >&2; exit 1 ;;
    esac
  done
}

bootstrap_prereq() {
  command -v jq >/dev/null || { echo "$PROG: jq é pré-requisito" >&2; exit 1; }
  [[ -f "$MANIFEST" ]] || { echo "$PROG: manifesto não encontrado: $MANIFEST" >&2; exit 1; }
  jq -e . "$MANIFEST" >/dev/null 2>&1 || { echo "$PROG: JSON inválido: $MANIFEST" >&2; exit 1; }
}

# Uma frase só: o banner aparece em cada ramo de cada bootstrap, e divergir entre
# ramos é o jeito de o usuário achar que um deles executou.
dry_run_banner() { echo "# dry-run: nada foi executado. Rode com --apply pra valer."; }
