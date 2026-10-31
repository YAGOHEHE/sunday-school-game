# Juegos Dominical

App SwiftUI (macOS 14+ / iOS 17) bilingüe ES / 中文 para recopilar, planificar y jugar los juegos de la escuela dominical. Ver `SPEC.md` para el contrato completo.

## Estructura

- `App/Sources/JuegosCore`: modelos, catálogo (`Resources/games.json`), datos de usuario, utilidades (ShuffleBag, Boom, CodeSequence). Sin UI.
- `App/Sources/JuegosUI`: vistas SwiftUI compartidas.
- `App/Sources/JuegosMac`: punto de entrada macOS.
- `App/Tests/JuegosCoreTests`: tests XCTest del núcleo.
- `scripts/`: `make_app.sh` (ensambla el .app) y `merge_games.py` (fusiona contenido).

## Comandos

```sh
cd App
swift build --target JuegosCore   # compilar el núcleo
swift test                        # tests

scripts/make_app.sh               # genera build/Juegos Dominical.app (firma ad-hoc)
```

## Fusionar contenido

El contenido se escribe en `App/Sources/JuegosCore/Resources/parts/partA.json`, `partB.json`, `partC.json` (los retos globales van en `partC`). Para generar `games.json`:

```sh
python3 -I scripts/merge_games.py
```

Valida ids únicos y que todo texto tenga `es` y `zh` no vacíos; sale con código 1 si hay errores.

## Datos de usuario

Se guardan en `~/Library/Application Support/JuegosDominical/userdata.json`.
# sunday-school-game
