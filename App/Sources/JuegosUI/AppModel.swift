import SwiftUI
import Observation
import JuegosCore

public enum DurationFilter: String, CaseIterable, Identifiable {
    case all, short, medium, long
    public var id: String { rawValue }
    var label: String {
        switch self { case .all: return "∗"; case .short: return "≤5"; case .medium: return "5–10"; case .long: return ">10" }
    }
    func accepts(_ g: Game) -> Bool {
        let m = g.suggestedMinutes
        switch self {
        case .all: return true
        case .short: return m <= 5
        case .medium: return m > 5 && m <= 10
        case .long: return m > 10
        }
    }
}

public struct EditorTarget: Identifiable {
    public let id = UUID()
    public var game: Game
    public var isNew: Bool
}

@MainActor @Observable
public final class AppModel {
    public private(set) var catalog: [Game] = []
    public private(set) var challenges: [L] = []
    public private(set) var games: [Game] = []
    public var loadError: String?

    public var userData: UserData {
        didSet { refreshGames(); scheduleSave() }
    }

    // UI
    public var selectedGameID: String?
    public var query = ""
    public var categoryFilter: GameCategory?
    public var durationFilter: DurationFilter = .all
    public var favoritesOnly = false
    public var editor: EditorTarget?
    public var showTemplates = false
    /// Plantilla que la hoja de plantillas debe seleccionar al abrirse (opcional).
    public var templatesFocusID: String?
    /// Solo pruebas (`--demo-session`): no escribe en disco.
    public var persistenceDisabled = false

    @ObservationIgnored private let store: UserDataStore
    @ObservationIgnored private var saveTask: Task<Void, Never>?

    public init(store: UserDataStore = UserDataStore()) {
        self.store = store
        self.userData = store.load()
        do {
            let file = try Catalog.loadBundled()
            catalog = file.games
            challenges = file.challenges
        } catch {
            loadError = "\(error)"
        }
        refreshGames()
        selectedGameID = games.first?.id
    }

    // MARK: Idioma

    public var language: LanguageMode {
        get { userData.language }
        set { userData.language = newValue }
    }

    public func t(_ es: String, _ zh: String) -> String {
        switch language {
        case .es: return es
        case .zh: return zh
        case .both: return es == zh ? es : "\(es) · \(zh)"
        }
    }

    /// Etiqueta corta: solo ES o solo 中文 (sin duplicar en modo ES+中文). Para controles con poco espacio.
    public func s(_ es: String, _ zh: String) -> String { language == .zh ? zh : es }

    public func text(_ l: L) -> String { l.text(language) }

    // MARK: Juegos

    private func refreshGames() {
        let hidden = Set(userData.hiddenGameIDs)
        games = Catalog.merged(catalog: catalog, user: userData).filter { !hidden.contains($0.id) }
    }

    public func game(_ id: String) -> Game? { games.first { $0.id == id } }

    public var filteredGames: [Game] {
        games.filter { g in
            (query.isEmpty || g.matches(query))
            && (categoryFilter == nil || g.category == categoryFilter)
            && durationFilter.accepts(g)
            && (!favoritesOnly || userData.favoriteIDs.contains(g.id))
        }
    }

    public var selectedGame: Game? { selectedGameID.flatMap(game) }

    public func isFavorite(_ id: String) -> Bool { userData.favoriteIDs.contains(id) }
    public func toggleFavorite(_ id: String) {
        if let i = userData.favoriteIDs.firstIndex(of: id) { userData.favoriteIDs.remove(at: i) }
        else { userData.favoriteIDs.append(id) }
    }

    public func isInCatalog(_ id: String) -> Bool { catalog.contains { $0.id == id } }
    public func isCustom(_ id: String) -> Bool { userData.customGames.contains { $0.id == id } }
    public func isOverride(_ id: String) -> Bool { isCustom(id) && isInCatalog(id) }
    public var hasHidden: Bool { !userData.hiddenGameIDs.isEmpty }

    public func newGame() {
        let g = Game(id: "custom-" + UUID().uuidString.prefix(8).lowercased(), icon: "🎲",
                     title: L("", ""), category: .energia, minMinutes: 5, maxMinutes: 10,
                     objective: L("", ""), steps: [], tips: [], why: nil, variants: [], tools: [])
        editor = EditorTarget(game: g, isNew: true)
    }

    public func edit(_ g: Game) { editor = EditorTarget(game: g, isNew: false) }

    public func saveCustom(_ g: Game) {
        if let i = userData.customGames.firstIndex(where: { $0.id == g.id }) { userData.customGames[i] = g }
        else { userData.customGames.append(g) }
        selectedGameID = g.id
    }

