import Foundation

// CONTRATO COMPARTIDO (Opus): plantillas del modo juego. Ver diseno/02, 10–31, 40, 41.

/// Disposición base del modo juego.
public enum PlayLayout: String, Codable, CaseIterable, Sendable {
    case palabra   // un elemento enorme en el centro + «otro». Fondo color de categoría.
    case reloj     // reglas a un lado, reloj grande al otro. Fondo oscuro.
    case tarjeta   // texto largo con cara oculta, ES | 中文 en columnas, «Revelar». Fondo blanco.

    public var name: L {
        switch self {
        case .palabra: return L("Palabra", "词语")
        case .reloj: return L("Reloj", "计时")
        case .tarjeta: return L("Tarjeta", "卡片")
        }
    }

    /// Regla automática según la herramienta principal (la primera) del juego.
    public static func automatic(for kind: ToolKind?) -> PlayLayout {
        switch kind {
        case .generator, .caller, .colorFlash, .boom, .codeSequence: return .palabra
        case .timer, .stopwatch: return .reloj
        case .deck, .identity, .reference: return .tarjeta
        case .scoreboard: return .palabra
        case nil: return .tarjeta   // sin herramientas: tarjeta con la ficha
        }
    }
}

public enum TemplateBackground: Codable, Hashable, Sendable {
    case category        // color de la categoría (o de la tarjeta activa en colorFlash)
    case dark
    case light
    case custom(hex: String)   // "#RRGGBB"
}

public enum SidePanel: Codable, Hashable, Sendable {
    case none
    /// Según las herramientas del juego: marcador si tiene scoreboard, reglas de color si tiene colorFlash; si no, nada.
    case auto
    case steps
    case colorRules
    case tool(ToolKind)
}

public struct PlayTemplate: Codable, Hashable, Identifiable, Sendable {
    public var id: String
    public var name: L
    public var base: PlayLayout
    public var background: TemplateBackground
    /// nil = herramienta principal del juego.
    public var mainTool: ToolKind?
    public var sidePanel: SidePanel
    public var sidePanelLeading: Bool
    /// true = ES y 中文 en dos columnas; false = apilado.
    public var bilingualColumns: Bool
    public var showReveal: Bool
    /// Botones Sí / No / No tiene relación (solo tienen efecto con un mazo).
    public var showAnswerButtons: Bool
    public var showSteps: Bool

    public init(id: String, name: L, base: PlayLayout, background: TemplateBackground, mainTool: ToolKind? = nil,
                sidePanel: SidePanel = .none, sidePanelLeading: Bool = false, bilingualColumns: Bool = false,
                showReveal: Bool = false, showAnswerButtons: Bool = false, showSteps: Bool = false) {
        self.id = id; self.name = name; self.base = base; self.background = background; self.mainTool = mainTool
        self.sidePanel = sidePanel; self.sidePanelLeading = sidePanelLeading; self.bilingualColumns = bilingualColumns
        self.showReveal = showReveal; self.showAnswerButtons = showAnswerButtons; self.showSteps = showSteps
    }

    public var isBuiltin: Bool { PlayTemplate.builtins.contains { $0.id == id } }

    // Integradas (mockups 10–31). No se guardan en disco ni se editan.
    public static let palabra = PlayTemplate(
        id: "palabra", name: PlayLayout.palabra.name, base: .palabra, background: .category,
        sidePanel: .auto, sidePanelLeading: false, bilingualColumns: false)
    public static let reloj = PlayTemplate(
        id: "reloj", name: PlayLayout.reloj.name, base: .reloj, background: .dark,
        sidePanel: .steps, sidePanelLeading: true, bilingualColumns: false, showSteps: true)
    public static let tarjeta = PlayTemplate(
        id: "tarjeta", name: PlayLayout.tarjeta.name, base: .tarjeta, background: .light,
        sidePanel: .none, sidePanelLeading: false, bilingualColumns: true, showReveal: true, showAnswerButtons: true)

    public static let builtins: [PlayTemplate] = [.palabra, .reloj, .tarjeta]

    public static func builtin(for layout: PlayLayout) -> PlayTemplate {
        switch layout { case .palabra: return .palabra; case .reloj: return .reloj; case .tarjeta: return .tarjeta }
    }

    /// Herramientas que la plantilla necesita y que el juego debería tener (para avisar en el editor).
    public var requiredTools: [ToolKind] {
        var r: [ToolKind] = []
        if let m = mainTool { r.append(m) }
        switch sidePanel {
        case .tool(let k): if !r.contains(k) { r.append(k) }
        case .colorRules: if !r.contains(.colorFlash) { r.append(.colorFlash) }
        default: break
        }
        return r
    }
}

/// Plantilla efectiva de un juego: game.template (propia o integrada con ese id); si es nil o no existe → regla automática.
public func resolveTemplate(for game: Game, custom: [PlayTemplate]) -> PlayTemplate {
    if let id = game.template {
        if let t = custom.first(where: { $0.id == id }) { return t }
        if let t = PlayTemplate.builtins.first(where: { $0.id == id }) { return t }
    }
    return PlayTemplate.builtin(for: PlayLayout.automatic(for: game.primaryToolIndex.map { game.tools[$0].kind }))
}

public extension Game {
    /// Herramienta principal: la primera que no sea de apoyo (temporizador, cronómetro, marcador);
    /// si todas son de apoyo, la primera. Reproduce el mapa diseno/02 (Palabra 14 · Reloj 4 · Tarjeta 5).
    var primaryToolIndex: Int? {
        let support: Set<ToolKind> = [.timer, .stopwatch, .scoreboard]
        return tools.firstIndex { !support.contains($0.kind) } ?? (tools.isEmpty ? nil : 0)
    }

    /// Herramienta que ocupa la zona central con esta plantilla (nil = ninguna: se muestra la ficha).
    func mainToolIndex(for template: PlayTemplate) -> Int? {
        if let k = template.mainTool, let i = tools.firstIndex(where: { $0.kind == k }) { return i }
        return primaryToolIndex
    }
}
