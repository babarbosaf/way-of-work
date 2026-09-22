#!/usr/bin/env bash
# Elegibilidade do modo visível: quem sobrevive a rodar em modo interativo.
#
# O despachante chama worker em modo de lote, e nesse modo nenhum deles é
# detectável como sessão de terminal. Ver o worker exige o modo conversacional,
# que troca modelo, flags, autenticação e a forma como a resposta volta. Esta lib
# existe porque a spec recusa presumir que os três workers configurados
# sobrevivam a essa troca: cada um é MEDIDO, e o veredito mora na policy como
# dado, com data e motivo.
#
# Fronteira dura: nada aqui toca a cascata do modo padrão. Worker não elegível
# some do modo visível e continua atendendo despacho normal como sempre atendeu.

visivel_configurar() { # policy
    VISIVEL_POLICY="$1"
    [[ -f "$VISIVEL_POLICY" ]] && jq -e . "$VISIVEL_POLICY" >/dev/null 2>&1
}

visivel_campo() { # backend campo → valor, ou vazio
    jq -r --arg b "$1" --arg c "$2" \
        '.visivel.backends[$b][$c] // empty' "$VISIVEL_POLICY" 2>/dev/null
}

# Veredito ausente conta como NÃO elegível, e é a escolha conservadora de
# propósito: worker sem medição é worker sobre o qual não se sabe nada, e o
# default de quem não se sabe é ficar de fora, nunca entrar na base da dúvida.
visivel_elegivel() { # backend → rc 0 se elegível
    [[ "$(visivel_campo "$1" elegivel)" == "true" ]]
}

visivel_lista() { # → um elegível por linha
    jq -r '.visivel.backends // {} | to_entries[]
        | select(.value.elegivel == true) | .key' "$VISIVEL_POLICY" 2>/dev/null
}

visivel_invoke() { # backend → comando interativo medido, ou vazio
    visivel_campo "$1" invoke
}

# Telas que o worker mostra ANTES de aceitar prompt, uma por linha em JSON. Mora
# aqui pelo mesmo motivo que a lista de elegíveis: régua copiada diverge, e esta
# diz quais teclas saem, o que erra caro.
visivel_telas() { # backend → uma tela por linha, ou nada
    jq -c --arg b "$1" '.visivel.backends[$b].telas_de_abertura // [] | .[]' \
        "$VISIVEL_POLICY" 2>/dev/null
}

# Porta única do modo visível. Recusa nomeia o worker e carrega o motivo que a
# medição gravou: "não elegível" sozinho manda quem leu caçar o porquê num
# arquivo de config, e é assim que a régua vira folclore.
visivel_exigir() { # backend → rc 0, ou rc 1 com a causa no stderr
    local b="$1" porque
    if visivel_elegivel "$b"; then return 0; fi
    porque=$(visivel_campo "$b" porque)
    [[ -n "$porque" ]] || porque="não foi medido no modo interativo"
    printf 'modo visível: %s não é elegível (%s)\n' "$b" "$porque" >&2
    return 1
}

# --- estado da sessão dirigida ---------------------------------------------
#
# A linha de uma sessão vive enquanto a SESSÃO vive, nunca enquanto o
# despachante vive. A API de metadados da ferramenta expira por prazo, e prazo
# aqui é o mecanismo errado: despachante que morre com worker vivo apagaria a
# linha e esconderia exatamente a sessão que precisa de intervenção (D-09).
# Então o estado mora em duas coisas que não expiram: o rótulo da aba, que morre
# com a aba, e um registro em disco, que esta lib varre.

# Marcador da fatia 01: aba dirigida nasce prefixada, e a receita de sidebar
# apaga essas linhas pra sobrar em destaque a linha de quem dirige.
VISIVEL_MARCA_DIRIGIDA="» "
# Estado desconhecido, e não "morto": a sessão pode estar trabalhando muito bem,
# o que se perdeu foi quem sabia o que ela estava fazendo.
VISIVEL_MARCA_ORFA=" ?"

visivel_sessoes_dir() { # → onde moram os registros de sessão dirigida
    printf '%s\n' "${DELEGATE_GATE_DIR:-$HOME/.claude/gate}/sessoes"
}

