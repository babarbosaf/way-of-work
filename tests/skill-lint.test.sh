#!/usr/bin/env bash
# Suíte do check-skill.py. Prova que a régua de autoria pega o que promete.
# Uso: bash tests/skill-lint.test.sh
#
# Cada regra roda duas vezes: numa skill plantada com a violação, onde precisa
# acusar, e nas skills versionadas do repo, onde precisa sair sem bloqueio.
# Gate que nunca viu vermelho não prova nada.

set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$HERE/.." || exit 2

LINT="python3 $HERE/../scripts/check-skill.py"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

passou=0
falhas=0
ok()   { printf '  ok    %s\n' "$1"; passou=$((passou + 1)); }
fail() { printf '  FALHA %s\n' "$1"; falhas=$((falhas + 1)); }

# Monta uma skill mínima e válida em $TMP/<nome>, pronta pra receber a violação.
planta() {
  local nome="$1"
  local dir="$TMP/$nome"
  mkdir -p "$dir"
  cat > "$dir/SKILL.md" <<EOF
---
name: $nome
description: Monta um artefato de teste a partir de um diretório. Use quando a suíte precisa de uma skill válida.
---

# ${nome}

Corpo mínimo, uma instrução por linha.
EOF
  echo "$dir"
}

esperado_limpo() {
  local desc="$1"; shift
  out=$($LINT "$@" 2>&1)
  if [ "$out" = "limpo." ]; then
    ok "$desc"
  else
    fail "$desc — esperava limpo, veio: $out"
  fi
}

# Aviso não trava o gate, então sem bloqueio é rc 0 com ou sem aviso na saída.
esperado_sem_bloqueio() {
  local desc="$1"; shift
  out=$($LINT "$@" 2>&1); rc=$?
  if [ "$rc" -eq 0 ]; then
    ok "$desc"
  else
    fail "$desc — esperava exit 0, veio $rc: $out"
  fi
}

esperado_pega() {
  local desc="$1" padrao="$2"; shift 2
  out=$($LINT "$@" 2>&1); rc=$?
  if [ "$rc" -ne 1 ]; then
    fail "$desc — esperava exit 1, veio $rc"
  elif ! grep -qi -- "$padrao" <<<"$out"; then
    fail "$desc — não achou /$padrao/ na saída: $out"
  else
    ok "$desc"
  fi
}

esperado_aviso() {
  local desc="$1" padrao="$2"; shift 2
  out=$($LINT "$@" 2>&1); rc=$?
  if [ "$rc" -ne 0 ]; then
    fail "$desc — aviso não pode travar o gate, veio exit $rc"
  elif ! grep -qi -- "aviso: .*$padrao" <<<"$out"; then
    fail "$desc — não achou aviso /$padrao/ na saída: $out"
  else
    ok "$desc"
  fi
}

echo "== skill válida =="
d=$(planta valida)
esperado_limpo "skill mínima passa" "$d"

echo "== frontmatter =="
d=$(planta sem-front); printf '# Sem frontmatter\n\nCorpo.\n' > "$d/SKILL.md"
esperado_pega "sem frontmatter" "sem frontmatter" "$d"

d=$(planta sem-name); sed -i.bak '/^name:/d' "$d/SKILL.md" && rm -f "$d/SKILL.md.bak"
esperado_pega "frontmatter sem name" "sem name" "$d"

d=$(planta sem-desc); sed -i.bak '/^description:/d' "$d/SKILL.md" && rm -f "$d/SKILL.md.bak"
esperado_pega "frontmatter sem description" "sem description" "$d"

d=$(planta name-torto); sed -i.bak 's/^name: name-torto/name: Name_Torto/' "$d/SKILL.md" && rm -f "$d/SKILL.md.bak"
esperado_pega "name fora do formato" "name inválido" "$d"

d=$(planta reservado); sed -i.bak 's/^name: reservado/name: claude-helper/' "$d/SKILL.md" && rm -f "$d/SKILL.md.bak"
esperado_pega "name com palavra reservada" "reservada" "$d"

d=$(planta divergente); sed -i.bak 's/^name: divergente/name: outra-coisa/' "$d/SKILL.md" && rm -f "$d/SKILL.md.bak"
esperado_pega "name diferente do diretório" "diferente do diretório" "$d"

d=$(planta desc-longa)
python3 - "$d/SKILL.md" <<'PY'
import sys
p = sys.argv[1]
t = open(p).read()
t = t.replace("Monta um artefato de teste a partir de um diretório.", "Monta " + "x" * 1100 + ".")
open(p, "w").write(t)
PY
esperado_pega "description acima de 1024 chars" "teto de 1024" "$d"

d=$(planta primeira-pessoa)
sed -i.bak 's/^description: .*/description: Eu monto o artefato pra você quando precisar./' "$d/SKILL.md" && rm -f "$d/SKILL.md.bak"
esperado_pega "description em primeira pessoa" "primeira ou segunda pessoa" "$d"

