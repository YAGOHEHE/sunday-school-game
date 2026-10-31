#!/usr/bin/env python3
"""Fusiona Resources/parts/part{A,B,C}.json en Resources/games.json y valida."""
import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RES = os.path.join(ROOT, "App", "Sources", "JuegosCore", "Resources")
PARTS = os.path.join(RES, "parts")
OUT = os.path.join(RES, "games.json")

errors = []


def check_l(v, where):
    if isinstance(v, dict) and set(v.keys()) >= {"es", "zh"} and all(isinstance(v[k], str) for k in ("es", "zh")) \
            and ("front" not in v):
        if not v["es"].strip() or not v["zh"].strip():
            errors.append(f"{where}: es/zh vacío -> {v}")
        return
    if isinstance(v, dict):
        for k, x in v.items():
            check_l(x, f"{where}.{k}")
    elif isinstance(v, list):
        for i, x in enumerate(v):
            check_l(x, f"{where}[{i}]")


def load(name):
    path = os.path.join(PARTS, name)
    try:
        with open(path, encoding="utf-8") as f:
            return json.load(f)
    except FileNotFoundError:
        errors.append(f"falta {path}")
    except json.JSONDecodeError as e:
        errors.append(f"{name}: JSON inválido: {e}")
    return None


def main():
    a, b, c = load("partA.json"), load("partB.json"), load("partC.json")
    if errors:
        return finish()
    games = []
    for name, part in (("partA", a), ("partB", b), ("partC", c)):
        gs = part.get("games")
        if not isinstance(gs, list):
            errors.append(f"{name}: falta 'games' (lista)")
            continue
        games += gs
    challenges = c.get("challenges")
    if not isinstance(challenges, list) or not challenges:
        errors.append("partC: falta 'challenges'")
        challenges = []
    seen = set()
    for g in games:
        gid = g.get("id", "<sin id>")
        if gid in seen:
            errors.append(f"id duplicado: {gid}")
        seen.add(gid)
        check_l(g, f"game[{gid}]")
    check_l(challenges, "challenges")
    if errors:
        return finish()
    with open(OUT, "w", encoding="utf-8") as f:
        json.dump({"version": 1, "challenges": challenges, "games": games}, f, ensure_ascii=False, indent=2)
        f.write("\n")
    print(f"OK: {len(games)} juegos, {len(challenges)} retos -> {OUT}")
    return 0


def finish():
    for e in errors:
        print("ERROR:", e, file=sys.stderr)
    return 1


if __name__ == "__main__":
    sys.exit(main())
