#!/usr/bin/env bash
# Suíte do resolve-context.py (skill execute). Prova que o resolvedor devolve o
# contexto completo quando há spec, tickets e verify real, e que trava quando
# falta o que nenhum ticket fecha sem.
# Uso: bash tests/execute-context.test.sh

set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$HERE/.."
RESOLVE="python3 $ROOT/skills/execute/scripts/resolve-context.py"
FIX="$ROOT/skills/to-spec/fixtures"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

passou=0; falhas=0
ok()   { printf '  ok    %s\n' "$1"; passou=$((passou + 1)); }
fail() { printf '  FALHA %s\n' "$1"; falhas=$((falhas + 1)); }

# Repo mínimo: project.yaml, spec boa e os três tickets bons das fixtures do to-spec.
planta_repo() {
  local dir="$TMP/$1"
  mkdir -p "$dir/.claude" "$dir/docs/specs/category-derivada/tickets"
  cat > "$dir/.claude/project.yaml" <<'EOF'
tracker:
  backend: none   # ticket = .md
repo:
  trunk: main
  branch_prefix: feature
verify_cmd: "uv run pytest"
smoke_cmd: "uv run pytest tests/smoke -q"
EOF
  cp "$FIX/spec-boa.md" "$dir/docs/specs/category-derivada/spec.md"
  cp "$FIX"/tickets-bons/*.md "$dir/docs/specs/category-derivada/tickets/"
  echo "$dir"
}

campo() { python3 -c 'import json,sys; d=json.load(sys.stdin); print(json.dumps(d'"$1"', ensure_ascii=False))'; }

echo "== contexto completo =="
repo=$(planta_repo bom)
out=$($RESOLVE category-derivada --root "$repo"); rc=$?
[ "$rc" -eq 0 ] && ok "repo completo sai exit 0" || fail "repo completo veio exit $rc: $out"
[ "$(campo '["ticket_count"]' <<<"$out")" = "3" ] && ok "conta os três tickets" || fail "ticket_count errado"
[ "$(campo '["simplify_suggested"]' <<<"$out")" = "false" ] && ok "3 tickets não sugere simplify" || fail "simplify sugerido com 3 tickets"
[ "$(campo '["tickets"][0]["parallel"]' <<<"$out")" = "true" ] && ok "lê o marcador [P]" || fail "não leu [P] do ticket 01"
[ "$(campo '["tickets"][0]["delega"]' <<<"$out")" = '"implement"' ] && ok "lê delega:" || fail "delega: não lido"
[ "$(python3 -c 'import json,sys; print(len(json.load(sys.stdin)["tickets"][0]["files"]))' <<<"$out")" = "3" ] && ok "files: multilinha vira lista" || fail "files: multilinha não parseado"
[ "$(campo '["tickets"][2]["blocked_by"]' <<<"$out")" != '""' ] && ok "lê blocked_by" || fail "blocked_by vazio"
[ "$(campo '["trunk"]' <<<"$out")" = '"main"' ] && ok "trunk do project.yaml" || fail "trunk errado"
[ "$(campo '["brief"]' <<<"$out")" = "null" ] && ok "brief ausente vira null" || fail "brief inventado"
mkdir -p "$repo/_tmp/execute" && echo "spec: category-derivada" > "$repo/_tmp/execute/category-derivada.md"
out=$($RESOLVE category-derivada --root "$repo")
[ "$(campo '["brief"]' <<<"$out")" != "null" ] && ok "brief presente é apontado" || fail "brief presente ignorado"

echo "== simplify por contagem =="
repo=$(planta_repo seis)
for n in 04 05 06; do
  sed "s/^01 /$n /" "$FIX/tickets-bons/01-category-dtr.md" > "$repo/docs/specs/category-derivada/tickets/$n-extra.md"
done
out=$($RESOLVE category-derivada --root "$repo")
[ "$(campo '["simplify_suggested"]' <<<"$out")" = "true" ] && ok "6 tickets sugere simplify" || fail "6 tickets sem sugestão"
out=$($RESOLVE category-derivada --root "$repo" --simplify-min 7)
[ "$(campo '["simplify_suggested"]' <<<"$out")" = "false" ] && ok "--simplify-min sobe o degrau" || fail "--simplify-min ignorado"

echo "== bloqueantes =="
repo=$(planta_repo sem-spec); rm "$repo/docs/specs/category-derivada/spec.md"
out=$($RESOLVE category-derivada --root "$repo"); rc=$?
[ "$rc" -eq 1 ] && grep -q "spec não encontrada" <<<"$out" && ok "spec ausente trava" || fail "spec ausente não travou (rc=$rc)"

repo=$(planta_repo todo); sed -i '' 's/^verify_cmd:.*/verify_cmd: "<TODO: comando>"/' "$repo/.claude/project.yaml"
out=$($RESOLVE category-derivada --root "$repo"); rc=$?
[ "$rc" -eq 1 ] && grep -q "verify_cmd ausente ou placeholder" <<<"$out" && ok "verify_cmd placeholder trava" || fail "placeholder passou (rc=$rc)"

repo=$(planta_repo sem-tickets); rm "$repo"/docs/specs/category-derivada/tickets/*.md
out=$($RESOLVE category-derivada --root "$repo"); rc=$?
[ "$rc" -eq 1 ] && grep -q "nenhum ticket" <<<"$out" && ok "diretório de tickets vazio trava" || fail "tickets vazios passaram (rc=$rc)"

repo=$(planta_repo grande); sed -i '' 's/^01 \[XS\]/01 [L]/' "$repo/docs/specs/category-derivada/tickets/01-category-dtr.md"
out=$($RESOLVE category-derivada --root "$repo"); rc=$?
[ "$rc" -eq 1 ] && grep -q "tamanho L" <<<"$out" && ok "ticket L trava" || fail "ticket L passou (rc=$rc)"

repo=$(planta_repo sem-campo); sed -i '' '/^delega:/d' "$repo/docs/specs/category-derivada/tickets/02-category-pdv.md"
out=$($RESOLVE category-derivada --root "$repo"); rc=$?
[ "$rc" -eq 1 ] && grep -q 'campo `delega:` ausente' <<<"$out" && ok "campo obrigatório ausente trava" || fail "campo ausente passou (rc=$rc)"

echo "== avisos não travam =="
repo=$(planta_repo notion); sed -i '' 's/backend: none.*/backend: notion/' "$repo/.claude/project.yaml"
out=$($RESOLVE category-derivada --root "$repo"); rc=$?
[ "$rc" -eq 0 ] && grep -q "backend notion" <<<"$out" && ok "backend externo avisa e segue" || fail "backend externo travou (rc=$rc)"

repo=$(planta_repo smoke-todo); sed -i '' 's/^smoke_cmd:.*/smoke_cmd: "<TODO: smoke>"/' "$repo/.claude/project.yaml"
out=$($RESOLVE category-derivada --root "$repo"); rc=$?
[ "$rc" -eq 0 ] && [ "$(campo '["smoke_cmd"]' <<<"$out")" = '""' ] && ok "smoke placeholder vira vazio com aviso" || fail "smoke placeholder travou ou vazou (rc=$rc)"

echo "== uso =="
$RESOLVE >/dev/null 2>&1; rc=$?
[ "$rc" -eq 2 ] && ok "sem slug é erro de uso" || fail "sem slug veio exit $rc"

echo
echo "$passou ok, $falhas falhas"
[ "$falhas" -eq 0 ]
