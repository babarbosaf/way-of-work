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
