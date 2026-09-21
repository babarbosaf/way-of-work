#!/usr/bin/env bash
# Guarda de agnosticismo do repo público: identidade do dono, caminho da máquina
# dele, unidade de negócio e ponteiro morto não entram no que é versionado.
# Uso: bash tests/agnostico.test.sh
#
# Toda regra roda duas vezes: no repo de verdade, onde precisa dar zero, e num
# arquivo com a violação plantada, onde precisa acusar. Assert que nunca viu
# vermelho não prova nada.
set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$HERE/.."
cd "$ROOT" || exit 1
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

PASS=0; FAIL=0
ok()   { PASS=$((PASS+1)); echo "  ✓ $1"; }
fail() { FAIL=$((FAIL+1)); echo "  ✗ $1"; }

# scan REGEX [EXCECAO] : varre os arquivos de texto do repo e imprime os hits.
# --untracked porque o vazamento chega em arquivo novo: sem isso o gate passa
# verde antes do commit e só acusa depois que o conteúdo já subiu.
# A exceção é por CONTEÚDO da linha, nunca por arquivo: isentar arquivo inteiro é
# o buraco por onde o próximo vazamento entra verde.
scan() {
  local regex="$1" excecao="${2:-}"
  local hits
  hits=$(git grep --untracked -inIE "$regex" -- $FILES 2>/dev/null || true)
  # linha marcada com guard-regex é dado desta suíte (padrão ou violação
  # plantada), não conteúdo do repo.
  hits=$(grep -vE '# guard-regex' <<<"$hits" || true)
  [[ -n "$excecao" ]] && hits=$(grep -vE "$excecao" <<<"$hits" || true)
  printf '%s' "$hits"
}

# regra NOME REGEX [EXCECAO] : zero no repo, e acusa na violação plantada.
regra() {
  local nome="$1" regex="$2" excecao="${3:-}"
  local hits
  hits=$(scan "$regex" "$excecao")
  if [[ -z "$hits" ]]; then ok "$nome: zero no repo"
  else fail "$nome: $(wc -l <<<"$hits" | tr -d ' ') hit(s)"; sed 's/^/      /' <<<"$hits"; fi
}

plantado() {
  local nome="$1" regex="$2" linha="$3" excecao="${4:-}"
  printf '%s\n' "$linha" > "$TMP/plantado.md"
  local hits
  hits=$( (cd "$TMP" && git grep --no-index -inIE "$regex" -- plantado.md) || true)
  [[ -n "$excecao" ]] && hits=$(grep -vE "$excecao" <<<"$hits" || true)
  if [[ -n "$hits" ]]; then ok "$nome: acusa a violação plantada"
  else fail "$nome: NÃO acusou a violação plantada (regra morta)"; fi
}

# --others: arquivo novo ainda não commitado entra na varredura. É onde o
# vazamento chega, e é antes do commit que o gate precisa acusar.
FILES=$(git ls-files --cached --others --exclude-standard | tr '\n' ' ')

# O nome do dono é legítimo em dois lugares: a linha de copyright da LICENSE e a
# URL do próprio repo. Em qualquer outro, é identidade vazando.
DONO='benedito|barbosa|maracaj|robson'  # guard-regex
DONO_OK='Copyright \(c\)|github\.com/babarbosaf|# guard-regex'  # guard-regex

echo "== identidade =="
regra    "nome do dono"      "$DONO" "$DONO_OK"  # guard-regex
plantado "nome do dono"      "$DONO" "Perguntar pro Benedito antes de mergear." "$DONO_OK"  # guard-regex
regra    "caminho da máquina" '/Users/[a-z]'  # guard-regex
plantado "caminho da máquina" '/Users/[a-z]' "Roda em /Users/alguem/projeto."  # guard-regex
PRIMEIRA='(^|[^[:alpha:]])(meu|minha|meus|minhas)([^[:alpha:]]|$)|não edito'  # guard-regex
# Duas exceções por conteúdo: o regex do próprio check-skill.py, que existe pra
# cobrar isso, e fala de terceiro citada entre aspas numa tabela de anti-padrão,
# que é o repo mostrando o que alguém diz, não o repo falando.
PRIMEIRA_OK='re\.compile|\| "'  # guard-regex
regra    "primeira pessoa"   "$PRIMEIRA" "$PRIMEIRA_OK"  # guard-regex
plantado "primeira pessoa"   "$PRIMEIRA" "Este é o meu fluxo." "$PRIMEIRA_OK"  # guard-regex
regra    "organização do dono" 'da casa|na casa|nossa casa'  # guard-regex
plantado "organização do dono" 'da casa|na casa|nossa casa' "A stack padrão da casa."  # guard-regex
regra    "máquina ou SO específico" 'meu mac|fora do mac|meu notebook'  # guard-regex
plantado "máquina ou SO específico" 'meu mac|fora do mac|meu notebook' "Fora do Mac isso não roda."  # guard-regex
# Caminho de trabalho fora do diretório de config é topologia privada: nome de
# projeto, layout de disco e, junto, o histórico de incidente que veio com ele.
# Um hook privado entrou num commit por `git add -A` antes desta regra existir.
# `Projects/repo` é o placeholder do exemplo de worktree, não projeto real.
regra    "caminho de trabalho privado" '~/(Projects|Documents|Desktop)|\$HOME/(Projects|Documents|Desktop)' 'Projects/repo'  # guard-regex
plantado "caminho de trabalho privado" '~/(Projects|Documents|Desktop)|\$HOME/(Projects|Documents|Desktop)' "WIKI = os.path.expanduser(\"~/Projects/llm-wiki\")"  # guard-regex

