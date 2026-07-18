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
if [[ -n "$cmd" ]]; then
    if echo "$cmd" | grep -qE '^\s*(git\s+commit|git\s+push|gh\s+pr\s+create)'; then
        exit 0
    fi
else
    if echo "$payload" | grep -qE '"command"\s*:\s*"(git commit|git push|gh pr create)'; then
        exit 0
    fi
fi

# Para todos os outros comandos, delega ao RTK normalmente
echo "$payload" | rtk hook claude
