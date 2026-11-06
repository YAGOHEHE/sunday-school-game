#!/usr/bin/env python3
"""Genera App/Sources/JuegosCore/Resources/parts/partG.json (juego 'viajes-pablo').

Las posiciones x/y se calculan con la MISMA proyección equirrectangular que la
lámina mapa-mediterraneo.jpg y el helper GeoWindow.mediterranean de Swift:
    x = (lon + 10.6) / 48.0
    y = (47.75 - lat) / 18.9123
No se escriben a mano. Además comprueba que ningún lugar quede a < 0.012 de otro.
"""
import json
import math
import os
import sys

LON_MIN, LON_MAX = -10.6, 37.4
LAT_MIN, LAT_MAX = 28.8377, 47.75
LON_SPAN = LON_MAX - LON_MIN          # 48.0
LAT_SPAN = LAT_MAX - LAT_MIN          # 18.9123
ASPECT = LON_SPAN / LAT_SPAN          # ~2.0
MIN_DIST = 0.012                      # misma épsilon que MapState.reveal


def project(lon, lat):
    return (lon - LON_MIN) / LON_SPAN, (LAT_MAX - lat) / LAT_SPAN


def L(es, zh):
    return {"es": es, "zh": zh}


# (es, zh[和合本], lon, lat, back_es, back_zh)
GROUPS = [
    (L("Primer viaje y punto de partida", "第一次旅行与起点"), [
        ("Jerusalén", "耶路撒冷", 35.23, 31.78,
         "La iglesia madre; desde aquí se envía el evangelio. Hechos 15.",
         "母会所在地；福音从这里传开。使徒行传15章。"),
        ("Antioquía de Siria", "安提阿", 36.16, 36.20,
         "La iglesia que envió a Pablo y Bernabé; aquí se les llamó cristianos. Hechos 13:1-3.",
         "差派保罗和巴拿巴的教会；门徒最初在这里被称为基督徒。使徒行传13:1-3。"),
        ("Tarso", "大数", 34.90, 36.92,
         "Ciudad natal de Pablo, en Cilicia. Hechos 22:3.",
         "保罗的家乡，在基利家。使徒行传22:3。"),
        ("Salamina (Chipre)", "撒拉米（居比路）", 33.90, 35.18,
         "Primera parada en Chipre; predican en las sinagogas. Hechos 13:5.",
         "在居比路的第一站；在会堂里传道。使徒行传13:5。"),
        ("Pafos (Chipre)", "帕弗（居比路）", 32.41, 34.76,
         "Allí se convierte el procónsul Sergio Paulo. Hechos 13:6-12.",
         "方伯士求保罗在这里信主。使徒行传13:6-12。"),
        ("Perge", "别加", 30.85, 36.96,
         "En Panfilia; aquí Juan Marcos se vuelve a Jerusalén. Hechos 13:13.",
         "在旁非利亚；约翰·马可在这里离队回耶路撒冷。使徒行传13:13。"),
        ("Antioquía de Pisidia", "彼西底的安提阿", 31.19, 38.31,
         "Gran sermón de Pablo en la sinagoga. Hechos 13:14-41.",
         "保罗在会堂里讲了一篇大道。使徒行传13:14-41。"),
        ("Iconio", "以哥念", 32.49, 37.87,
         "Muchos creen, pero deben huir de una revuelta. Hechos 14:1-6.",
         "许多人信了，但因骚乱不得不离开。使徒行传14:1-6。"),
        ("Listra", "路司得", 32.28, 37.58,
         "Sanan a un cojo; a Pablo lo apedrean. Patria de Timoteo. Hechos 14:8-20.",
         "医好瘸腿的人；保罗在这里被石头打。提摩太的家乡。使徒行传14:8-20。"),
        ("Derbe", "特庇", 33.26, 37.35,
         "Punto más lejano del primer viaje; muchos discípulos. Hechos 14:20-21.",
         "第一次旅行最远的地方；收了许多门徒。使徒行传14:20-21。"),
    ]),
    (L("Segundo viaje", "第二次旅行"), [
        ("Troas", "特罗亚", 26.09, 39.75,
         "La visión del varón macedonio: «Pasa a Macedonia». Hechos 16:8-10.",
         "看见马其顿人的异象：“请过到马其顿来”。使徒行传16:8-10。"),
        ("Filipos", "腓立比", 24.28, 41.01,
         "Se convierte Lidia; cárcel y terremoto. Primera iglesia en Europa. Hechos 16.",
         "吕底亚信主；下监与地震。欧洲的第一间教会。使徒行传16章。"),
        ("Tesalónica", "帖撒罗尼迦", 22.94, 40.64,
         "Predican tres sábados; estalla un alboroto. Hechos 17:1-9.",
         "一连三个安息日讲道；城里起了骚乱。使徒行传17:1-9。"),
        ("Berea", "庇哩亚", 22.20, 40.52,
         "Los de Berea examinan las Escrituras cada día. Hechos 17:10-12.",
         "庇哩亚人天天查考圣经。使徒行传17:10-12。"),
        ("Atenas", "雅典", 23.73, 37.98,
         "Discurso en el Areópago sobre el «Dios no conocido». Hechos 17:16-34.",
         "在亚略巴古讲论“未识之神”。使徒行传17:16-34。"),
        ("Corinto", "哥林多", 22.93, 37.94,
         "Pablo se queda año y medio con Aquila y Priscila. Hechos 18:1-11.",
         "保罗与亚居拉、百基拉同住一年半。使徒行传18:1-11。"),
    ]),
    (L("Tercer viaje", "第三次旅行"), [
        ("Éfeso", "以弗所", 27.34, 37.94,
         "Dos años enseñando; el alboroto de los plateros de Diana. Hechos 19.",
         "教导了两年；银匠为亚底米起哄。使徒行传19章。"),
        ("Mileto", "米利都", 27.28, 37.53,
         "Pablo se despide de los ancianos de Éfeso. Hechos 20:17-38.",
         "保罗在这里与以弗所的长老道别。使徒行传20:17-38。"),
        ("Rodas", "罗底", 28.23, 36.43,
         "Escala de la isla rumbo a Jerusalén. Hechos 21:1.",
         "回耶路撒冷途中停靠的海岛。使徒行传21:1。"),
        ("Tiro", "推罗", 35.20, 33.27,
         "Los discípulos le ruegan que no suba a Jerusalén. Hechos 21:3-6.",
         "门徒劝他不要上耶路撒冷。使徒行传21:3-6。"),
        ("Cesarea", "该撒利亚", 34.90, 32.50,
         "Casa de Felipe; luego Pablo estará preso aquí. Hechos 21:8; 23:23-35.",
         "腓利的家；后来保罗在这里被囚。使徒行传21:8；23:23-35。"),
    ]),
    (L("Viaje a Roma", "前往罗马"), [
        ("Sidón", "西顿", 35.38, 33.56,
         "Primera escala del viaje como preso; le tratan con bondad. Hechos 27:3.",
         "作囚犯启程后的第一站；受到善待。使徒行传27:3。"),
        ("Mira (Licia)", "每拉（吕家）", 29.98, 36.25,
         "Cambian a una nave de Alejandría rumbo a Italia. Hechos 27:5-6.",
         "换上一只往意大利去的亚历山大船。使徒行传27:5-6。"),
        ("Buenos Puertos (Creta)", "佳澳（革哩底）", 24.80, 34.90,
         "Pablo avisa del peligro, pero zarpan igualmente. Hechos 27:8-13.",
         "保罗警告有危险，船还是开了。使徒行传27:8-13。"),
        ("Malta", "米利大", 14.40, 35.90,
         "Naufragio; todos se salvan y la víbora no le daña. Hechos 27:39-28:6.",
         "船破了；众人都得救，毒蛇也没有害他。使徒行传27:39-28:6。"),
        ("Siracusa (Sicilia)", "叙拉古（西西里）", 15.29, 37.08,
         "Tres días de escala en Sicilia. Hechos 28:12.",
         "在西西里停留了三天。使徒行传28:12。"),
        ("Regio", "利基翁", 15.65, 38.11,
         "Escala en la punta de Italia. Hechos 28:13.",
         "停靠在意大利的尖端。使徒行传28:13。"),
        ("Puteoli", "部丢利", 14.12, 40.82,
         "Desembarca en Italia; halla hermanos. Hechos 28:13-14.",
         "在意大利上岸；遇见弟兄。使徒行传28:13-14。"),
        ("Roma", "罗马", 12.48, 41.89,
         "Preso pero predicando con libertad en la capital del imperio. Hechos 28:16-31.",
         "虽被囚，却在帝国的京城放胆传道。使徒行传28:16-31。"),
        ("España (Tarsis)", "西班牙（他施）", -5.00, 37.00,
         "El confín que Pablo deseaba alcanzar; lugar de reto. Romanos 15:24.",
         "保罗盼望去到的尽头；挑战地点。罗马书15:24。"),
    ]),
]


