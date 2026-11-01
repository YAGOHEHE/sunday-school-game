import Foundation

public struct ShuffleBag<T> {
    private let items: [T]
    private var queue: [Int] = []   // índices pendientes; el siguiente es el último
    private var lastIndex: Int?

    public init(_ items: [T]) {
        self.items = items
        reset()
    }

    public var remaining: Int { queue.count }

    public mutating func reset() {
        queue = Array(items.indices).shuffled()
        lastIndex = nil
    }

    public mutating func next() -> T? {
        guard !items.isEmpty else { return nil }
        if queue.isEmpty { refill() }
        let i = queue.removeLast()
        lastIndex = i
        return items[i]
    }

    /// Rebaraja; con >1 elemento, el primero servido no es el último de la ronda anterior.
    private mutating func refill() {
        queue = Array(items.indices).shuffled()
        if items.count > 1, let l = lastIndex, queue.last == l {
            queue.swapAt(queue.count - 1, Int.random(in: 0..<(queue.count - 1)))
        }
    }
}

public enum Boom {
    public static func isBoom(_ n: Int, multiple: Int, includeDigit: Bool) -> Bool {
        guard n > 0, multiple > 0 else { return false }
        if n % multiple == 0 { return true }
        if includeDigit {
            let digit = Character(String(multiple % 10))
            return String(n).contains(digit)
        }
        return false
    }
}

public enum CodeSignal: String, CaseIterable, Codable, Sendable {
    case squeeze, tap, press

    public var name: L {
        switch self {
        case .squeeze: return L("Apretar la mano", "捏手")
        case .tap: return L("Tocar el hombro", "拍肩")
        case .press: return L("Presionar fuerte", "用力按")
        }
    }

    public var symbol: String {
        switch self {
        case .squeeze: return "✊"
        case .tap: return "👋"
        case .press: return "👇"
        }
    }
}

public enum CodeSequence {
    public static func make<R: RandomNumberGenerator>(length: Int, using rng: inout R) -> [(signal: CodeSignal, count: Int)] {
        var result: [(signal: CodeSignal, count: Int)] = []
        var prev: CodeSignal?
        for _ in 0..<max(0, length) {
            let options = CodeSignal.allCases.filter { $0 != prev }
            let s = options.randomElement(using: &rng)!
            result.append((s, Int.random(in: 1...3, using: &rng)))
            prev = s
        }
        return result
    }

    public static func make(length: Int) -> [(signal: CodeSignal, count: Int)] {
        var rng = SystemRandomNumberGenerator()
        return make(length: length, using: &rng)
    }
}

public extension Game {
    func matches(_ query: String) -> Bool {
        let q = fold(query.trimmingCharacters(in: .whitespacesAndNewlines))
        if q.isEmpty { return true }
        let hay = [title.es, title.zh, objective.es, objective.zh, id].map(fold)
        return hay.contains { $0.contains(q) }
    }
}

private func fold(_ s: String) -> String {
    s.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: nil)
}

public extension Session {
    func repeated() -> Session {
        var copy = self
        copy.id = UUID()
        copy.date = Date()
        copy.items = items.map { SessionItem(gameID: $0.gameID, minutes: $0.minutes) }
        return copy
    }

    var overBudget: Bool { totalMinutes > availableMinutes }
}

public extension Array where Element == Session {
    static var historyLimit: Int { 60 }

    /// Inserta o reemplaza (mismo `id`) y mantiene el orden por fecha descendente y el tope.
    mutating func upsert(_ s: Session, limit: Int = historyLimit) {
        removeAll { $0.id == s.id }
        let i = firstIndex { $0.date < s.date } ?? endIndex
        insert(s, at: i)
        if count > limit { removeLast(count - limit) }
    }
}