echo "== ponteiro morto =="
# CHANGELOG registra o que já saiu, então cita nome de arquivo removido por
# desenho, e fixture de lint cita ponteiro morto de propósito. A guarda vale pro
# resto, e o [Unreleased] tem assert próprio abaixo.
MORTO='RUNBOOK\.md|templates/VOZ|docs/research/escrita\.md|CONTEXT\.md|ADR-000|specs/done/'  # guard-regex
SALVO='^(CHANGELOG\.md|tests/fixtures/)'  # guard-regex
regra    "ponteiro pra arquivo removido" "$MORTO" "$SALVO"  # guard-regex
plantado "ponteiro pra arquivo removido" "$MORTO" "Ver RUNBOOK.md para o passo a passo." "$SALVO"  # guard-regex

quebrados=$(python3 "$HERE/check-links.py" || true)
if [[ -z "$quebrados" ]]; then ok "link markdown relativo: todos resolvem"
else fail "link markdown relativo quebrado"; sed 's/^/      /' <<<"$quebrados"; fi

echo "== plano e conta do dono =="
# Qual serviço o dono assina, quanto paga e o que está setado na máquina dele não
# é doutrina: é a intimidade dele. O repo diz QUE existe hierarquia de modelos e
# COMO ela se declara, nunca de quem é a fatura. Nome de modelo fica, porque é o
# dado que a policy roteia; nome de plano comercial e preço, não.
PLANO='chatgpt|\$[0-9]+ ?/ ?m[êe]s|\$[0-9]+/m|r\$ ?[0-9]|(assinatura|plano|cota) (j[áa] )?pag[oa]|dono (j[áa] )?paga|que o dono paga|nesta conta|setad[ao] neste ambiente|conectado em (jan|fev|mar|abr|mai|jun|jul|ago|set|out|nov|dez)'  # guard-regex
regra    "plano ou preço do dono" "$PLANO"  # guard-regex
plantado "plano ou preço do dono" "$PLANO" "O codex é ChatGPT Plus (\$20/mês), custo marginal zero."  # guard-regex

echo "== ponteiro pra artefato fora do git =="
# `docs/specs/` e `docs/research/` são gitignored, e tracker é privado: um ID de
# spec ou de ticket num arquivo versionado manda o leitor abrir o que ele não tem.
# A convenção de caminho (`docs/specs/<slug>/spec.md`) fica, porque ensina onde
# ele põe as dele; o ID concreto, não. Fixture de lint cita ID de propósito.
FORAGIT='(SPEC|CORE|RTK|PROD|OPS)-[0-9]{3,4}|spec [0-9]{4}-[0-9]{3}'  # guard-regex
FORAGIT_OK='^skills/to-spec/fixtures/|^tests/fixtures/|# guard-regex'  # guard-regex
regra    "ID de spec ou de ticket" "$FORAGIT" "$FORAGIT_OK"  # guard-regex
plantado "ID de spec ou de ticket" "$FORAGIT" "Circuit-breaker vive no delegate.sh (SPEC-2026-002 D-04)." "$FORAGIT_OK"  # guard-regex

echo "== unidade de negócio =="
NEGOCIO='comercial nontech|exitlag|holding imob|xanim|liberdata'  # guard-regex
regra    "nome de unidade ou cliente" "$NEGOCIO"  # guard-regex
plantado "nome de unidade ou cliente" "$NEGOCIO" "Roteia pro comercial nontech."  # guard-regex

echo "== permissão suprimida no settings versionado =="
FLAGS='skipDangerousModePermissionPrompt|skipAutoPermissionPrompt|"defaultMode"'  # guard-regex
if grep -qE "$FLAGS" settings.json; then
  fail "settings.json versionado desliga confirmação de permissão"
  grep -nE "$FLAGS" settings.json | sed 's/^/      /'
else
  ok "settings.json: nenhuma flag que suprime permissão"
fi
printf '{"env":{"skipAutoPermissionPrompt":"true"}}\n' > "$TMP/s.json"
if grep -qE "$FLAGS" "$TMP/s.json"; then ok "flags: acusa a violação plantada"
else fail "flags: NÃO acusou a violação plantada (regra morta)"; fi

echo "== LICENSE =="
n=$(grep -c 'Copyright (c)' LICENSE || true)  # guard-regex
[[ "$n" == "1" ]] && ok "LICENSE tem exatamente uma linha de copyright" \
                  || fail "LICENSE tem $n linhas de copyright (esperado 1)"
outros=$(git grep -nI 'Copyright (c)' -- . | grep -vE '^LICENSE:|# guard-regex' || true)  # guard-regex
[[ -z "$outros" ]] && ok "copyright só na LICENSE" \
                   || { fail "copyright fora da LICENSE"; sed 's/^/      /' <<<"$outros"; }

echo
echo "== $PASS passed, $FAIL failed =="
[[ $FAIL -eq 0 ]]
