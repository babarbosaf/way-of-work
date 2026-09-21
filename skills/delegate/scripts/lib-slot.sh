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

# Só aponta o diretório. Criar é de quem escreve, porque a camada de terminal
# pergunta o estado do gate e consulta não pode deixar diretório atrás de si.
slot_configurar() { # gate_dir
    SLOT_DIR="$1"
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
    # O resgate do órfão tira o arquivo do caminho com `mv`, não com `rm -f`: dois
    # despachos que vissem o mesmo órfão passariam os dois pelo teste acima, e com
    # `rm -f` o segundo apagaria o slot que o primeiro acabou de criar, deixando os
    # dois se julgando donos do balde. Só um `mv` acha a origem, então só um chega
    # à recriação, e o outro desiste sem tocar em nada.
    local resgate="$SLOT_DIR/resgate.$1.${BASHPID:-$$}"
    mv "$f" "$resgate" 2>/dev/null || return 1
    rm -f "$resgate"
    ( set -o noclobber; printf '%s\n' "$conteudo" > "$f" ) 2>/dev/null
}

# Quem varre slots pergunta aqui, e não sai lendo o formato do arquivo por conta:
# o `--gc` e a camada de terminal precisam da mesma resposta.
# Aqui a pergunta é outra: não "o slot pode ser tomado", mas "tem alguém
# trabalhando". As duas divergem num caso real, e a diferença é mentira na tela:
# o prazo começa na tomada do slot e o prazo do worker começa depois do preparo
# da chamada, então worker vivo passa do prazo do slot e desaparecia da
# listagem. Quem decide tomar continua usando `slot_orfao`, porque lá segurar
# balde de worker travado é o dano.
slot_em_curso() { # lista os baldes com dono vivo, um por linha: balde id
    local f pool pid id
    for f in "$SLOT_DIR"/slot.*; do
        [[ -f "$f" ]] || continue
        # Uma abertura só: o arquivo é reescrito por outro processo, e dois seds
        # podiam validar o dono de uma versão e imprimir o id de outra.
        IFS=$'\t' read -r pool pid id < <(
            awk -F= '$1=="balde"{b=$2} $1=="pid"{p=$2} $1=="id"{i=$2} END{printf "%s\t%s\t%s\n", b, p, i}' "$f" 2>/dev/null)
        [[ "$pid" =~ ^[0-9]+$ ]] || continue
        kill -0 "$pid" 2>/dev/null || continue
        printf '%s %s\n' "$pool" "$id"
    done
}

slot_soltar() { # pool → solta o slot só quando o dono dele é este processo
    local f="$(slot_arquivo "$1")"
    [[ -f "$f" ]] || return 0
    [[ "$(sed -n 's/^pid=//p' "$f" 2>/dev/null)" == "${BASHPID:-$$}" ]] && rm -f "$f"
    return 0
}
