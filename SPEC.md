# Juegos Dominical — Especificación (contrato para los agentes)

App macOS 14+ (luego iPadOS 17) en SwiftUI para recopilar, planificar y **jugar** los juegos de la escuela dominical. Bilingüe ES / 中文 (simplificado). Público: adolescentes de una escuela dominical china en España.

Plan completo: `/Users/jiaheqiu/.claude/plans/federated-prancing-pine.md`.
Contrato de datos: `App/Sources/JuegosCore/Models.swift` (NO cambiar sin coordinar).
Fuente original (solo lectura, NO modificar): `/Users/jiaheqiu/Library/Mobile Documents/com~apple~CloudDocs/主日学/2025:26/02_课堂游戏/*.md`

## Propiedad de carpetas (para trabajar en paralelo sin pisarse)
| Agente | Posee |
|---|---|
| Contenido (Haiku) | `App/Sources/JuegosCore/Resources/parts/*.json` → fusionado en `games.json` |
| Core (Sonnet) | `App/Sources/JuegosCore/*.swift` excepto `Models.swift`, `Templates.swift`, `App/Tests/`, `scripts/`, `README.md` |
| Contrato (Opus) | `App/Sources/JuegosCore/Models.swift`, `App/Sources/JuegosCore/Templates.swift` |
| Tests/SPEC (Haiku) | `App/Tests/JuegosCoreTests/`, `SPEC.md` |
| UI (Sonnet) | `App/Sources/JuegosUI/`, `App/Sources/JuegosMac/` |

## games.json
Raíz = `CatalogFile` (`version: 1`, `challenges: [L]`, `games: [Game]`). `L` = `{"es": "...", "zh": "..."}`. Ambos idiomas siempre rellenos.
Campos opcionales ausentes = omitir la clave (no `null`). Evitar comillas ASCII `"` dentro de textos: usar « » o “ ”.

