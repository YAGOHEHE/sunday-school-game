import Foundation

// CONTRATO COMPARTIDO (Opus). No cambiar nombres/campos sin coordinar: games.json, JuegosUI y los tests dependen de esto.

/// Texto bilingüe. `zh` en chino simplificado.
public struct L: Codable, Hashable, Sendable {
    public var es: String
    public var zh: String
    public init(es: String, zh: String) { self.es = es; self.zh = zh }
    public init(_ es: String, _ zh: String) { self.es = es; self.zh = zh }

    public func text(_ mode: LanguageMode) -> String {
        switch mode {
        case .es: return es.isEmpty ? zh : es
        case .zh: return zh.isEmpty ? es : zh
        case .both:
            if es.isEmpty { return zh }
            if zh.isEmpty || zh == es { return es }
            return "\(es)\n\(zh)"
        }
    }
}

public enum LanguageMode: String, Codable, CaseIterable, Sendable { case es, zh, both }

public enum GameCategory: String, Codable, CaseIterable, Sendable {
    case energia      // ⚡ moverse, subir energía
    case mente        // 🧠 lógica, atención, reflejos
    case equipo       // 🤝 cooperación, contacto
    case expresion    // 🎭 mímica, actuación, desinhibición
    case conocerse    // 💬 conocerse, socializar
    case biblia       // 📖 juegos bíblicos / reflexión

    public var emoji: String {
        switch self {
        case .energia: return "⚡"
        case .mente: return "🧠"
        case .equipo: return "🤝"
        case .expresion: return "🎭"
        case .conocerse: return "💬"
        case .biblia: return "📖"
        }
    }
    public var name: L {
        switch self {
        case .energia: return L("Energía", "活力")
        case .mente: return L("Mente", "动脑")
        case .equipo: return L("Equipo", "团队")
        case .expresion: return L("Expresión", "表演")
        case .conocerse: return L("Conocerse", "认识彼此")
        case .biblia: return L("Biblia", "圣经")
        }
    }
}

public struct Card: Codable, Hashable, Sendable {
    public var front: L
    /// Respuesta / acción / guía (opcional según la herramienta).
    public var back: L?
    /// Solo para `colorFlash`: "red" | "yellow" | "blue" | "green" | "purple" | "orange".
    public var color: String?
    public init(front: L, back: L? = nil, color: String? = nil) {
        self.front = front; self.back = back; self.color = color
    }
}

public struct CardGroup: Codable, Hashable, Sendable {
    public var name: L
    public var cards: [Card]
    public init(name: L, cards: [Card]) { self.name = name; self.cards = cards }
}

public enum ToolKind: String, Codable, CaseIterable, Sendable {
    case timer          // cuenta atrás. `seconds`
    case stopwatch      // cronómetro con vueltas
    case scoreboard     // marcador. `teams`
    case deck           // mazo: muestra front, botón revela back. `groups`
    case generator      // aleatorio grande por categoría (sin repetir). `groups`
    case reference      // tabla/rejilla fija para consultar. `groups`
    case boom           // contador ¡Boom!. `multiple`
    case caller         // llamador de órdenes (front = orden, back = acción correcta), voz opcional. `groups`
    case colorFlash     // tarjeta de color a pantalla completa (cards con `color`, back = regla). `groups`
    case identity       // tarjetas de identidad (front = rol, back = cómo tratarle), imprimibles. `groups`
    case codeSequence   // genera secuencias de señales (捏/拍/压). `length`
}

public struct ToolSpec: Codable, Hashable, Sendable {
    public var kind: ToolKind
    public var title: L?
    public var seconds: Int?
    public var teams: Int?
    public var multiple: Int?
    public var length: Int?
    public var groups: [CardGroup]?
    public init(kind: ToolKind, title: L? = nil, seconds: Int? = nil, teams: Int? = nil,
                multiple: Int? = nil, length: Int? = nil, groups: [CardGroup]? = nil) {
        self.kind = kind; self.title = title; self.seconds = seconds; self.teams = teams
        self.multiple = multiple; self.length = length; self.groups = groups
    }
}

public struct Variant: Codable, Hashable, Sendable {
    public var title: L
    public var objective: L?
    public var steps: [L]
    public var tips: [L]
    public init(title: L, objective: L? = nil, steps: [L] = [], tips: [L] = []) {
        self.title = title; self.objective = objective; self.steps = steps; self.tips = tips
    }
    private enum CodingKeys: String, CodingKey { case title, objective, steps, tips }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        title = try c.decode(L.self, forKey: .title)
        objective = try c.decodeIfPresent(L.self, forKey: .objective)
        steps = try c.decodeIfPresent([L].self, forKey: .steps) ?? []
        tips = try c.decodeIfPresent([L].self, forKey: .tips) ?? []
    }
}

public struct Game: Codable, Hashable, Identifiable, Sendable {
    public var id: String
    public var icon: String
    public var title: L
    public var category: GameCategory
    public var minMinutes: Int
    public var maxMinutes: Int
    public var objective: L
    public var steps: [L]
    public var tips: [L]
    public var why: L?
    public var variants: [Variant]
    public var tools: [ToolSpec]
    /// id de plantilla del modo juego (integrada o propia). nil = automática según la herramienta principal.
    public var template: String?

