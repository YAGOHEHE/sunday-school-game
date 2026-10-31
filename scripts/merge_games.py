#!/usr/bin/env python3
"""Fusiona Resources/parts/*.json (orden alfabético) en Resources/games.json y valida."""
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
    names = sorted(n for n in os.listdir(PARTS) if n.endswith(".json"))
    if not names:
        errors.append(f"sin parts en {PARTS}")
        return finish()
    parts = [(n, load(n)) for n in names]
    if errors:
        return finish()
    games = []
    challenges = None
    for name, part in parts:
        gs = part.get("games")
        if not isinstance(gs, list):
            errors.append(f"{name}: falta 'games' (lista)")
            continue
        games += gs
        if challenges is None and isinstance(part.get("challenges"), list) and part["challenges"]:
            challenges = part["challenges"]
    if challenges is None:
        errors.append("ningún part tiene 'challenges'")
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
