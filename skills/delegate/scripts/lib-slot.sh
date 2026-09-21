#!/usr/bin/env bash
# Slot de balde: um worker por balde de cota, nunca dois.
#
# Por que existe: dois workers no mesmo balde disputam a mesma cota, e o saldo
# que um leu envelhece na mão do outro. Sem dono do slot, dois despachos
# disparados ao mesmo tempo tomariam o mesmo balde sem se ver.
#
# Mora no mesmo diretório em que o castigo já mora, um arquivo por balde, e não
# num processo novo pra manter vivo. Isso resolve de graça três coisas: tomar o
# slot é atômico, a camada de terminal tem de onde ler as tasks em curso, e slot
# de worker morto se libera pelo mesmo raciocínio de expiração do castigo.

slot_configurar() { # gate_dir
    SLOT_DIR="$1"
    mkdir -p "$SLOT_DIR"
}

slot_arquivo() { echo "$SLOT_DIR/slot.$1"; }

# Slot órfão: o processo dono morreu, ou o prazo declarado passou. Nos dois casos
# ninguém está trabalhando naquele balde, e segurar ele seria travar por medo.
slot_orfao() { # pool → 0 quando o slot pode ser tomado
    local f pid prazo
    f=$(slot_arquivo "$1")
    [[ -f "$f" ]] || return 0
    pid=$(sed -n 's/^pid=//p' "$f" 2>/dev/null)
    prazo=$(sed -n 's/^prazo=//p' "$f" 2>/dev/null)
    [[ "$prazo" =~ ^[0-9]+$ ]] && (( prazo < $(date +%s) )) && return 0
    [[ "$pid" =~ ^[0-9]+$ ]] || return 0
    kill -0 "$pid" 2>/dev/null && return 1
    return 0
}

# Criação com noclobber: o próprio open(O_EXCL) do shell decide quem ganhou, sem
# janela entre checar e escrever. Conferir antes e escrever depois é justamente o
# que deixaria dois despachos entrarem no mesmo balde.
# BASHPID expandido DIRETO, e nunca $$ nem $(funcao): dentro de subshell o $$ continua sendo o pid do shell que
# forkou, e o despacho assíncrono roda justamente num subshell cujo pai sai na
# hora. Gravar $$ ali fazia o slot nascer apontando pra um processo morto, e o
# despacho seguinte tomava o mesmo balde julgando o slot órfão. E ler isso por
# substituição de comando devolve o pid do subshell da própria substituição, que
# morre na hora, o que reproduz o mesmo bug por outro caminho. Os dois foram
# medidos.
slot_tomar() { # pool id prazo_segundos → 0 quando tomou
    local f="$(slot_arquivo "$1")" conteudo
    conteudo="pid=${BASHPID:-$$}"$'\n'"id=$2"$'\n'"prazo=$(( $(date +%s) + $3 ))"$'\n'"balde=$1"
    if ( set -o noclobber; printf '%s\n' "$conteudo" > "$f" ) 2>/dev/null; then
        return 0
    fi
    slot_orfao "$1" || return 1
    rm -f "$f"
    ( set -o noclobber; printf '%s\n' "$conteudo" > "$f" ) 2>/dev/null
}

slot_soltar() { # pool → solta o slot só quando o dono dele é este processo
    local f="$(slot_arquivo "$1")"
    [[ -f "$f" ]] || return 0
    [[ "$(sed -n 's/^pid=//p' "$f" 2>/dev/null)" == "${BASHPID:-$$}" ]] && rm -f "$f"
    return 0
}

slot_em_curso() { # lista os baldes ocupados agora, um por linha: balde id
    local f pool
    for f in "$SLOT_DIR"/slot.*; do
        [[ -f "$f" ]] || continue
        pool=$(sed -n 's/^balde=//p' "$f" 2>/dev/null)
        slot_orfao "$pool" && continue
        printf '%s %s\n' "$pool" "$(sed -n 's/^id=//p' "$f" 2>/dev/null)"
    done
}
