#!/usr/bin/env bash
# Aplica o contrato do RTK desta máquina (config/rtk.json). Dry-run por default:
# imprime o que faria e não muda nada. Com --apply, executa.
#
# Dois modos, mesma convenção do bootstrap-plugins.sh. Sem flag: instala o RTK se
# faltar e escreve `[hooks] exclude_commands` no config.toml. Com --update:
# `brew upgrade rtk` antes de reescrever a config, porque chave nova do upstream
# só aparece depois do binário novo.
#
# Por que o bypass mora na config e não no hook wrapper: o RTK casa
# exclude_commands contra a forma peeled do comando desde a 0.47 (env-prefix,
# `uv run`, segmento de pipe). Regex de shell no wrapper não fazia isso.
set -uo pipefail

PROG=bootstrap-rtk
HELP_ATE=12
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MANIFEST="${MANIFEST:-$RAIZ/config/rtk.json}"
. "$RAIZ/scripts/bootstrap-common.sh"
bootstrap_args "$@"
bootstrap_prereq

MINIMA=$(jq -r '.versao_minima // ""' "$MANIFEST")

# Instalação: o RTK é opcional, então ausência não é erro — é trabalho a fazer.
if ! command -v rtk >/dev/null 2>&1; then
  if (( APPLY == 0 )); then
    dry_run_banner
    echo "brew install rtk"
    echo "# (config só depois do binário; rode de novo pra ver o resto)"
    exit 0
  fi
  echo "+ brew install rtk"
  brew install rtk || { echo "bootstrap-rtk: brew install falhou" >&2; exit 1; }
fi

if (( UPDATE == 1 )); then
  if (( APPLY == 0 )); then
    dry_run_banner
    echo "brew upgrade rtk"
  else
    echo "+ brew upgrade rtk"
    brew upgrade rtk || echo "  já na última, ou brew falhou. Segue." >&2
  fi
fi

INSTALADA=$(rtk --version 2>/dev/null | awk '{print $2}')
MEDIDA=$(jq -r '.versao_medida // ""' "$MANIFEST")
if [[ -n "$MEDIDA" && -n "$INSTALADA" && "$MEDIDA" != "$INSTALADA" ]]; then
  echo "bootstrap-rtk: docs/rtk.md foi medido na $MEDIDA, e agora roda $INSTALADA." >&2
  echo "  Remeça as afirmações do doc, corrija o que mudou e suba versao_medida no manifesto." >&2
  echo "  Até lá, tests/hooks.test.sh falha de propósito." >&2
fi
if [[ -n "$MINIMA" && -n "$INSTALADA" ]]; then
  if [[ "$(printf '%s\n%s\n' "$MINIMA" "$INSTALADA" | sort -V | head -1)" != "$MINIMA" ]]; then
    echo "bootstrap-rtk: rtk $INSTALADA é anterior à mínima $MINIMA do manifesto." >&2
    echo "  exclude_commands só é honrado na forma peeled a partir da 0.47. Rode --update." >&2
  fi
fi

# O próprio RTK diz onde mora a config (macOS e Linux divergem).
CONFIG=$(rtk config 2>/dev/null | sed -n '1s/^Config: //p')
[[ -n "$CONFIG" ]] || { echo "bootstrap-rtk: não consegui descobrir o config.toml" >&2; exit 1; }

DESEJADO=$(jq -r '.hooks.exclude_commands[]' "$MANIFEST")

if (( APPLY == 0 )); then
  dry_run_banner
  echo "# config: $CONFIG"
  echo "# [hooks] exclude_commands ="
  while IFS= read -r c; do echo "#   $c"; done <<<"$DESEJADO"
  exit 0
fi

[[ -f "$CONFIG" ]] || { echo "+ rtk config --create"; rtk config --create >/dev/null; }

MANIFEST="$MANIFEST" CONFIG="$CONFIG" python3 - <<'PY'
import json, os, re, sys, tomllib

manifesto = json.load(open(os.environ["MANIFEST"], encoding="utf-8"))
alvo = list(manifesto["hooks"]["exclude_commands"])
caminho = os.environ["CONFIG"]
texto = open(caminho, encoding="utf-8").read()

atual = tomllib.loads(texto).get("hooks", {}).get("exclude_commands", [])
if atual == alvo:
    print(f"bootstrap-rtk: config já casa com o manifesto ({len(alvo)} comandos).")
    sys.exit(0)

bloco = "exclude_commands = [\n" + "".join(f'    "{c}",\n' for c in alvo) + "]"
novo, n = re.subn(
    r"^exclude_commands\s*=\s*\[[^\]]*\]",
    lambda _: bloco,
    texto,
    count=1,
    flags=re.MULTILINE | re.DOTALL,
)
if n == 0:
    if "[hooks]" in novo:
        novo = novo.replace("[hooks]", "[hooks]\n" + bloco, 1)
    else:
        novo = novo.rstrip("\n") + "\n\n[hooks]\n" + bloco + "\n"

# Só escreve o que volta a fazer parse, e com o valor que se quis escrever.
checado = tomllib.loads(novo).get("hooks", {}).get("exclude_commands", [])
if checado != alvo:
    sys.exit(f"bootstrap-rtk: patch do TOML não bateu ({checado!r}); config intocada.")

open(caminho, "w", encoding="utf-8").write(novo)
print(f"bootstrap-rtk: exclude_commands atualizado ({len(alvo)} comandos) em {caminho}")
PY
