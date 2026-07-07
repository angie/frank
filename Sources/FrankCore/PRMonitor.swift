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

public protocol UserNotifier: Sendable {
    func post(_ content: NotificationContent) async
}

public struct SilentNotifier: UserNotifier {
    public init() {}

    public func post(_ content: NotificationContent) async {}
}

@MainActor
@Observable
public final class PRMonitor {
    public nonisolated static let defaultInterval: Duration = .seconds(60)

    public private(set) var state: PollState = .idle
    public private(set) var ciStates: [Int: CIState] = [:]

    private let client: any PullRequestSearching
    private let checks: any ChecksFetching
    private let notifier: any UserNotifier
    private var lastKnownCIStates: [Int: CIState]?

    public init(
        client: any PullRequestSearching,
        checks: any ChecksFetching = NoChecks(),
        notifier: any UserNotifier = SilentNotifier()
    ) {
        self.client = client
        self.checks = checks
        self.notifier = notifier
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

        guard let fresh = try? await checks.ciStates(for: merged) else {
            ciStates = [:]
            return
        }
        ciStates = fresh

        for transition in TransitionDetector.detect(previous: lastKnownCIStates, current: fresh) {
            if let content = NotificationContent.forCITransition(transition, in: merged) {
                await notifier.post(content)
            }
        }
        lastKnownCIStates = fresh
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
