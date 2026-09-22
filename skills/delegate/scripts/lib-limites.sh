#!/usr/bin/env bash
# Classificação e persistência única dos limites de worker.

limites_configurar() { # policy gate_dir
    LIMITES_POLICY="$1"
    LIMITES_GATE_DIR="$2"
    # A policy passada e nenhuma outra. Rede de segurança que lê arquivo
    # diferente faz teste com policy própria medir o número do repo sem avisar.
    # Três escalares do mesmo arquivo numa leitura: três forks de jq custavam
    # 12,9ms contra 3,9ms, medido, e isso é pago em todo despacho.
    IFS=$'\t' read -r RATE_LIMIT_MINS TIER_FALLBACK_MINS TRANSIENT_COOLDOWN_MINS SILENT_FAIL_MINS < <(
        jq -r '[.cooldowns.rate_limit_mins // "", .cooldowns.tier_fallback_mins // "", .cooldowns.transient_mins // "", .cooldowns.silent_fail_mins // ""] | @tsv' \
            "$LIMITES_POLICY" 2>/dev/null)
    [[ "$RATE_LIMIT_MINS" =~ ^[0-9]+$ && "$TIER_FALLBACK_MINS" =~ ^[0-9]+$ \
        && "$TRANSIENT_COOLDOWN_MINS" =~ ^[0-9]+$ && "$SILENT_FAIL_MINS" =~ ^[0-9]+$ ]]
}

cooldown_remaining() { # pool → 0 + segundos restantes se ativo; 1 se livre
    local f="$LIMITES_GATE_DIR/cooldown.$1" saved now expires rem
    [[ -f "$f" ]] || return 1
    saved=$(cat "$f" 2>/dev/null) || return 1
    now=$(date +%s)
    if [[ "$saved" == expiry:* ]]; then
        expires=${saved#expiry:}
    else
        # Arquivo legado guardava o instante de armação com o prazo longo.
        expires=$(( saved + TIER_FALLBACK_MINS * 60 ))
    fi
    [[ "$expires" =~ ^[0-9]+$ ]] || { rm -f "$f"; return 1; }
    rem=$(( expires - now ))
    if (( rem > 0 )); then echo "$rem"; return 0; fi
    rm -f "$f"; return 1
}

limites_armar_em() { # pool epoch
    printf 'expiry:%s\n' "$2" > "$LIMITES_GATE_DIR/cooldown.$1"
}

limites_armar_por_minutos() { # pool minutos
    limites_armar_em "$1" $(( $(date +%s) + $2 * 60 ))
}

arm_cooldown_longo() { limites_armar_por_minutos "$1" "$TIER_FALLBACK_MINS"; }

# Quem sabe a classe não precisa saber o prazo. É o que separa "calibrar a falha
# silenciosa" de "calibrar a cota de tier": antes as duas eram o mesmo número,
# então mexer numa movia a outra calada.
limites_armar_classe() { # pool classe
    case "$2" in
        rate_limit)  limites_armar_por_minutos "$1" "$RATE_LIMIT_MINS" ;;
        transiente)  limites_armar_por_minutos "$1" "$TRANSIENT_COOLDOWN_MINS" ;;
        silent_fail) limites_armar_por_minutos "$1" "$SILENT_FAIL_MINS" ;;
        *)           arm_cooldown_longo "$1" ;;
    esac
}
clear_cooldown() { rm -f "$LIMITES_GATE_DIR/cooldown.$1"; }

classificar_limite() { # arquivo de saída → rate_limit|tier_quota|transiente|silent_fail|desconhecido
    # Ordem: do castigo mais longo pro mais curto. Mensagem ambígua tem que cair
    # no prazo longo, porque errar pra curto faz a cascata voltar a bater numa
    # cota que já acabou, e é justamente a chamada perdida que o gate evita.
    # "timeout" NÃO entra como sinal de tropeço: a mensagem de cota esgotada do
    # plano traz a palavra, e o tropeço de verdade chega por rc=124 ou pelo
    # código HTTP. Ancorar em palavra solta ("reset") classificava output de
    # worker que só imprimia `git reset` como cota, e punia balde são por 60min.
    local out="$1"
    if grep -qiE '(quota[^.]{0,40}(exceeded|reached)|usage limit|limit reached|out of (credits|tokens)|insufficient_quota|resets? (at|on|in) )' "$out"; then
        echo tier_quota
    elif grep -qiE '(rate.?limit|too many requests|status.*429|RESOURCE_EXHAUSTED)' "$out"; then
        echo rate_limit
    elif grep -qiE '(does not exist or you do not have access|model .* not (found|supported)|status 404|502 bad gateway|503 service unavailable|504 gateway timeout|overloaded_error|temporarily unavailable)' "$out"; then
        echo transiente
    elif grep -qiE '(run ended with no output|no recorded error|no output (was )?(produced|generated)|i (was |am )?(unable|not able) to (process|complete|read)|context (length|window) exceeded|prompt is too long|input too large)' "$out"; then
        # Worker que desistiu e disse isso numa desculpa curta, com rc=0. É falha
        # do pool como as outras, e o prazo dela é o da policy — não mais o da cota
        # de tier, que era o que ela tomava emprestado.
        # Saída VAZIA não entra aqui de propósito: quem lê o vazio é o despachante,
        # que só o trata como falha silenciosa no rc=0. Classificar vazio aqui faria
        # todo rc≠0 mudo virar castigo de balde, e hoje ele desce a cascata limpo.
        echo silent_fail
    else echo desconhecido
    fi
}

limites_reset_epoch() { # arquivo → epoch do reset, se legível e futuro
    local reset epoch now
    reset=$(grep -ioE '[0-9]{4}-[0-9]{2}-[0-9]{2}[T ][0-9]{2}:[0-9]{2}(:[0-9]{2})?Z' "$1" | head -1)
    [[ -n "$reset" ]] || return 1
    if date -d "$reset" +%s >/dev/null 2>&1; then
        epoch=$(date -d "$reset" +%s)
    elif date -j -u -f '%Y-%m-%dT%H:%M:%SZ' "$reset" +%s >/dev/null 2>&1; then
        epoch=$(date -j -u -f '%Y-%m-%dT%H:%M:%SZ' "$reset" +%s)
    else
        return 1
    fi
    now=$(date +%s)
    [[ "$epoch" =~ ^[0-9]+$ ]] && (( epoch > now )) || return 1
    echo "$epoch"
}

armar_limite() { # pool arquivo [rc] → classe aplicada
    local classe reset
    if [[ "${3:-}" == 124 ]]; then classe=transiente
    else classe=$(classificar_limite "$2")
    fi
    if [[ "$classe" == tier_quota ]] && reset=$(limites_reset_epoch "$2"); then
        limites_armar_em "$1" "$reset"
    else
        limites_armar_classe "$1" "$classe"
    fi
    echo "$classe"
}
