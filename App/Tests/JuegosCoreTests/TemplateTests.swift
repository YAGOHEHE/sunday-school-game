import XCTest
@testable import JuegosCore

final class TemplateTests: XCTestCase {
    private func game(_ id: String, tools: [ToolKind], template: String? = nil) -> Game {
        Game(id: id, icon: "🎲", title: L("Juego", "游戏"), category: .mente, minMinutes: 5, maxMinutes: 10,
             objective: L("Objetivo", "目标"), steps: [], tools: tools.map { ToolSpec(kind: $0) }, template: template)
    }

    private func template(_ id: String, base: PlayLayout = .palabra, mainTool: ToolKind? = nil,
                          sidePanel: SidePanel = .none) -> PlayTemplate {
        PlayTemplate(id: id, name: L("Propia", "自定义"), base: base, background: .light,
                     mainTool: mainTool, sidePanel: sidePanel)
    }

    // MARK: - Mapa de plantillas del catálogo empaquetado (diseno/02: Palabra 21 · Reloj 11 · Tarjeta 7; ampliación 2026-10-31)

    private let expected: [(id: String, template: String)] = [
        ("letras-humanas", "palabra"), ("mimica", "palabra"), ("cambia-de-sitio", "palabra"),
        ("camara-lenta", "palabra"), ("palabra-prohibida", "palabra"), ("reto-absurdo", "palabra"),
        ("sillas-invisibles", "palabra"), ("boom", "palabra"), ("maquina-codigo", "palabra"),
        ("ser-vivo", "palabra"), ("cadena-emocional", "palabra"), ("tiempo-inverso", "palabra"),
        ("tormenta", "palabra"), ("agencia-detectives", "palabra"),
        ("pulso-electrico", "reloj"), ("nudo-humano", "reloj"), ("asesino", "reloj"), ("ppt-cadena", "reloj"),
        ("quien-viene-detras", "tarjeta"), ("historias-de-lado", "tarjeta"), ("trampas-mentales", "tarjeta"),
        ("evolucion", "tarjeta"), ("bolsa-identidad", "tarjeta"),
        // Ampliación 2026-10-31
        ("zip-zap-zop", "reloj"), ("caras-serias", "reloj"), ("gigantes-magos-elfos", "tarjeta"),
        ("contar-hasta-20", "reloj"), ("pasa-la-palmada", "reloj"), ("nos-vamos-de-viaje", "palabra"),
        ("dos-verdades-mentira", "reloj"), ("quien-soy-biblico", "palabra"),
        ("verdadero-falso-biblico", "tarjeta"), ("telefono-versiculo", "palabra"),
        ("abecedario-biblico", "palabra"), ("rap-versiculo", "palabra"), ("fila-en-silencio", "palabra"),
        ("historia-palabra", "palabra"), ("submarino", "reloj"), ("isla-desierta", "reloj"),
    ]

    func testBundledCatalogMapsToExpectedTemplates() throws {
        let catalog = try Catalog.loadBundled()
        XCTAssertEqual(catalog.games.count, 39)

        let expectedIDs = expected.map(\.id)
        XCTAssertEqual(expectedIDs.count, 39)
        XCTAssertEqual(Set(expectedIDs).count, expectedIDs.count, "la tabla esperada tiene ids repetidos")
        XCTAssertEqual(Set(expectedIDs), Set(catalog.games.map(\.id)), "la tabla no cubre exactamente el catálogo")

        let byID = Dictionary(uniqueKeysWithValues: catalog.games.map { ($0.id, $0) })
        for (id, tpl) in expected {
            guard let g = byID[id] else { XCTFail("falta \(id) en el catálogo"); continue }
            XCTAssertEqual(resolveTemplate(for: g, custom: []).id, tpl, id)
        }

        let counts = Dictionary(grouping: catalog.games, by: { resolveTemplate(for: $0, custom: []).id })
            .mapValues(\.count)
        XCTAssertEqual(counts["palabra"], 21)
        XCTAssertEqual(counts["reloj"], 11)
        XCTAssertEqual(counts["tarjeta"], 7)
    }

    func testBibliaCategoryAndCatalogCategories() throws {
        XCTAssertTrue(GameCategory.allCases.contains(.biblia))
        XCTAssertEqual(GameCategory.allCases.count, 6)
        XCTAssertEqual(GameCategory.biblia.emoji, "📖")
        XCTAssertEqual(GameCategory.biblia.name.es, "Biblia")
        XCTAssertEqual(GameCategory.biblia.name.zh, "圣经")
        let catalog = try Catalog.loadBundled()
        for g in catalog.games { XCTAssertTrue(GameCategory.allCases.contains(g.category), g.id) }
        XCTAssertEqual(catalog.games.filter { $0.category == .biblia }.count, 5)
    }

    // MARK: - resolveTemplate

    func testUnknownTemplateIdFallsBackToAutomatic() {
        XCTAssertEqual(resolveTemplate(for: game("a", tools: [.timer], template: "inexistente"), custom: []).id, "reloj")
        XCTAssertEqual(resolveTemplate(for: game("b", tools: [.deck], template: "inexistente"), custom: []).id, "tarjeta")
    }

