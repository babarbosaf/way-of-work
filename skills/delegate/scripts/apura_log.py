#!/usr/bin/env python3
"""Apura a policy de delegação a partir do log JSONL de auditoria."""

import argparse
import json
import math
import re
import sys
from collections import defaultdict
from datetime import datetime, timedelta, timezone
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
# O detail é uma string de campos separados por espaço (model=, branch=, base=,
# saldo=), então o nome do modelo termina no primeiro espaço. Casar até o
# ponto-e-vírgula engolia o resto da linha e transformava degrau já provado em
# buraco, que é o erro mais caro aqui: é ele que decide se a fila pode virar.
MODELOS = re.compile(r"(?:^|[;,\s])model=([^;\s]+)")
# Consumo de cota e amostra de duração não são a mesma população. As duas
# gastaram chamada, mas empty_diff é falha silenciosa do worker, e o teto de
# espera sai só do que terminou bem.
CHAMADAS = {"ok", "empty_diff"}
BEM_SUCEDIDAS = {"ok"}


def argumentos():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--log", type=Path, default=Path.home() / ".claude/gate/delegate.log")
    parser.add_argument("--policy", type=Path, default=ROOT / "config/model-policy.json")
    parser.add_argument("--check", action="store_true", help="falha quando a policy diverge da apuração")
    return parser.parse_args()


def ler_jsonl(caminho):
    linhas = []
    with caminho.open(encoding="utf-8") as arquivo:
        for numero, texto in enumerate(arquivo, 1):
            texto = texto.strip()
            if not texto:
                continue
            try:
                linha = json.loads(texto)
                linha["_ts"] = datetime.fromisoformat(linha["ts"].replace("Z", "+00:00"))
            except (ValueError, KeyError, json.JSONDecodeError) as erro:
                raise ValueError(f"{caminho}:{numero}: JSONL inválido: {erro}") from erro
            linhas.append(linha)
    return linhas


def modelo(linha):
    achado = MODELOS.search(str(linha.get("detail", "")))
    return achado.group(1).strip() if achado else None


def pico_por_janela(linhas, janela):
    por_pool = defaultdict(list)
    for linha in linhas:
        if linha.get("status") in CHAMADAS and linha.get("pool"):
            por_pool[linha["pool"]].append(linha["_ts"])
    picos = {}
    for pool, tempos in por_pool.items():
        tempos.sort()
        inicio = 0
        pico = 0
        for fim, tempo in enumerate(tempos):
            while tempo - tempos[inicio] > janela:
                inicio += 1
            pico = max(pico, fim - inicio + 1)
        picos[pool] = pico
    return picos


def entradas_declaradas(policy):
    for tipo, entradas in policy.get("tasks", {}).items():
        if isinstance(entradas, list):
            for indice, entrada in enumerate(entradas):
                yield f"tasks.{tipo}[{indice}]", entrada
    for tipo, tiers in policy.get("tiers", {}).items():
        if not isinstance(tiers, dict):
            continue
        for tier, entradas in tiers.items():
            if isinstance(entradas, list):
                for indice, entrada in enumerate(entradas):
                    yield f"tiers.{tipo}.{tier}[{indice}]", entrada


def apurar(linhas, policy):
    agora = datetime.now(timezone.utc)
    recentes = [linha for linha in linhas if linha["_ts"] >= agora - timedelta(days=30)]
    janela_mins = policy["budgets"]["window_mins"]
    picos = pico_por_janela(recentes, timedelta(minutes=janela_mins))
    pools = {}
    for pool, declarado in policy["budgets"]["pools"].items():
        # Régua recusada de propósito não é régua ausente. O pico medido é piso de
        # uso, não teto do provider, e um balde que ninguém gastou ainda viraria
        # régua de duas ou três chamadas, estrangulando justamente quem lidera a
        # fila. Aqui fica o que a policy declara, com o pico observado ao lado pra
        # a decisão futura ter o dado na mão.
        if isinstance(declarado, dict) and "max_calls" not in declarado:
            pools[pool] = dict(declarado)
            if pool in picos:
                pools[pool]["observado"] = picos[pool]
        elif pool in picos:
            pools[pool] = {"max_calls": picos[pool]}
        else:
            pools[pool] = {"status": "sem_amostra"}

    por_task = defaultdict(list)
    vistos = set()
    for linha in linhas:
        nome_modelo = modelo(linha)
        if nome_modelo and linha.get("status") in CHAMADAS:
            vistos.add((linha.get("backend"), nome_modelo))
        if linha.get("status") in BEM_SUCEDIDAS and isinstance(linha.get("dur_s"), (int, float)):
            por_task[linha.get("task")].append(linha["dur_s"])
    timeouts = {}
    for task, declarado in policy.get("timeouts", {}).items():
        if task.startswith("$"):
            continue
        duracoes = por_task[task]
        if len(duracoes) >= 10:
            timeouts[task] = {"seconds": math.ceil(2 * max(duracoes)), "status": "medido", "calls": len(duracoes)}
        else:
            timeouts[task] = {"seconds": declarado, "status": "estimativa", "calls": len(duracoes)}

    nao_provadas = []
    for caminho, entrada in entradas_declaradas(policy):
        identidade = (entrada.get("backend"), entrada.get("model"))
        if identidade not in vistos:
            nao_provadas.append({"path": caminho, "backend": identidade[0], "model": identidade[1]})
    return {
        "budgets": {"window_mins": janela_mins, "pools": pools},
        "timeouts": timeouts,
        "unproven_entries": nao_provadas,
    }


def divergencias(apurado, policy):
    erros = []
    for pool, valor in apurado["budgets"]["pools"].items():
        declarado = policy["budgets"]["pools"].get(pool)
        if isinstance(declarado, dict) and "max_calls" not in declarado:
            continue
        if declarado != valor:
            erros.append(f"budgets.pools.{pool}: declarado {declarado}, apurado {valor}")
    for task, valor in apurado["timeouts"].items():
        if valor["status"] == "medido" and policy["timeouts"].get(task) != valor["seconds"]:
            erros.append(f"timeouts.{task}: declarado {policy['timeouts'].get(task)}, apurado {valor['seconds']}")
    return erros


def main():
    args = argumentos()
    try:
        with args.policy.open(encoding="utf-8") as arquivo:
            policy = json.load(arquivo)
        apurado = apurar(ler_jsonl(args.log), policy)
    except (OSError, ValueError, json.JSONDecodeError, KeyError) as erro:
        print(f"erro: {erro}", file=sys.stderr)
        return 1
    print(json.dumps(apurado, ensure_ascii=False, indent=2, sort_keys=True))
    if args.check:
        erros = divergencias(apurado, policy)
        if erros:
            print("policy divergente:", *erros, sep="\n", file=sys.stderr)
            return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