def main():
    places = []
    for _, cards in GROUPS:
        for es, zh, lon, lat, *_ in cards:
            x, y = project(lon, lat)
            places.append((es, x, y))
    # Comprobación de colisiones (misma métrica que el juego: dx escalado por aspect).
    problems = []
    for i in range(len(places)):
        for j in range(i + 1, len(places)):
            dx = (places[i][1] - places[j][1]) * ASPECT
            dy = places[i][2] - places[j][2]
            d = math.hypot(dx, dy)
            if d < MIN_DIST:
                problems.append((places[i][0], places[j][0], round(d, 4)))
    if problems:
        for a, b, d in problems:
            print(f"COLISIÓN: {a} ~ {b}  dist={d}", file=sys.stderr)
        sys.exit(1)

    groups_json = []
    for name, cards in GROUPS:
        out_cards = []
        for es, zh, lon, lat, bes, bzh in cards:
            x, y = project(lon, lat)
            out_cards.append({"front": L(es, zh), "back": L(bes, bzh),
                              "x": round(x, 4), "y": round(y, 4)})
        groups_json.append({"name": name, "cards": out_cards})

    total = sum(len(c) for _, c in GROUPS)
    game = {
        "id": "viajes-pablo",
        "icon": "🧭",
        "title": L("Viajes de Pablo", "保罗的旅程"),
        "category": "biblia",
        "minMinutes": 5,
        "maxMinutes": 10,
        "objective": L(
            "Situar en el mapa del Mediterráneo las ciudades de los viajes de Pablo; gana quien ponga el punto más cerca.",
            "在地中海地图上找出保罗旅程中的城市；点得最近的人获胜。"),
        "steps": [
            L("En la lámina aparece un lugar: «Coloca este lugar».", "图上会出现一个地点：“找出这个地点”。"),
            L("Dos jugadores por ronda. El Jugador 1 toca el mapa donde cree que está; luego el Jugador 2.",
              "每轮两位玩家。玩家1点一下自己认为的位置，接着玩家2。"),
            L("Pulsa «Revelar»: una estrella muestra el sitio real y marca quién quedó más cerca.",
              "点“揭晓”：星星显示真实位置，并标出谁离得最近。"),
            L("El punto más cercano gana; en caso de empate ganan los dos.", "最近的人得分；平手则两人都得分。"),
            L("Pulsa «Siguiente lugar» y rota de jugadores.", "点“下一个”，并轮换玩家。"),
        ],
        "tips": [
            L("👉 Empieza por los lugares conocidos (Jerusalén, Antioquía, Roma) y sube la dificultad.",
              "👉 先从熟悉的地点开始（耶路撒冷、安提阿、罗马），再逐渐加难。"),
            L("👉 Al revelar, lee la pista para contar qué pasó allí en los Hechos.",
              "👉 揭晓后，读一读说明，讲讲使徒行传里在那里发生的事。"),
            L("👉 Sigue el orden de los grupos para repasar los cuatro viajes de Pablo.",
              "👉 按分组顺序进行，复习保罗的四次旅程。"),
        ],
        "why": L(
            "Ver los viajes sobre el mapa ayuda a entender cómo el evangelio pasó de Jerusalén a Roma.",
            "在地图上看旅程，有助于理解福音如何从耶路撒冷传到罗马。"),
        "tools": [{
            "kind": "map",
            "title": L("Mapa del Mediterráneo", "地中海地图"),
            "plate": {
                "image": "mapa-mediterraneo.jpg",
                "aspect": 2.0,
                "lonMin": LON_MIN, "lonMax": LON_MAX,
                "latMin": LAT_MIN, "latMax": LAT_MAX,
            },
            "groups": groups_json,
        }],
    }

    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    out = os.path.join(root, "App", "Sources", "JuegosCore", "Resources", "parts", "partG.json")
    with open(out, "w", encoding="utf-8") as f:
        json.dump({"games": [game]}, f, ensure_ascii=False, indent=2)
        f.write("\n")
    print(f"OK: viajes-pablo con {total} lugares en {len(GROUPS)} grupos -> {out}")


if __name__ == "__main__":
    main()