# Gatilho citado é fala do usuário, não a skill falando de si.
d=$(planta gatilho-citado)
sed -i.bak 's/^description: .*/description: Gera handoff da sessão. Invoque quando o usuário disser "vou compactar" ou "pausar por aqui"./' "$d/SKILL.md" && rm -f "$d/SKILL.md.bak"
esperado_limpo "gatilho entre aspas não conta como primeira pessoa" "$d"

d=$(planta sem-gatilho)
sed -i.bak 's/^description: .*/description: Monta artefato de teste a partir de diretório./' "$d/SKILL.md" && rm -f "$d/SKILL.md.bak"
esperado_aviso "description sem gatilho de uso" "sem gatilho" "$d"

echo "== corpo =="
d=$(planta corpo-longo)
{ cat "$d/SKILL.md"; for i in $(seq 1 520); do echo "linha $i"; done; } > "$d/tmp" && mv "$d/tmp" "$d/SKILL.md"
esperado_pega "corpo acima de 500 linhas" "teto de 500" "$d"

d=$(planta corpo-quase)
{ cat "$d/SKILL.md"; for i in $(seq 1 420); do echo "linha $i"; done; } > "$d/tmp" && mv "$d/tmp" "$d/SKILL.md"
esperado_aviso "corpo perto do teto" "perto do teto" "$d"

echo "== referência =="
d=$(planta link-morto)
printf '\nVer [o que não existe](references/fantasma.md).\n' >> "$d/SKILL.md"
esperado_pega "link relativo morto" "link morto" "$d"

d=$(planta aninhada); mkdir -p "$d/references"
printf '# A\n\nVer [B](b.md).\n' > "$d/references/a.md"
printf '# B\n\nConteúdo.\n' > "$d/references/b.md"
printf '\nVer `references/a.md` e `references/b.md`.\n' >> "$d/SKILL.md"
esperado_pega "referência que aponta pra referência" "referência aninhada" "$d"

d=$(planta sem-indice); mkdir -p "$d/references"
{ echo "# Longa"; echo; echo "## Uma seção"; for i in $(seq 1 120); do echo "linha $i"; done; } > "$d/references/longa.md"
printf '\nVer `references/longa.md`.\n' >> "$d/SKILL.md"
esperado_aviso "referência longa sem índice" "sem índice no topo" "$d"

d=$(planta com-indice); mkdir -p "$d/references"
{ echo "# Longa"; echo; echo "## Conteúdo"; echo; echo "- Uma seção"; echo; echo "## Uma seção"; for i in $(seq 1 120); do echo "linha $i"; done; } > "$d/references/longa.md"
printf '\nVer `references/longa.md`.\n' >> "$d/SKILL.md"
esperado_limpo "referência longa com índice passa" "$d"

d=$(planta orfa); mkdir -p "$d/references"
printf '# Órfã\n\nNinguém aponta pra cá.\n' > "$d/references/orfa.md"
esperado_aviso "referência não citada pelo SKILL.md" "não é citada" "$d"

# Amostra de artefato é molde: índice enfiado no meio estragaria o molde, e o
# SKILL.md não navega pra ela porque quem consome é o teste ou o exemplo.
d=$(planta amostra); mkdir -p "$d/fixtures" "$d/references/exemplos"
{ echo "# PRD de exemplo"; echo; echo "## Problema"; for i in $(seq 1 120); do echo "linha $i"; done; } > "$d/references/exemplos/PRD.md"
{ echo "# spec ruim"; for i in $(seq 1 120); do echo "linha $i"; done; } > "$d/fixtures/spec-ruim.md"
printf '\nVer `references/exemplos/PRD.md`.\n' >> "$d/SKILL.md"
esperado_limpo "amostra em exemplos/ e fixtures/ fica fora da régua de índice" "$d"

echo "== caminho =="
d=$(planta backslash)
printf '\nRodar `scripts\\helper.py`.\n' >> "$d/SKILL.md"
esperado_pega "caminho com barra invertida" "barra invertida" "$d"

echo "== diretório =="
mkdir -p "$TMP/vazia"
esperado_pega "diretório sem SKILL.md" "sem SKILL.md" "$TMP/vazia"

out=$($LINT "$TMP/nao-existe" 2>&1); rc=$?
[ "$rc" -eq 2 ] && ok "alvo inexistente sai com exit 2" || fail "alvo inexistente — esperava exit 2, veio $rc"

echo "== repo real =="
# Só as skills versionadas: diretório não rastreado é resíduo de máquina.
mapfile -t VERSIONADAS < <(git ls-files skills/ | cut -d/ -f1-2 | sort -u | grep -v '^skills/_')
if [ "${#VERSIONADAS[@]}" -eq 0 ]; then
  fail "nenhuma skill versionada encontrada"
else
  esperado_sem_bloqueio "${#VERSIONADAS[@]} skills versionadas sem bloqueio" "${VERSIONADAS[@]}"
fi

echo
echo "== $passou passed, $falhas failed =="
[ "$falhas" -eq 0 ]