    func testBuiltinTemplateIdOverridesAutomatic() {
        // Juego de tarjeta forzado a reloj.
        XCTAssertEqual(resolveTemplate(for: game("a", tools: [.deck], template: "reloj"), custom: []).id, "reloj")
    }

    func testCustomTemplateIsUsed() {
        let tpl = template("tpl-x", base: .palabra, mainTool: .boom)
        let r = resolveTemplate(for: game("a", tools: [.deck], template: "tpl-x"), custom: [tpl])
        XCTAssertEqual(r, tpl)
    }

    func testGameWithoutToolsIsTarjeta() {
        XCTAssertEqual(resolveTemplate(for: game("a", tools: []), custom: []).id, "tarjeta")
        XCTAssertNil(game("a", tools: []).primaryToolIndex)
    }

    // MARK: - mainToolIndex

    func testMainToolIndexUsesTemplateMainToolWhenPresent() {
        let g = game("a", tools: [.timer, .generator, .scoreboard])
        XCTAssertEqual(g.mainToolIndex(for: template("t", mainTool: .scoreboard)), 2)
    }

    func testMainToolIndexFallsBackToPrimaryWhenMissing() {
        let g = game("a", tools: [.timer, .generator, .scoreboard])
        XCTAssertEqual(g.primaryToolIndex, 1)
        XCTAssertEqual(g.mainToolIndex(for: template("t", mainTool: .boom)), 1)
        XCTAssertEqual(g.mainToolIndex(for: template("t", mainTool: nil)), 1)
    }

    // MARK: - requiredTools

    func testRequiredToolsNoDuplicates() {
        XCTAssertEqual(template("a", mainTool: .colorFlash, sidePanel: .colorRules).requiredTools, [.colorFlash])
        XCTAssertEqual(template("b", mainTool: .deck, sidePanel: .colorRules).requiredTools, [.deck, .colorFlash])
        XCTAssertEqual(template("c", mainTool: .deck, sidePanel: .tool(.timer)).requiredTools, [.deck, .timer])
        XCTAssertEqual(template("d", mainTool: .colorFlash, sidePanel: .tool(.colorFlash)).requiredTools, [.colorFlash])
        XCTAssertEqual(template("e", mainTool: nil, sidePanel: .none).requiredTools, [])
    }

    // MARK: - Codable

    func testPlayTemplateRoundtrip() throws {
        let tpl = PlayTemplate(id: "tpl-x", name: L("Mi plantilla", "我的模板"), base: .reloj,
                               background: .custom(hex: "#123456"), mainTool: .stopwatch,
                               sidePanel: .tool(.scoreboard), sidePanelLeading: true, bilingualColumns: true,
                               showReveal: true, showAnswerButtons: true, showSteps: true)
        let data = try JSONEncoder().encode(tpl)
        let back = try JSONDecoder().decode(PlayTemplate.self, from: data)
        XCTAssertEqual(back, tpl)
        XCTAssertEqual(back.background, .custom(hex: "#123456"))
        XCTAssertEqual(back.sidePanel, .tool(.scoreboard))
    }

    func testGameWithoutTemplateOmitsKey() throws {
        let data = try JSONEncoder().encode(game("a", tools: [.timer]))
        let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertNotNil(obj)
        XCTAssertNil(obj?["template"], "template nil debe omitirse, no codificarse como null")
        XCTAssertFalse(String(decoding: data, as: UTF8.self).contains("\"template\""))
    }

    func testGameWithTemplateRoundtrip() throws {
        let g = game("a", tools: [.deck], template: "tpl-x")
        let back = try JSONDecoder().decode(Game.self, from: try JSONEncoder().encode(g))
        XCTAssertEqual(back.template, "tpl-x")
        XCTAssertEqual(back, g)
    }

    // MARK: - UserData tolerante

    func testUserDataDecodesPartialJSON() throws {
        let u = try JSONDecoder().decode(UserData.self, from: Data(#"{"roster":["Ana"],"language":"zh"}"#.utf8))
        XCTAssertEqual(u.roster, ["Ana"])
        XCTAssertEqual(u.language, .zh)
        XCTAssertEqual(u.templates, [])
        XCTAssertEqual(u.history, [])
        XCTAssertEqual(u.customGames, [])
        XCTAssertEqual(u.version, 1)
    }

    func testUserDataDecodesEmptyObject() throws {
        let u = try JSONDecoder().decode(UserData.self, from: Data("{}".utf8))
        XCTAssertEqual(u.roster, [])
        XCTAssertEqual(u.language, .both)
        XCTAssertEqual(u.templates, [])
        XCTAssertEqual(u.history, [])
    }

    func testUserDataTemplatesRoundtripThroughStore() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = UserDataStore(directory: dir)
        var u = UserData()
        u.templates = [
            PlayTemplate(id: "tpl-x", name: L("Mi plantilla", "我的模板"), base: .palabra,
                         background: .custom(hex: "#123456"), sidePanel: .colorRules),
        ]
        try store.save(u)
        let back = store.load()
        XCTAssertEqual(back.templates, u.templates)
    }
}
