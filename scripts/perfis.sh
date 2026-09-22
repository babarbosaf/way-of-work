#!/usr/bin/env bash
# Diagnostica, e opcionalmente conserta, a deriva entre os perfis de configuração
# da máquina e este repositório.
#
# Uso: perfis.sh              diagnostica e não escreve nada
#      perfis.sh --aplicar    cria os links que faltam e liga os hooks do baseline
#
# Por que existe: tudo que um perfil usa (skills, hooks, docs, config, scripts,
# AGENTS.md) é link pra este repositório, então `git pull` já atualiza todos de
# uma vez. O `settings.json` é a exceção, porque carrega preferência pessoal, e é
# ele que decide QUAIS hooks rodam. Hook novo que entra aqui não chega a perfil
# nenhum sozinho, e a diferença só aparece quando a trava falta na hora errada.
#
# O baseline é o `settings.json` deste repositório. Hook que o perfil liga a mais
# não é deriva: perfil pode querer mais trava, e acusar isso transformaria
# preferência em erro.
set -uo pipefail

RAIZ="${PERFIS_RAIZ:-$HOME}"
REPO="${PERFIS_REPO:-$HOME/.claude}"
BASE="$REPO/settings.json"
APLICAR=0

die() { printf '%s\n' "$*" >&2; exit 1; }

while (( $# )); do
    case "$1" in
        --aplicar) APLICAR=1; shift ;;
        -h|--help) sed -n '2,8p' "$0"; exit 0 ;;
        *) die "uso: $(basename "$0") [--aplicar]" ;;
    esac
done

command -v jq >/dev/null 2>&1 || die "perfis: preciso do jq"
[[ -f "$BASE" ]] || die "perfis: baseline não encontrado em $BASE"
jq -e . "$BASE" >/dev/null 2>&1 || die "perfis: baseline ilegível em $BASE"

# O que todo perfil espelha do repositório. A lista sai do que existe aqui, e não
# de uma constante: item novo no repositório entra sozinho, e item que saiu para
# de ser cobrado.
ESPELHADOS=()
for alvo in hooks skills docs config scripts AGENTS.md CLAUDE.md; do
    [[ -e "$REPO/$alvo" ]] && ESPELHADOS+=("$alvo")
done

# Trinca (evento, matcher, comando) que o baseline liga e o perfil não. Matcher
# ausente vira string vazia, senão a comparação casaria um hook de evento sem
# matcher com outro de matcher qualquer.
hooks_faltantes() {
    jq -r --slurpfile perfil "$1" '
        (.hooks // {}) | to_entries[] | .key as $ev | .value[] |
        (.matcher // "") as $m | (.hooks // [])[] | .command as $c |
        select(
            ( ($perfil[0].hooks[$ev] // [])
              | map(select((.matcher // "") == $m) | (.hooks // [])[].command)
              | index($c) ) == null
        ) | [$ev, $m, $c] | @tsv
    ' "$BASE" 2>/dev/null
}

liga_hook() { # settings evento matcher comando
    local arq="$1" tmp
    tmp="$(dirname "$arq")/.perfis.$$"
    jq --arg ev "$2" --arg m "$3" --arg c "$4" '
        .hooks //= {} | .hooks[$ev] //= [] |
        if (.hooks[$ev] | map(.matcher // "") | index($m)) != null then
            .hooks[$ev] |= map(
                if (.matcher // "") == $m
                then .hooks = ((.hooks // []) + [{type:"command", command:$c}])
                else . end)
        else
            .hooks[$ev] += [{matcher:$m, hooks:[{type:"command", command:$c}]}]
        end
    ' "$arq" > "$tmp" || { rm -f "$tmp"; return 1; }
    # Publica por rename: settings meio escrito é config quebrada de uma sessão
    # inteira, e o perfil é lido a cada start.
    mv "$tmp" "$arq"
}

achados=0
for perfil in "$RAIZ"/.claude*; do
    [[ -d "$perfil" ]] || continue
    [[ "$perfil" == "$REPO" ]] && continue

    pendencias=()
    for alvo in "${ESPELHADOS[@]}"; do
        [[ -e "$perfil/$alvo" ]] && continue
        pendencias+=("link ausente: $alvo")
        (( APLICAR )) && ln -s "$REPO/$alvo" "$perfil/$alvo"
    done

    cfg="$perfil/settings.json"
    if [[ ! -f "$cfg" ]]; then
        pendencias+=("sem settings.json, nenhum hook roda neste perfil")
    elif ! jq -e . "$cfg" >/dev/null 2>&1; then
        # Ilegível não é vazio: consertar por cima apagaria a preferência toda.
        pendencias+=("settings.json ilegível, nada foi tocado")
    else
        while IFS=$'\t' read -r ev m c; do
            [[ -n "$c" ]] || continue
            pendencias+=("hook do baseline não ligado: $(basename "$c")")
            (( APLICAR )) && { liga_hook "$cfg" "$ev" "$m" "$c" \
                || pendencias+=("não consegui ligar $(basename "$c")"); }
        done < <(hooks_faltantes "$cfg")
    fi

    if (( ${#pendencias[@]} )); then
        achados=$(( achados + ${#pendencias[@]} ))
        printf '%s\n' "$perfil"
        printf '  %s\n' "${pendencias[@]}"
    else
        printf '%s\n  alinhado com o repositório\n' "$perfil"
    fi
done

if (( achados == 0 )); then
    printf '\nnenhuma deriva.\n'
elif (( APLICAR )); then
    printf '\n%s pendência(s) tratada(s). Rode de novo pra conferir.\n' "$achados"
else
    printf '\n%s pendência(s). Nada foi escrito; use --aplicar.\n' "$achados"
fi
exit 0
