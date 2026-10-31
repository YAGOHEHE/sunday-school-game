import Foundation

public enum Catalog {
    public enum CatalogError: Error { case notFound }

    public static func decode(_ data: Data) throws -> CatalogFile {
        try JSONDecoder().decode(CatalogFile.self, from: data)
    }

    public static func loadBundled() throws -> CatalogFile {
        // 1) Dentro del .app: Contents/Resources/JuegosDominical_JuegosCore.bundle
        if let res = Bundle.main.resourceURL {
            let b = res.appendingPathComponent("JuegosDominical_JuegosCore.bundle")
            if let bundle = Bundle(url: b), let data = read(bundle) { return try decode(data) }
        }
        // 2) Bundle.module (swift run / tests)
        if let data = read(Bundle.module) { return try decode(data) }
        throw CatalogError.notFound
    }

    private static func read(_ bundle: Bundle) -> Data? {
        let url = bundle.url(forResource: "games", withExtension: "json")
            ?? bundle.url(forResource: "games", withExtension: "json", subdirectory: "Resources")
        return url.flatMap { try? Data(contentsOf: $0) }
    }

    public static func merged(catalog: [Game], user: UserData) -> [Game] {
        let overrides = Dictionary(user.customGames.map { ($0.id, $0) }, uniquingKeysWith: { _, b in b })
        let catalogIDs = Set(catalog.map(\.id))
        var result = catalog.map { overrides[$0.id] ?? $0 }
        var seen = Set<String>()
        for g in user.customGames where !catalogIDs.contains(g.id) && seen.insert(g.id).inserted {
            result.append(overrides[g.id] ?? g)
        }
        let hidden = Set(user.hiddenGameIDs)
        return result.filter { !hidden.contains($0.id) }
    }
}
