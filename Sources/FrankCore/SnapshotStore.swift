import Foundation

public protocol SnapshotStoring: Sendable {
    func load() -> [Int: PRChecks]?
    func save(_ statuses: [Int: PRChecks])
}

public struct NoStore: SnapshotStoring {
    public init() {}

    public func load() -> [Int: PRChecks]? { nil }

    public func save(_ statuses: [Int: PRChecks]) {}
}

public struct FileSnapshotStore: SnapshotStoring {
    private let fileURL: URL

    public init(fileURL: URL) {
        self.fileURL = fileURL
    }

    public func load() -> [Int: PRChecks]? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? JSONDecoder().decode([Int: PRChecks].self, from: data)
    }

    public func save(_ statuses: [Int: PRChecks]) {
        guard let data = try? JSONEncoder().encode(statuses) else { return }
        try? FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try? data.write(to: fileURL, options: .atomic)
    }
}
