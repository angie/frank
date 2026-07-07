import Foundation
import Observation

public protocol PullRequestSearching: Sendable {
    func openAuthoredPullRequests() async throws -> [PullRequest]
    func openCommentedPullRequests() async throws -> [PullRequest]
}

public protocol ChecksFetching: Sendable {
    func ciStates(for pullRequests: [PullRequest]) async throws -> [Int: CIState]
}

public struct NoChecks: ChecksFetching {
    public init() {}

    public func ciStates(for pullRequests: [PullRequest]) async throws -> [Int: CIState] {
        [:]
    }
}

@MainActor
@Observable
public final class PRMonitor {
    public nonisolated static let defaultInterval: Duration = .seconds(60)

    public private(set) var state: PollState = .idle
    public private(set) var ciStates: [Int: CIState] = [:]

    private let client: any PullRequestSearching
    private let checks: any ChecksFetching

    public init(client: any PullRequestSearching, checks: any ChecksFetching = NoChecks()) {
        self.client = client
        self.checks = checks
    }

    public func poll() async {
        let merged: [PullRequest]
        do {
            async let authored = client.openAuthoredPullRequests()
            async let commented = client.openCommentedPullRequests()
            merged = PRScope.merge(authored: try await authored, commented: try await commented)
            state = .loaded(merged)
        } catch {
            state = .failed
            return
        }
        ciStates = (try? await checks.ciStates(for: merged)) ?? [:]
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
