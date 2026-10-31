import SwiftUI
import Observation
import JuegosCore

/// Estado compartido del modo juego. La ventana principal y la de proyector observan el mismo objeto.
@MainActor @Observable
public final class PlayController {
    public var game: Game?
    public var queue: [Game] = []
    public var queueIndex = 0
    /// -1 = ficha del juego; -2 = herramienta central de la plantilla (por defecto).
    public var toolIndex = -2

    /// Respuesta del profe en un mazo (Sí / No / Sin relación), espejada en el proyector.
    var answer: AnswerChoice?
    var answerTick = -1
    /// El proyector deja de mostrar el rol de «Bolsa de identidad».
    public var identityHidden = false

    public var challenge: L?
    public var showChallenge = false

    public var showDraw = false
    public var drawName: String?
    public var drawSpinning = false
    public var eliminated: Set<String> = []

    let clock = TimerState(seconds: 300)

    @ObservationIgnored private var stateStore: [String: AnyObject] = [:]
    @ObservationIgnored private var challengeBag = ShuffleBag<L>([])
    @ObservationIgnored private var challengeSource: [L] = []
    @ObservationIgnored private var spinTask: Task<Void, Never>?

    public init() {}

    public var isActive: Bool { game != nil }
    public var sessionPosition: (Int, Int)? { queue.count > 1 ? (queueIndex + 1, queue.count) : nil }
    public var canNext: Bool { queueIndex + 1 < queue.count }
    public var canPrevious: Bool { queueIndex > 0 }

    // MARK: Ciclo

    public func play(_ g: Game) { begin(queue: [g], index: 0) }

    public func startSession(model: AppModel) {
        let games = model.sessionGames()
        guard !games.isEmpty else { return }
        model.archiveSession()
        begin(queue: games, index: 0)
    }

    private func begin(queue: [Game], index: Int) {
        self.queue = queue
        queueIndex = index
        stateStore = [:]
        eliminated = []
        enter(queue[index])
    }

    private func enter(_ g: Game) {
        game = g
        toolIndex = -2
        answer = nil; answerTick = -1; identityHidden = false
        showChallenge = false
        showDraw = false
    }

    public func next() { if canNext { pauseAll(); queueIndex += 1; enter(queue[queueIndex]) } }
    public func previous() { if canPrevious { pauseAll(); queueIndex -= 1; enter(queue[queueIndex]) } }

    /// Detiene temporizadores, cronómetros, llamadas automáticas y voz del juego que se deja.
    private func pauseAll() {
        for case let s as CardBagState in stateStore.values { s.setAuto(false) }
        for case let s as TimerState in stateStore.values { s.pause() }
        for case let s as StopwatchState in stateStore.values { s.pause() }
        Speaker.shared.stop()
    }

    public func exit() {
        pauseAll()
        clock.pause()
        game = nil; queue = []; queueIndex = 0; toolIndex = -2
        showChallenge = false; showDraw = false
        stateStore = [:]
    }

    // MARK: Estado de herramientas

    func state<T: AnyObject>(index: Int, make: () -> T) -> T {
        let key = "\(game?.id ?? "")#\(index)"
        if let s = stateStore[key] as? T { return s }
        let s = make()
        stateStore[key] = s
        return s
    }

    /// Índice de la herramienta visible: la elegida en las pestañas o, por defecto, la central de la plantilla.
    func effectiveIndex(game g: Game, template: PlayTemplate) -> Int {
        if toolIndex == -2 { return g.mainToolIndex(for: template) ?? -1 }
        return g.tools.indices.contains(toolIndex) || toolIndex == -1 ? toolIndex : -1
    }

    public func primaryAction() { primaryAction(template: nil) }

    func primaryAction(template: PlayTemplate?) {
        guard let g = game else { return }
        if showChallenge { rollChallenge(); return }
        if showDraw { return }
        let idx = template.map { effectiveIndex(game: g, template: $0) } ?? toolIndex
        let key = "\(g.id)#\(idx)"
        if let bag = stateStore[key] as? CardBagState, let t = template, !t.showReveal,
           bag.kind == .deck || bag.kind == .identity {
            bag.next(); return
        }
        (stateStore[key] as? ToolState)?.primary()
    }