### Catálogo (23 juegos) — id · icono · categoría · min–max · herramientas
| id | ficha original | icono | cat | min | tools |
|---|---|---|---|---|---|
| quien-viene-detras | "Conexión de neuronas".md («¿Quién viene detrás?», 2 variantes, banco de 110 preguntas en 11 categorías) | 🚪 | conocerse | 15–20 | timer 300 (conversación); deck: 11 grupos = categorías del banco (solo front) |
| letras-humanas | 人体字母数字 | 🔤 | equipo | 5–8 | timer 30; generator grupos: Letras (A–Z selección), Números (0–9), Palabras (OK, SOS, AMOR, PAZ, FE, LUZ, DIOS…), 汉字 (人, 大, 十, 王, 口, 木, 爱?(difícil)…); scoreboard teams 3 |
| pulso-electrico | 传递脉冲 | 💓 | mente | 5 | stopwatch |
| historias-de-lado | 情境推理型 海龟汤 | 🐢 | mente | 10 | deck: front = historia, back = verdad. Las 3 originales (en la del ascensor usar «es un niño / 小孩», no 侏儒) + Monopoly (hombre empuja su coche hasta un hotel y dice que está arruinado) + Romeo y Julieta peces |
| trampas-mentales | 经典陷阱型 | 🪤 | mente | 10 | deck: front = pregunta, back = respuesta correcta (+ trampa). Las 5 originales + «¿Cuántos animales de cada especie llevó Moisés en el arca? → Ninguno, fue Noé» + «17 ovejas, mueren todas menos 9 → quedan 9» + «¿Qué pesa más, un kilo de hierro o uno de plumas? → igual» |
| nudo-humano | 解手链 | 🪢 | equipo | 8–10 | timer 600 |
| evolucion | 进化 | 🐣 | energia | 5–8 | reference: 1 grupo «Etapas» Huevo→Pollito→Fénix→Humano (front = etapa, back = postura/regla); timer 300 |
| mimica | “Batalla de mímica por equipos” | 🙊 | expresion | 8–10 | timer 30; generator grupos Profesiones, Deportes, Animales, Películas conocidas, Historias bíblicas (≥10 c/u); scoreboard teams 2 |
| cambia-de-sitio | “Cambia de sitio si…” | 🔄 | energia | 5–8 | generator 1 grupo «Cambia de sitio si…» (≥20 frases) |
| camara-lenta | “Cámara lenta” | 🎬 | expresion | 5 | generator grupo Acciones (≥20); timer 60 |
| asesino | “El asesino” | 😉 | mente | 7–10 | timer 600 |
| palabra-prohibida | “Palabra prohibida” | 🤐 | mente | 5–8 | timer 300; generator grupo «Preguntas trampa» (≥20 preguntas que invitan a decir sí/no) |
| ppt-cadena | “Piedra, papel, tijera en cadena” | ✊ | energia | 5 | timer 300 |
| reto-absurdo | “Reto absurdo” | 🤪 | expresion | 5 | generator 1 grupo «Retos» (= los mismos de `challenges`) |
| sillas-invisibles | “Sillas invisibles” | 🪑 | energia | 3–5 | caller: ¡SILLA! (sentarse en el aire), ¡MESA! (tocar el suelo), ¡CIELO! (brazos arriba) + 3 más inventadas (¡ESTATUA!, ¡ROCA!…) |
| boom | “¡Boom!” | 💥 | mente | 5 | boom multiple 7 |
| maquina-codigo | 人类密码机 | 📟 | equipo | 7 | codeSequence length 4; timer 420 |
| ser-vivo | 共生物体 | 👾 | equipo | 8–10 | generator grupo Tareas (≥10); timer 120 |
| cadena-emocional | 情绪传染链 | 😱 | expresion | 6 | generator grupo Emociones (≥15) |
| tiempo-inverso | 时间倒流 | ⏪ | energia | 5 | caller: las 31 filas de las 3 tablas (front = orden «¡Adelante!» es / «向前走!» zh; back = acción opuesta). Completar «¡Perdimos todo!» → «Celebrar como si hubierais ganado». Añadir «¡Tiempo inverso!» → caminar hacia atrás como un vídeo rebobinado |
| tormenta | 禁语风暴 | 🌪️ | mente | 5–8 | colorFlash 1 grupo: red=cantarlo, yellow=decirlo en otro idioma/dialecto, blue=silencio, solo mímica; generator grupo Categorías (≥15) |
| agencia-detectives | 谎言侦探局 | 🕵️ | mente | 10 | generator grupos «Escenas» y «Detalles absurdos» (≥10 c/u); timer 300. REGLA CORREGIDA: si los detectives descubren el detalle absurdo, ganan los detectives; si se acaba el tiempo sin descubrirlo, gana el guionista. Título ES: «La Agencia de Detectives» |
| bolsa-identidad | 身份交换所 | 🪪 | conocerse | 6 | identity 1 grupo con los 30 roles (front = rol, back = guía); timer 300 |

`challenges` (global): hablar como robot 10 s, cantar una canción infantil, imitar a un profesor (con respeto), 5 flexiones, 5 saltos, decir tu comida favorita, decir una serie que te guste, bailar 10 s, caminar como pingüino, decir un trabalenguas, contar un chiste, recitar un versículo de memoria, hablar como un bebé 10 s, poner la cara más seria 10 s sin reírse… (≥14).

Contenido: fiel a las fichas (objetivo, pasos, tips «👉 Puedes añadir», «Por qué funciona» → `why`, variantes). Traducir lo que falte. Quitar numeración «1.» «6.» de los títulos. Títulos: ES = nombre español; ZH = nombre chino (para los que no lo tienen, traducir: p. ej. 「数七 ¡Boom!」→ zh «数七»).

### Plantillas del modo juego
Contrato en `App/Sources/JuegosCore/Templates.swift` (Opus). Diseño: `diseno/02-Mapa-Plantillas.html` (mapa 14/4/5) y mockups 10–31, 40–41.