    public init(id: String, icon: String, title: L, category: GameCategory, minMinutes: Int, maxMinutes: Int,
                objective: L, steps: [L], tips: [L] = [], why: L? = nil, variants: [Variant] = [], tools: [ToolSpec] = [], template: String? = nil) {
        self.id = id; self.icon = icon; self.title = title; self.category = category
        self.minMinutes = minMinutes; self.maxMinutes = maxMinutes; self.objective = objective
        self.steps = steps; self.tips = tips; self.why = why; self.variants = variants; self.tools = tools
        self.template = template
    }

    private enum CodingKeys: String, CodingKey {
        case id, icon, title, category, minMinutes, maxMinutes, objective, steps, tips, why, variants, tools, template
    }

    /// Tolerante: steps/tips/variants/tools ausentes = [].
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        icon = try c.decode(String.self, forKey: .icon)
        title = try c.decode(L.self, forKey: .title)
        category = try c.decode(GameCategory.self, forKey: .category)
        minMinutes = try c.decode(Int.self, forKey: .minMinutes)
        maxMinutes = try c.decode(Int.self, forKey: .maxMinutes)
        objective = try c.decode(L.self, forKey: .objective)
        steps = try c.decodeIfPresent([L].self, forKey: .steps) ?? []
        tips = try c.decodeIfPresent([L].self, forKey: .tips) ?? []
        why = try c.decodeIfPresent(L.self, forKey: .why)
        variants = try c.decodeIfPresent([Variant].self, forKey: .variants) ?? []
        tools = try c.decodeIfPresent([ToolSpec].self, forKey: .tools) ?? []
        template = try c.decodeIfPresent(String.self, forKey: .template)
    }

    /// Minutos sugeridos al añadir a una sesión.
    public var suggestedMinutes: Int { (minMinutes + maxMinutes + 1) / 2 }
}

/// Raíz de games.json.
public struct CatalogFile: Codable, Sendable {
    public var version: Int
    /// Retos globales (botón 🎲 Reto en cualquier juego).
    public var challenges: [L]
    public var games: [Game]
    public init(version: Int, challenges: [L], games: [Game]) {
        self.version = version; self.challenges = challenges; self.games = games
    }
}

// MARK: - Datos del usuario

public struct SessionItem: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var gameID: String
    public var minutes: Int
    public init(id: UUID = UUID(), gameID: String, minutes: Int) {
        self.id = id; self.gameID = gameID; self.minutes = minutes
    }
}

public struct Session: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var date: Date
    public var title: String
    public var availableMinutes: Int
    public var items: [SessionItem]
    public var notes: String
    public init(id: UUID = UUID(), date: Date = Date(), title: String = "", availableMinutes: Int = 30,
                items: [SessionItem] = [], notes: String = "") {
        self.id = id; self.date = date; self.title = title; self.availableMinutes = availableMinutes
        self.items = items; self.notes = notes
    }
    public var totalMinutes: Int { items.reduce(0) { $0 + $1.minutes } }
}

public struct UserData: Codable, Sendable {
    public var version: Int = 1
    /// Juegos creados por el usuario o versiones editadas de juegos del catálogo (mismo id = sustituye).
    public var customGames: [Game] = []
    /// ids de juegos del catálogo ocultados por el usuario.
    public var hiddenGameIDs: [String] = []
    public var favoriteIDs: [String] = []
    public var currentSession: Session = Session()
    public var history: [Session] = []
    /// Lista de alumnos para el sorteo.
    public var roster: [String] = []
    public var language: LanguageMode = .both
    /// Plantillas de modo juego creadas por el usuario (las integradas no se guardan).
    public var templates: [PlayTemplate] = []
    public init() {}

    private enum CodingKeys: String, CodingKey {
        case version, customGames, hiddenGameIDs, favoriteIDs, currentSession, history, roster, language, templates
    }

    /// Tolerante: cualquier clave ausente toma su valor por defecto (userdata.json antiguos siguen cargando).
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = UserData()
        version = try c.decodeIfPresent(Int.self, forKey: .version) ?? d.version
        customGames = try c.decodeIfPresent([Game].self, forKey: .customGames) ?? d.customGames
        hiddenGameIDs = try c.decodeIfPresent([String].self, forKey: .hiddenGameIDs) ?? d.hiddenGameIDs
        favoriteIDs = try c.decodeIfPresent([String].self, forKey: .favoriteIDs) ?? d.favoriteIDs
        currentSession = try c.decodeIfPresent(Session.self, forKey: .currentSession) ?? d.currentSession
        history = try c.decodeIfPresent([Session].self, forKey: .history) ?? d.history
        roster = try c.decodeIfPresent([String].self, forKey: .roster) ?? d.roster
        language = try c.decodeIfPresent(LanguageMode.self, forKey: .language) ?? d.language
        templates = try c.decodeIfPresent([PlayTemplate].self, forKey: .templates) ?? d.templates
    }
}