    // MARK: Acceso tipado a estados (se crean bajo demanda con el mismo almacén que ToolHost)

    func bag(_ i: Int) -> CardBagState? {
        guard let g = game, g.tools.indices.contains(i) else { return nil }
        let spec = g.tools[i]
        switch spec.kind {
        case .deck, .generator, .caller, .colorFlash, .identity:
            return state(index: i) { CardBagState(kind: spec.kind, groups: spec.groups ?? []) }
        default: return nil
        }
    }
    func timerState(_ i: Int) -> TimerState? {
        guard let g = game, g.tools.indices.contains(i), g.tools[i].kind == .timer else { return nil }
        let s = g.tools[i].seconds ?? 60
        return state(index: i) { TimerState(seconds: s) }
    }
    func stopwatchState(_ i: Int) -> StopwatchState? {
        guard let g = game, g.tools.indices.contains(i), g.tools[i].kind == .stopwatch else { return nil }
        return state(index: i) { StopwatchState() }
    }
    func scoreboardState(_ i: Int) -> ScoreboardState? {
        guard let g = game, g.tools.indices.contains(i), g.tools[i].kind == .scoreboard else { return nil }
        let n = g.tools[i].teams ?? 2
        return state(index: i) { ScoreboardState(count: n) }
    }
    func boomState(_ i: Int) -> BoomState? {
        guard let g = game, g.tools.indices.contains(i), g.tools[i].kind == .boom else { return nil }
        let m = g.tools[i].multiple ?? 7
        return state(index: i) { BoomState(multiple: m) }
    }
    func codeState(_ i: Int) -> CodeSequenceState? {
        guard let g = game, g.tools.indices.contains(i), g.tools[i].kind == .codeSequence else { return nil }
        let n = g.tools[i].length ?? 4
        return state(index: i) { CodeSequenceState(length: n) }
    }
    func referenceState(_ i: Int) -> ReferenceState? {
        guard let g = game, g.tools.indices.contains(i), g.tools[i].kind == .reference else { return nil }
        return state(index: i) { ReferenceState() }
    }

    // MARK: Reto

    public func rollChallenge(from source: [L]? = nil) {
        if let source, source != challengeSource {
            challengeSource = source
            challengeBag = ShuffleBag(source)
        }
        guard !challengeSource.isEmpty else { return }
        var c = challengeBag.next()
        if c == nil { challengeBag.reset(); c = challengeBag.next() }
        challenge = c
        showChallenge = true
        showDraw = false
    }

    // MARK: Sorteo

    public func openDraw() { showDraw = true; showChallenge = false }

    public func draw(roster: [String]) {
        let pool = roster.filter { !eliminated.contains($0) }
        guard !pool.isEmpty, !drawSpinning else { return }
        drawSpinning = true
        spinTask?.cancel()
        spinTask = Task { [weak self] in
            for _ in 0..<14 {
                guard !Task.isCancelled else { return }
                self?.drawName = pool.randomElement()
                try? await Task.sleep(nanoseconds: 70_000_000)
            }
            self?.drawName = pool.randomElement()
            self?.drawSpinning = false
        }
    }

    public func toggleEliminated(_ name: String) {
        if eliminated.contains(name) { eliminated.remove(name) } else { eliminated.insert(name) }
    }

    public func closeOverlays() { showChallenge = false; showDraw = false }
}

enum AnswerChoice: String {
    case yes, no, unrelated
    var label: L {
        switch self {
        case .yes: return L("Sí", "是")
        case .no: return L("No", "否")
        case .unrelated: return L("No tiene relación", "无关")
        }
    }
    var color: Color {
        switch self {
        case .yes: return Color(hex: 0x2B8A3E)
        case .no: return Color(hex: 0xC92A2A)
        case .unrelated: return Color(hex: 0x495057)
        }
    }
}