visivel_adaptador() { # → o caminho do adaptador da ferramenta de terminal
    local aqui; aqui="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    printf '%s\n' "${DELEGATE_ADAPTADOR:-$aqui/../../../scripts/herdr-adapter.sh}"
}

visivel_registrar() { # pane tab nome dono
    local dir arq; dir=$(visivel_sessoes_dir); mkdir -p "$dir" || return 1
    # Nome do arquivo pela aba: o painel pode mudar de lugar dentro da aba, e a
    # aba é o que a lista mostra e o que se fecha.
    arq="$dir/${2//:/-}.json"
    jq -n --arg p "$1" --arg t "$2" --arg n "$3" --arg d "$4" \
        '{pane:$p, tab:$t, nome:$n, dono:($d|tonumber), aberto_em:(now|todate)}' \
        > "$arq"
}

# Varredura: alinha os registros com o que a ferramenta lista. Não fecha nada e
# não abre nada, porque fechar é decisão de outra fatia e abrir é do abridor.
visivel_sincronizar() { # → rc 0
    local dir adaptador lista arq tab dono rotulo
    dir=$(visivel_sessoes_dir)
    [[ -d "$dir" ]] || return 0
    adaptador=$(visivel_adaptador)
    [[ -x "$adaptador" ]] || return 1
    lista=$("$adaptador" listar) || return 1
    for arq in "$dir"/*.json; do
        [[ -f "$arq" ]] || continue
        tab=$(jq -r '.tab // empty' "$arq" 2>/dev/null)
        dono=$(jq -r '.dono // empty' "$arq" 2>/dev/null)
        # Sessão que não está mais na lista morreu, e o registro vai junto:
        # registro sobrevivente ressuscitaria a linha na próxima varredura.
        if [[ -z "$tab" ]] || ! awk -F'\t' -v t="$tab" '$1==t{f=1} END{exit !f}' <<<"$lista"; then
            rm -f "$arq"; continue
        fi
        [[ -n "$dono" ]] && kill -0 "$dono" 2>/dev/null && continue
        rotulo=$(awk -F'\t' -v t="$tab" '$1==t{print $2; exit}' <<<"$lista")
        # Remarcar o que já está marcado encheria a lista de "» x ? ? ?" e o log
        # de mudança que não mudou nada.
        [[ "$rotulo" == *"$VISIVEL_MARCA_ORFA" ]] && continue
        "$adaptador" rotular "$tab" "$rotulo$VISIVEL_MARCA_ORFA" || true
    done
    return 0
}

# Grupo do projeto: três projetos com trabalho aberto ao mesmo tempo produzem uma
# lista achatada onde nada diz de onde cada linha veio. O nível de agrupamento já
# existe na ferramenta, e o que faltava era alguém escolher por projeto.
# Devolve "id" quando o grupo já existia, e "id<TAB>pane<TAB>tab" quando teve que
# criar: a aba raiz que nasce com o grupo é pra ser reusada, não abandonada.
visivel_espaco() { # cwd → grupo do projeto, criando se ainda não houver
    local cwd="$1" nome adaptador
    nome=$(basename "$cwd")
    adaptador=$(visivel_adaptador)
    [[ -x "$adaptador" ]] || return 1
    # Reusar antes de criar: dois grupos com o mesmo nome espalhariam as abas do
    # mesmo projeto por dois lugares, que é o contrário do que a lista quer.
    local achado
    achado=$("$adaptador" espacos | awk -F'\t' -v n="$nome" '$2==n{print $1; exit}')
    [[ -n "$achado" ]] && { printf '%s\n' "$achado"; return 0; }
    "$adaptador" criar-espaco "$cwd" "$nome"
}

# Prazo de ociosidade, em minutos, e ele é dado da policy. Duração cravada em
# script é o que faz dois pontos de chamada divergirem sem ninguém ver, e aqui o
# erro é caro nos dois sentidos: curto demais mata trabalho em curso, longo
# demais devolve a lista entupida que a camada existe pra desentupir.
visivel_prazo_ocioso() { # → minutos, ou nada quando a policy não declara
    jq -r '.visivel.ciclo.prazo_ocioso_min // empty' "$VISIVEL_POLICY" 2>/dev/null
}
