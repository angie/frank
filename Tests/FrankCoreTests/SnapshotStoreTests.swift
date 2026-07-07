import Foundation
import FrankCore
import Testing

@Suite("Snapshot store")
struct SnapshotStoreTests {
    private func temporaryFile() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("frank-tests-\(UUID().uuidString)")
            .appendingPathComponent("state.json")
    }

    @Test("statuses round-trip through the file store")
    func roundTrip() throws {
        let url = temporaryFile()
        let store = FileSnapshotStore(fileURL: url)
        let statuses = [
            1: PRChecks(ci: .failing, review: .changesRequested, commentCount: 4, recentCommenters: ["sam"]),
            2: PRChecks(ci: .passing, review: .approved),
        ]

        store.save(statuses)

        #expect(FileSnapshotStore(fileURL: url).load() == statuses)
    }

    @Test("a missing file loads as nothing")
    func missingFileLoadsNil() {
        #expect(FileSnapshotStore(fileURL: temporaryFile()).load() == nil)
    }

    @Test("a snapshot from before the layout fields still loads")
    func legacySnapshotLoads() throws {
        let url = temporaryFile()
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(#"{"1":{"ci":"failing","review":"approved","commentCount":2,"recentCommenters":["sam"]}}"#.utf8)
            .write(to: url)

        let loaded = FileSnapshotStore(fileURL: url).load()

        #expect(loaded?[1]?.ci == .failing)
        #expect(loaded?[1]?.approvals == 0)
        #expect(loaded?[1]?.createdAt == nil)
    }

    @Test("a corrupt file loads as nothing")
    func corruptFileLoadsNil() throws {
        let url = temporaryFile()
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("not json".utf8).write(to: url)

        #expect(FileSnapshotStore(fileURL: url).load() == nil)
    }
}
