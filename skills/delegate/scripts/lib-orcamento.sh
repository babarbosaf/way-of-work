#!/usr/bin/env bash
# Saldo de balde de cota, contado no nosso próprio log de auditoria.
#
# Nenhum dos CLIs entrega saldo real sem terminal interativo, então consultar o
# provider não é opção que exista. Contar chamada é proxy grosseiro, e um scan
# pequeno conta igual a uma implementação grande: aceito de propósito, porque o
# gate não existe pra espelhar a cota do provider, existe pra girar a fila antes
# do dano.
#
# Duas situações valem como balde LIVRE, e a escolha é deliberada: log ilegível e
# balde sem régua medida. Gate cego não pode bloquear trabalho, então nos dois
# casos a fila volta a descer por falha, que é exatamente o que ela fazia antes.

orcamento_configurar() { # policy log
    ORCAMENTO_POLICY="$1"
    ORCAMENTO_LOG="$2"
    ORCAMENTO_WINDOW_MINS=$(jq -r '.budgets.window_mins // empty' "$ORCAMENTO_POLICY" 2>/dev/null)
    [[ "$ORCAMENTO_WINDOW_MINS" =~ ^[0-9]+$ ]]
}

orcamento_teto() { # pool → régua do balde, ou vazio quando não há régua medida
    jq -r --arg p "$1" '.budgets.pools[$p].max_calls // empty' "$ORCAMENTO_POLICY" 2>/dev/null
}

# Corte da janela no mesmo formato que o log grava. Comparar string ISO em UTC
# ordena igual a comparar instante, e assim nenhuma linha precisa ser convertida.
orcamento_corte() {
    local secs=$(( ORCAMENTO_WINDOW_MINS * 60 ))
    date -u -r $(( $(date +%s) - secs )) +%Y-%m-%dT%H:%M:%SZ 2>/dev/null \
        || date -u -d "@$(( $(date +%s) - secs ))" +%Y-%m-%dT%H:%M:%SZ
}

orcamento_gastas() { # pool → chamadas que chegaram a um worker na janela, ou vazio se o log não se lê
    [[ -f "$ORCAMENTO_LOG" ]] || { echo 0; return 0; }
    # `unavailable` é cascata esgotada: nenhum worker foi alcançado, então a
    # linha não representa consumo de cota nenhuma.
    jq -s --arg p "$1" --arg corte "$(orcamento_corte)" \
        '[.[] | select(.pool == $p and .status != "unavailable" and .ts >= $corte)] | length' \
        "$ORCAMENTO_LOG" 2>/dev/null
}

orcamento_restante() { # pool → imprime saldo ou "livre"; 0 = pode gastar, 1 = estourou
    local teto gastas
    teto=$(orcamento_teto "$1")
    [[ "$teto" =~ ^[0-9]+$ ]] || { echo livre; return 0; }
    gastas=$(orcamento_gastas "$1")
    [[ "$gastas" =~ ^[0-9]+$ ]] || { echo livre; return 0; }
    if (( gastas >= teto )); then echo 0; return 1; fi
    echo $(( teto - gastas ))
}
