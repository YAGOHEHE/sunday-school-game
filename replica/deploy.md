# Deploy checklist: Juegos Dominical (macOS)

Fecha: 2026-10-31 · Commit: — (no hay repositorio git) · Versión 0.1.0 (1) · Go del usuario: **todavía no** (solo revisión)

> Adaptado de replica-deploy. Es una app nativa de macOS sin backend, sin cuentas ni pagos, así que no aplican las secciones de base de datos de producción, Stripe, OAuth, email, DNS ni uptime. En su lugar se comprueban firma, notarización, arquitectura, icono y distribución.

## Preflight

| | Comprobación | Resultado |
|---|---|---|
| ✅ | Tests (`swift test`, JuegosCoreTests) | 9 / 9 pasan |
| ✅ | Build de producción (`swift build -c release`, `scripts/make_app.sh`) | compila; 1 warning |
| ✅ | Catálogo `games.json` válido | 23 juegos, 14 retos, ningún texto ES/ZH vacío |
| ✅ | Bugs S1/S2 abiertos | ninguno conocido; los 3 encontrados en la revisión están corregidos |
| ✅ | Privacidad | sin red, sin analítica y sin terceros; los datos se quedan en `~/Library/Application Support/JuegosDominical/userdata.json` |
| ❌ | **Gatekeeper** (`spctl -a`) | **rejected**: firma ad-hoc sin Team ID ni notarización. En otro Mac aparecerá «no se puede abrir» |
| ❌ | **Arquitectura** | **solo arm64**: no arranca en Macs Intel |
| ❌ | **Icono de la app** | no existe (`App/Icon/` vacío): sale el icono genérico |
| ❌ | **Control de versiones** | el proyecto no es un repositorio git: no hay historial ni copia |
| ⚠️ | Argumentos de prueba en release | `--play`, `--projector` y `--touch-save` se compilan también en release, y `--touch-save` modifica los datos (añade «Prueba» a la lista de alumnos). Hay que limitarlos con `#if DEBUG` |
| ⚠️ | Idioma del sistema | Info.plist sin `CFBundleDevelopmentRegion` ni `CFBundleLocalizations`: los menús File/Edit/View/Window salen en inglés |
| ⚠️ | Funciones sin probar en uso real | voz del llamador, sonido del temporizador, exportar PDF de identidades, proyector a pantalla completa en monitor externo, editor de juegos |
| ⚠️ | Cobertura de tests | solo el núcleo; sin tests de AppModel (sesión, overrides) ni de PlayController (`pauseAll`) |
| ⚠️ | Copia de seguridad de datos | no se pueden exportar ni importar sesiones, juegos propios ni alumnos |

**Veredicto:** se puede usar ya en tu propio Mac (Apple Silicon). **No está lista para repartir** a otros profesores hasta resolver los 4 ❌.

## Distribución (elige una)

| Opción | Qué requiere | Pros / contras |
|---|---|---|
| **A. DMG firmado y notarizado** (recomendada) | Cuenta Apple Developer (99 $/año, la crea y paga el usuario), certificado «Developer ID Application», `codesign --options runtime`, `xcrun notarytool submit`, `xcrun stapler staple` | Se abre con doble clic en cualquier Mac. Se puede reutilizar `biblia-app/scripts/make_dmg.sh` |
| B. DMG sin notarizar (gratis) | Nada | Cada profesor tiene que hacer clic derecho → Abrir, o ejecutar `xattr -dr com.apple.quarantine`. Poco amigable |
| C. Mac App Store | Cuenta Developer, App Sandbox con entitlement `user-selected.read-write` para exportar PDF, ficha de la tienda, etiqueta de privacidad «Data Not Collected» y revisión de Apple | Actualizaciones automáticas. Más trabajo; tiene sentido junto con la versión de iPad |

Pasos que hace el usuario: crear y pagar la cuenta Developer, generar el certificado y crear una app-specific password para `notarytool`. Claude no introduce contraseñas ni datos de pago.

## Vigilancia la primera semana

- Informes de fallos: en macOS los crashes llegan a Consola / `~/Library/Logs/DiagnosticReports`; con App Store, a Xcode Organizer. No hace falta Sentry.
- Probar el flujo completo en clase: crear sesión → Empezar → cada juego con proyector → historial.
- Anotar qué herramientas no se usan o confunden a los alumnos.

## Mejoras priorizadas

**P0, antes de compartir**
1. Binario universal (x86_64 + arm64) en `make_app.sh`.
2. Icono propio (`App/Icon/Juegos.icns`); se puede generar como en `biblia-app/scripts/make_icon.swift`.
3. `git init` y primer commit.
4. Argumentos de prueba solo en `#if DEBUG`.
5. Elegir distribución (A/B/C) y añadir `scripts/make_dmg.sh`.

**P1, calidad**
6. `CFBundleDevelopmentRegion = es` y `CFBundleLocalizations = [es, zh-Hans]` para los menús del sistema.
7. Prueba manual de lo no probado (voz, sonido, PDF, proyector externo, editor).
8. Exportar e importar datos (JSON) desde el menú, como copia de seguridad y paso previo a sincronizar con el iPad.
9. Tests de AppModel y PlayController.

**P2, producto**
10. Reloj de la clase: minutos restantes de la sesión entera durante el modo juego.
11. Historial con lo que se jugó de verdad (duración real, notas tras la clase y valoración del juego).
12. Importar nuevas fichas .md desde la carpeta de iCloud `02_课堂游戏`.
13. Versión iPadOS (fase 5 del plan).
