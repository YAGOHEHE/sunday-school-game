import XCTest
@testable import JuegosCore

final class JuegosCoreTests: XCTestCase {
    private func game(_ id: String, _ es: String = "Juego", zh: String = "游戏") -> Game {
        Game(id: id, icon: "🎲", title: L(es, zh), category: .mente, minMinutes: 5, maxMinutes: 10,
             objective: L("Objetivo", "目标"), steps: [])
    }

    func testDecodeInline() throws {
        let json = """
        {"version":1,"challenges":[{"es":"Bailar","zh":"跳舞"}],
         "games":[{"id":"x","icon":"🎲","title":{"es":"Equis","zh":"X"},"category":"mente",
         "minMinutes":5,"maxMinutes":10,"objective":{"es":"o","zh":"目"},"steps":[],"tips":[],"variants":[],
         "tools":[{"kind":"timer","seconds":30}]}]}
        """
        let c = try Catalog.decode(Data(json.utf8))
        XCTAssertEqual(c.games.count, 1)
        XCTAssertEqual(c.games[0].tools[0].seconds, 30)
        XCTAssertEqual(c.games[0].suggestedMinutes, 8)
    }

    func testBundledCatalogValid() throws {
        let c = try Catalog.loadBundled()
        XCTAssertEqual(c.version, 1)
        XCTAssertFalse(c.games.isEmpty)
        XCTAssertFalse(c.challenges.isEmpty)
        XCTAssertEqual(Set(c.games.map(\.id)).count, c.games.count, "ids duplicados")

        func bi(_ l: L, _ w: String) {
            XCTAssertFalse(l.es.trimmingCharacters(in: .whitespaces).isEmpty, "es vacío: \(w)")
            XCTAssertFalse(l.zh.trimmingCharacters(in: .whitespaces).isEmpty, "zh vacío: \(w)")
        }
        c.challenges.forEach { bi($0, "challenge") }
        for g in c.games {
            bi(g.title, g.id); bi(g.objective, g.id)
            g.steps.forEach { bi($0, g.id) }
            g.tips.forEach { bi($0, g.id) }
            if let w = g.why { bi(w, g.id) }
            XCTAssertLessThanOrEqual(g.minMinutes, g.maxMinutes, g.id)
            for v in g.variants {
                bi(v.title, g.id)
                if let o = v.objective { bi(o, g.id) }
                v.steps.forEach { bi($0, g.id) }
                v.tips.forEach { bi($0, g.id) }
            }
            for t in g.tools {
                if let ti = t.title { bi(ti, g.id) }
                let w = "\(g.id)/\(t.kind)"
                switch t.kind {
                case .timer: XCTAssertNotNil(t.seconds, w)
                case .scoreboard: XCTAssertNotNil(t.teams, w)
                case .boom: XCTAssertNotNil(t.multiple, w)
                case .codeSequence: XCTAssertNotNil(t.length, w)
                case .stopwatch: break
                case .deck, .generator, .reference, .caller, .colorFlash, .identity:
                    XCTAssertFalse(t.groups?.isEmpty ?? true, w)
                }
                for grp in t.groups ?? [] {
                    bi(grp.name, w)
                    XCTAssertFalse(grp.cards.isEmpty, w)
                    for card in grp.cards {
                        bi(card.front, w)
                        if let b = card.back { bi(b, w) }
                        if t.kind == .colorFlash { XCTAssertNotNil(card.color, w) }
                    }
                }
            }
        }
    }

    func testMerged() {
        let cat = [game("a"), game("b"), game("c")]
        var u = UserData()
        u.customGames = [game("b", "Editado"), game("z")]
        u.hiddenGameIDs = ["c"]
        let m = Catalog.merged(catalog: cat, user: u)
        XCTAssertEqual(m.map(\.id), ["a", "b", "z"])
        XCTAssertEqual(m[1].title.es, "Editado")
    }

