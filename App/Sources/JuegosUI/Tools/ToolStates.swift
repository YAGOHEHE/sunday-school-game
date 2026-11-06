import SwiftUI
import Observation
import JuegosCore

@MainActor
protocol ToolState: AnyObject {
    /// Acción principal (barra espaciadora).
    func primary()
}

// MARK: - Temporizador

@MainActor @Observable
final class TimerState: ToolState {
    var total: Double
    var remaining: Double
    var running = false
    var finished = false
    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var endDate: Date?

    init(seconds: Int) {
        let t = Double(max(1, seconds)); total = t; remaining = t
    }

    func primary() { running ? pause() : start() }

    func start() {
        if remaining <= 0 { remaining = total }
        finished = false
        endDate = Date().addingTimeInterval(remaining)
        running = true
        timer?.invalidate()
        let t = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    func pause() {
        running = false
        timer?.invalidate(); timer = nil
    }

    func reset() { pause(); finished = false; remaining = total }

    func set(seconds: Int) {
        pause(); finished = false
        total = Double(max(1, seconds)); remaining = total
    }

    func add(seconds: Double) {
        remaining = max(0, remaining + seconds)
        total = max(total, remaining)
        if running { endDate = Date().addingTimeInterval(remaining) }
    }

    private func tick() {
        guard let end = endDate else { return }
        remaining = max(0, end.timeIntervalSinceNow)
        if remaining <= 0 {
            pause(); finished = true
            Sound.ding()
        }
    }

    deinit { timer?.invalidate() }
}

// MARK: - Cronómetro

@MainActor @Observable
final class StopwatchState: ToolState {
    var elapsed: Double = 0
    var running = false
    var laps: [Double] = []
    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var startDate: Date?
    @ObservationIgnored private var base: Double = 0

    func primary() { running ? pause() : start() }

    func start() {
        base = elapsed
        startDate = Date()
        running = true
        timer?.invalidate()
        let t = Timer(timeInterval: 0.05, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, let s = self.startDate else { return }
                self.elapsed = self.base + Date().timeIntervalSince(s)
            }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    func pause() { running = false; timer?.invalidate(); timer = nil }
    func reset() { pause(); elapsed = 0; laps = [] }
    func lap() { if running || elapsed > 0 { laps.append(elapsed) } }
    deinit { timer?.invalidate() }
}

// MARK: - Marcador

struct Team: Identifiable, Hashable {
    var id = UUID()
    var name: String
    var score = 0
}

@MainActor @Observable
final class ScoreboardState: ToolState {
    var teams: [Team]
    init(count: Int) {
        let n = max(1, min(8, count))
        teams = (1...n).map { Team(name: "Equipo \($0)") }
    }
    func primary() {}
    func addTeam() {
        guard teams.count < 8 else { return }
        teams.append(Team(name: "Equipo \(teams.count + 1)"))
    }
    func removeTeam() { if teams.count > 1 { teams.removeLast() } }
    func resetScores() { for i in teams.indices { teams[i].score = 0 } }
}

// MARK: - Bolsa de tarjetas (mazo, generador, llamador, color, identidad)

@MainActor @Observable
final class CardBagState: ToolState {
    let groups: [CardGroup]
    let kind: ToolKind
    var groupIndex: Int          // -1 = todos
    var current: Card?
    var revealed = false
    var rollTick = 0
    var remaining = 0
    var reshuffled = false
    var manual = false           // colorFlash
    // llamador
    var auto = false
    var interval = 5
    var speak = false
    var speakMode: LanguageMode = .es
    var showAll = false          // identity
    var shown: [Card] = []       // cartas ya mostradas (roles usados)
    private var bag = ShuffleBag<Card>([])
    @ObservationIgnored private var autoTimer: Timer?

    init(kind: ToolKind, groups: [CardGroup]) {
        self.kind = kind
        self.groups = groups
        let allowAll = (kind == .generator || kind == .caller || kind == .colorFlash || kind == .identity)
        groupIndex = (allowAll && groups.count > 1) ? -1 : 0
        rebuild()
    }

    var hasAllOption: Bool { groups.count > 1 && kind != .deck }

    var cards: [Card] {
        if groupIndex < 0 { return groups.flatMap(\.cards) }
        return groups.indices.contains(groupIndex) ? groups[groupIndex].cards : []
    }

    private func rebuild() {
        bag = ShuffleBag(cards)
        remaining = bag.remaining
    }

    func select(_ i: Int) {
        groupIndex = i; current = nil; revealed = false; reshuffled = false; shown = []
        rebuild()
    }

    func shuffleAgain() { rebuild(); current = nil; revealed = false; reshuffled = false; shown = [] }

    func next() {
        // ShuffleBag.next() nunca devuelve nil (se rebaraja solo al agotarse). Detectamos el fin
        // de ronda por remaining == 0 ANTES de robar, para reiniciar el contador de mostradas y
        // marcar el rebarajado. Así el contador no se pasa del total (antes salía «14 de 12»).
        let newRound = bag.remaining == 0 && !shown.isEmpty
        let c = bag.next()
        if newRound { reshuffled = true; shown = [] } else { reshuffled = false }
        if let c { shown.append(c) }
        current = c
        revealed = false
        remaining = bag.remaining
        rollTick += 1
        if speak, kind == .caller, let f = c?.front { Speaker.shared.say(f, mode: speakMode) }
    }

    func reveal() { revealed = true }

    func pick(_ card: Card) { current = card; revealed = false; rollTick += 1 }

    func primary() {
        switch kind {
        case .deck, .caller, .identity:
            if current == nil { next() }
            else if !revealed, current?.back != nil { reveal() }
            else { next() }
        case .reference: break
        default: next()
        }
    }

    func setAuto(_ on: Bool) {
        auto = on
        autoTimer?.invalidate(); autoTimer = nil
        guard on else { return }
        if current == nil { next() }
        scheduleAuto()
    }

    private func scheduleAuto() {
        autoTimer?.invalidate()
        let t = Timer(timeInterval: Double(max(1, interval)), repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.next() }
        }
        RunLoop.main.add(t, forMode: .common)
        autoTimer = t
    }

    func setInterval(_ s: Int) {
        interval = max(1, s)
        if auto { scheduleAuto() }
    }

    deinit { autoTimer?.invalidate() }
}

// MARK: - Boom

@MainActor @Observable
final class BoomState: ToolState {
    var n = 0
    var multiple: Int
    var includeDigit = true
    init(multiple: Int) { self.multiple = max(2, multiple) }
    var isBoom: Bool { n > 0 && Boom.isBoom(n, multiple: multiple, includeDigit: includeDigit) }
    func primary() { n += 1 }
    func reset() { n = 0 }
}

// MARK: - Secuencia de código

@MainActor @Observable
final class CodeSequenceState: ToolState {
    var length: Int
    var sequence: [(signal: CodeSignal, count: Int)] = []
    var hidden = false
    init(length: Int) { self.length = max(1, length) }
    func primary() { generate() }
    func generate() { sequence = CodeSequence.make(length: length); hidden = false }
}

// MARK: - Referencia

@MainActor @Observable
final class ReferenceState: ToolState {
    var groupIndex = 0
    func primary() {}
}
