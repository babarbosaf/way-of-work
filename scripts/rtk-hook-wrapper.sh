#!/usr/bin/env bash
# Wrapper para rtk hook claude que bypassa rewrite em comandos
# que não se beneficiam de compressão (git commit, git push, gh pr create).
#
# O parser JSON do RTK falha com HEREDOC/newlines literais no campo command,
# causando erro na primeira tentativa de commit/PR.

set -u

payload=$(cat)

# Tenta extrair o comando via python3; se falhar, usa grep direto no payload
cmd=$(echo "$payload" | python3 -c "import sys,json; print(json.load(sys.stdin).get('tool_input',{}).get('command',''))" 2>/dev/null || echo "")

# Bypass para comandos que quebram com HEREDOC ou não geram output compressível
# Checa tanto o comando extraído quanto o payload bruto (para quando o JSON parse falha)
#
# Leitura de arquivo (cat/head/tail/less/more/bat) também é bypass, e por medida:
# `rtk read` no nível default devolve os mesmos bytes (AGENTS.md 5223 -> 5222; o
# delegate.sh 19432 CRESCE pra 19550 no --level aggressive, porque o filtro volta
# vazio e o rtk cai pro bruto mais uma linha de warning). O rewrite creditava
# 6914 chamadas a 25.3% no `rtk gain`, o pior percentual da tabela no maior
# volume, e criava a impressão de que o caminho estava coberto. Quem manda nesse
# caminho agora é hooks/bash_read_guard.py, que roteia pro worker. O rtk fica no
# que ele mede bem: saída de comando (test 85.8%, git diff 96.2%, lint 94.2%).
BYPASS='^[[:space:]]*(git[[:space:]]+commit|git[[:space:]]+push|gh[[:space:]]+pr[[:space:]]+create|cat|bat|less|more|head|tail)([[:space:]]|$)'
if [[ -n "$cmd" ]]; then
    if echo "$cmd" | grep -qE "$BYPASS"; then
        exit 0
    fi
else
    if echo "$payload" | grep -qE '"command"[[:space:]]*:[[:space:]]*"(git commit|git push|gh pr create|cat |bat |less |more |head |tail )'; then
        exit 0
    fi
fi

# RTK é opcional: sem o CLI instalado o hook sai limpo e o comando roda sem
# compressão. Sem esta guarda, todo Bash de quem clona o repo sem rtk toma
# `rtk: command not found` e rc=127.
command -v rtk >/dev/null 2>&1 || exit 0

# Para todos os outros comandos, delega ao RTK normalmente
echo "$payload" | rtk hook claude