- **`PlayLayout`** (disposición base): `palabra` (elemento enorme al centro + «otro», fondo de color de categoría), `reloj` (reloj grande + reglas a un lado, fondo oscuro), `tarjeta` (texto con cara oculta, ES | 中文 en columnas, «Revelar», fondo blanco). `PlayLayout.automatic(for: ToolKind?)` da la regla automática: `generator`, `caller`, `colorFlash`, `boom`, `codeSequence` y `scoreboard` → `palabra`; `timer`, `stopwatch` → `reloj`; `deck`, `identity`, `reference` y sin herramientas → `tarjeta`.
- **`TemplateBackground`**: `category` (color de categoría o de la tarjeta activa en colorFlash), `dark`, `light`, `custom(hex: "#RRGGBB")`.
- **`SidePanel`**: `none`; `auto` (según las herramientas del juego: marcador si tiene `scoreboard`, reglas de color si tiene `colorFlash`; si no, nada); `steps` (pasos del juego); `colorRules` (reglas de color, requiere `colorFlash`); `tool(ToolKind)` (herramienta fija en el panel).
- **`PlayTemplate`** (`Identifiable`, `Codable`): `id`, `name: L`, `base: PlayLayout`, `background: TemplateBackground`, `mainTool: ToolKind?` (nil = herramienta principal del juego), `sidePanel: SidePanel`, `sidePanelLeading: Bool` (panel a la izquierda), `bilingualColumns: Bool` (ES y 中文 en dos columnas), `showReveal: Bool`, `showAnswerButtons: Bool` (Sí / No / No tiene relación; solo con mazo), `showSteps: Bool`. Propiedades: `isBuiltin` (id de una integrada) y `requiredTools` (`mainTool` + herramienta del `sidePanel`, sin duplicados; sirve para avisar en el editor).
- **Integradas** (no se guardan en disco ni se editan; ids fijos):
  - `palabra`: base `palabra`, fondo `category`, panel `auto`, panel a la derecha, sin columnas bilingües.
  - `reloj`: base `reloj`, fondo `dark`, panel `steps` a la izquierda, `showSteps = true`.
  - `tarjeta`: base `tarjeta`, fondo `light`, sin panel, `bilingualColumns = true`, `showReveal = true`, `showAnswerButtons = true`.
- **`Game.template: String?`**: id de plantilla (integrada o propia). Si es `nil` se omite al codificar (no se escribe `null`). Si el id no existe, se usa la regla automática.
- **`UserData.templates: [PlayTemplate]`**: solo plantillas propias; las integradas no se guardan.
- **`UserData` decode tolerante**: cada clave ausente toma su valor por defecto (incluida `templates`), así que `userdata.json` antiguos siguen cargando y `{}` es válido.
- **`resolveTemplate(for: Game, custom: [PlayTemplate]) -> PlayTemplate`**: busca `game.template` primero en `custom` (por id), luego en las integradas; si no encuentra nada o `template` es nil, aplica la regla automática sobre la herramienta principal.
- **Herramienta principal** (`Game.primaryToolIndex`): la primera herramienta que no sea `timer`, `stopwatch` ni `scoreboard`; si todas son de apoyo, la primera; si no tiene herramientas, `nil`. Con esta regla el catálogo sale 14 palabra · 4 reloj · 5 tarjeta.
- **Herramienta del área central** (`Game.mainToolIndex(for:)`): la del índice de `template.mainTool` si el juego la tiene; si no, `primaryToolIndex`.

## UI (resumen; detalle en el plan)
NavigationSplitView: Biblioteca (sidebar, filtros categoría/duración/favoritos, búsqueda en ambos idiomas) · Sesión del día (drag&drop desde la biblioteca, reordenar, minutos por juego, barra total/disponible, ▶ Empezar sesión, historial con «repetir») · Ficha (detalle + Jugar). Modo juego a pantalla completa con pestañas de herramientas, temporizador visible, botones globales 🎲 Reto y 🎯 Sorteo (roster), ▶ Siguiente juego en sesión. Ventana de proyector (macOS) que espeja el modo juego sin controles. Editor de juegos. Selector ES / 中文 / ES+中文. Imprimir/exportar PDF de tarjetas de identidad.
