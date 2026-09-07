02 [M]  Leitura de arquivo grande por Bash apanha igual à leitura por Read

O que construir: hook `bash_read_guard.py` no PreToolUse de Bash, antes do rtk na
cadeia, casando comando que despeja arquivo inteiro no contexto (`cat`, `head`
sem `-n` pequeno, `tail`, `less`, `more`, `bat`, `rtk read`). Leitura apontada
passa, que é a regra do `check-bash-read` do Portal: pipe que filtra (`| grep`,
`| rg`, `| jq`, `| wc`), `head -N` com N dentro do `grep_max`, redirect pra
arquivo (não entra no transcript). Soma linhas quando o comando lista vários
arquivos. Isento: binário, imagem, arquivo inexistente, `cat` sem argumento.

Motivo medido: hoje `Read` acima de 200 linhas é bloqueado e `cat` do mesmo
arquivo passa, reescrito pra `rtk read -l none`, que devolve os mesmos bytes. O
caminho honesto apanha e o silencioso passa, e modo auto do harness instrui ler
com `cat`/`head`/`sed -n`.

files:      hooks/bash_read_guard.py, settings.json
blocked_by: 01
delega:     não
verify:     bash tests/hooks.test.sh

Aceite:
- [x] `cat <arquivo acima do grep_max>` bloqueia
- [x] `cat <arquivo pequeno>` libera
- [x] `cat grande | grep x` libera (leitura apontada)
- [x] `head -50 grande` libera; `head -400 grande` bloqueia
- [x] `cat grande > /tmp/x` libera (não entra no transcript)
- [x] `rtk read grande` bloqueia (é o mesmo despejo com outro nome)
- [x] payload inválido, arquivo inexistente e imagem liberam
- [x] `BASH_READ_GUARD_DISABLED=1` libera
- [x] hook registrado no `settings.json` antes do `rtk-hook-wrapper.sh`
