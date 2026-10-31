import Foundation

public final class UserDataStore {
    public static var defaultDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        let dir = base.appendingPathComponent("JuegosDominical", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    public let fileURL: URL

    public init(directory: URL = UserDataStore.defaultDirectory) {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        self.fileURL = directory.appendingPathComponent("userdata.json")
    }

    public func load() -> UserData {
        let fm = FileManager.default
        guard fm.fileExists(atPath: fileURL.path) else { return UserData() }
        do {
            let data = try Data(contentsOf: fileURL)
            let dec = JSONDecoder()
            dec.dateDecodingStrategy = .iso8601
            return try dec.decode(UserData.self, from: data)
        } catch {
            let bak = fileURL.appendingPathExtension("bak")
            try? fm.removeItem(at: bak)
            try? fm.moveItem(at: fileURL, to: bak)
            return UserData()
        }
    }

    public func save(_ data: UserData) throws {
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        enc.dateEncodingStrategy = .iso8601
        let bytes = try enc.encode(data)
        try bytes.write(to: fileURL, options: .atomic)
    }
}