    /// Elimina un juego propio, o restaura el original si era un override del catálogo.
    public func deleteCustom(_ id: String) {
        userData.customGames.removeAll { $0.id == id }
        if !isInCatalog(id) {
            userData.currentSession.items.removeAll { $0.gameID == id }
            userData.favoriteIDs.removeAll { $0 == id }
        }
        if selectedGameID == id, game(id) == nil { selectedGameID = games.first?.id }
    }

    public func hide(_ id: String) {
        if !userData.hiddenGameIDs.contains(id) { userData.hiddenGameIDs.append(id) }
        if selectedGameID == id { selectedGameID = games.first { $0.id != id }?.id }
    }

    public func unhideAll() { userData.hiddenGameIDs = [] }

    // MARK: Plantillas

    public var templates: [PlayTemplate] { userData.templates }
    public var allTemplates: [PlayTemplate] { PlayTemplate.builtins + userData.templates }

    public func template(for game: Game) -> PlayTemplate { resolveTemplate(for: game, custom: userData.templates) }

    public func templateName(_ id: String) -> L? { allTemplates.first { $0.id == id }?.name }

    /// Guarda una plantilla propia (las integradas se ignoran).
    public func saveTemplate(_ t: PlayTemplate) {
        guard !PlayTemplate.builtins.contains(where: { $0.id == t.id }) else { return }
        if let i = userData.templates.firstIndex(where: { $0.id == t.id }) { userData.templates[i] = t }
        else { userData.templates.append(t) }
    }

    /// Copia editable (integrada o propia). La copia queda guardada.
    @discardableResult
    public func duplicate(_ t: PlayTemplate) -> PlayTemplate {
        var c = t
        c.id = "tpl-" + UUID().uuidString.prefix(8).lowercased()
        c.name = L(t.name.es + " (copia)", t.name.zh + " (副本)")
        userData.templates.append(c)
        return c
    }

    /// Juegos (catálogo + propios) que usan esa plantilla de forma explícita o por regla automática.
    public func games(using templateID: String) -> [Game] {
        games.filter { template(for: $0).id == templateID }
    }

    /// Nº de juegos propios con `template == id` (los que pasarán a automática al eliminarla).
    public func customGamesExplicitlyUsing(_ id: String) -> Int {
        games.filter { $0.template == id }.count
    }

    /// Elimina una plantilla propia; los juegos que la usaban pasan a automática. Devuelve cuántos juegos afectó.
    @discardableResult
    public func deleteTemplate(id: String) -> Int {
        guard userData.templates.contains(where: { $0.id == id }) else { return 0 }
        var affected = Set<String>()
        for i in userData.customGames.indices where userData.customGames[i].template == id {
            userData.customGames[i].template = nil
            affected.insert(userData.customGames[i].id)
        }
        // Juegos del catálogo con template == id (poco probable): se guardan como override en automática.
        for g in catalog where g.template == id && !userData.customGames.contains(where: { $0.id == g.id }) {
            var c = g; c.template = nil
            userData.customGames.append(c)
            affected.insert(g.id)
        }
        userData.templates.removeAll { $0.id == id }
        return affected.count
    }

    public func openTemplates(focus id: String? = nil) {
        templatesFocusID = id
        showTemplates = true
    }

    // MARK: Sesión

    public var session: Session {
        get { userData.currentSession }
        set { userData.currentSession = newValue }
    }

    public func addToSession(_ g: Game) {
        userData.currentSession.items.append(SessionItem(gameID: g.id, minutes: g.suggestedMinutes))
    }

    public func addToSession(id: String) { if let g = game(id) { addToSession(g) } }

    public func sessionGames() -> [Game] {
        session.items.compactMap { game($0.gameID) }
    }

    /// Guarda una copia en el historial.
    public func archiveSession() {
        var copy = session
        copy.id = UUID()
        copy.date = Date()
        userData.history.insert(copy, at: 0)
        if userData.history.count > 60 { userData.history.removeLast(userData.history.count - 60) }
    }

    public func repeatSession(_ s: Session) { userData.currentSession = s.repeated() }

    public func deleteHistory(_ id: UUID) { userData.history.removeAll { $0.id == id } }

    // MARK: Roster

    public func addStudent(_ name: String) {
        let n = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !n.isEmpty, !userData.roster.contains(n) else { return }
        userData.roster.append(n)
    }
    public func removeStudent(_ name: String) { userData.roster.removeAll { $0 == name } }

    // MARK: Guardado

    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 600_000_000)
            guard !Task.isCancelled else { return }
            self?.saveNow()
        }
    }

    public func saveNow() {
        guard !persistenceDisabled else { return }
        do { try store.save(userData) } catch { loadError = "No se pudo guardar: \(error)" }
    }
}