    func testShuffleBag() {
        var bag = ShuffleBag(Array(0..<10))
        XCTAssertEqual(bag.remaining, 10)
        var seen = Set<Int>()
        for _ in 0..<10 { seen.insert(bag.next()!) }
        XCTAssertEqual(seen.count, 10)
        XCTAssertEqual(bag.remaining, 0)
        // frontera: sin repetir el último
        var bag2 = ShuffleBag([1, 2])
        var prev = bag2.next()!
        for _ in 0..<500 {
            let n = bag2.next()!
            XCTAssertNotEqual(n, prev)
            prev = n
        }
        var one = ShuffleBag(["x"])
        XCTAssertEqual(one.next(), "x"); XCTAssertEqual(one.next(), "x")
        var empty = ShuffleBag<Int>([])
        XCTAssertNil(empty.next())
        bag.reset()
        XCTAssertEqual(bag.remaining, 10)
    }

    func testBoom() {
        XCTAssertTrue(Boom.isBoom(7, multiple: 7, includeDigit: false))
        XCTAssertTrue(Boom.isBoom(14, multiple: 7, includeDigit: false))
        XCTAssertFalse(Boom.isBoom(17, multiple: 7, includeDigit: false))
        XCTAssertTrue(Boom.isBoom(17, multiple: 7, includeDigit: true))
        XCTAssertTrue(Boom.isBoom(14, multiple: 7, includeDigit: true))
        XCTAssertFalse(Boom.isBoom(8, multiple: 7, includeDigit: true))
        XCTAssertFalse(Boom.isBoom(0, multiple: 7, includeDigit: true))
    }

    func testCodeSequence() {
        for _ in 0..<200 {
            let s = CodeSequence.make(length: 6)
            XCTAssertEqual(s.count, 6)
            for (i, e) in s.enumerated() {
                XCTAssertTrue((1...3).contains(e.count))
                if i > 0 { XCTAssertNotEqual(e.signal, s[i - 1].signal) }
            }
        }
        var rng = SystemRandomNumberGenerator()
        XCTAssertEqual(CodeSequence.make(length: 4, using: &rng).count, 4)
    }

    func testMatches() {
        let g = game("cambia-de-sitio", "Cámara lenta", zh: "慢动作")
        XCTAssertTrue(g.matches(""))
        XCTAssertTrue(g.matches("camara"))
        XCTAssertTrue(g.matches("LENTA"))
        XCTAssertTrue(g.matches("慢"))
        XCTAssertTrue(g.matches("sitio"))
        XCTAssertFalse(g.matches("zzz"))
    }

    func testSession() {
        let s = Session(title: "t", availableMinutes: 20,
                        items: [SessionItem(gameID: "a", minutes: 10), SessionItem(gameID: "b", minutes: 15)])
        XCTAssertEqual(s.totalMinutes, 25)
        XCTAssertTrue(s.overBudget)
        let r = s.repeated()
        XCTAssertNotEqual(r.id, s.id)
        XCTAssertEqual(r.items.map(\.gameID), ["a", "b"])
        XCTAssertEqual(r.items.map(\.minutes), [10, 15])
        XCTAssertTrue(zip(r.items, s.items).allSatisfy { $0.id != $1.id })
        XCTAssertFalse(Session(availableMinutes: 30).overBudget)
    }

    func testUserDataStore() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = UserDataStore(directory: dir)
        XCTAssertEqual(store.load().roster, [])
        var u = UserData()
        u.roster = ["Ana", "李明"]
        u.favoriteIDs = ["a"]
        u.language = .zh
        u.customGames = [game("z")]
        u.history = [Session(date: Date(timeIntervalSince1970: 1_700_000_000), title: "h")]
        try store.save(u)
        let back = store.load()
        XCTAssertEqual(back.roster, ["Ana", "李明"])
        XCTAssertEqual(back.language, .zh)
        XCTAssertEqual(back.customGames.first?.id, "z")
        XCTAssertEqual(back.history.first?.date, Date(timeIntervalSince1970: 1_700_000_000))

        try Data("{ corrupto".utf8).write(to: store.fileURL)
        XCTAssertEqual(store.load().roster, [])
        XCTAssertTrue(FileManager.default.fileExists(atPath: store.fileURL.appendingPathExtension("bak").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: store.fileURL.path))
    }
}
