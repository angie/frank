import Foundation
import Observation

public protocol PullRequestSearching: Sendable {
    func openAuthoredPullRequests() async throws -> [PullRequest]
}

@MainActor
@Observable
public final class PRMonitor {
    public nonisolated static let defaultInterval: Duration = .seconds(60)

    public private(set) var state: PollState = .idle

    private let client: any PullRequestSearching

    public init(client: any PullRequestSearching) {
        self.client = client
    }

    public func poll() async {
        do {
            state = .loaded(try await client.openAuthoredPullRequests())
        } catch {
            state = .failed
        }
    }

    public func run(
        interval: Duration = PRMonitor.defaultInterval,
        sleep: @escaping @Sendable (Duration) async throws -> Void = { try await Task.sleep(for: $0) }
    ) async {
        while true {
            await poll()
            do {
                try await sleep(interval)
            } catch {
                return
            }
        }
    }
}
