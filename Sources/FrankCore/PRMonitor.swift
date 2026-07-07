import Foundation
import Observation

public protocol PullRequestSearching: Sendable {
    func openAuthoredPullRequests() async throws -> [PullRequest]
    func openCommentedPullRequests() async throws -> [PullRequest]
}

public protocol ChecksFetching: Sendable {
    func statuses(for pullRequests: [PullRequest]) async throws -> [Int: PRChecks]
}

public struct NoChecks: ChecksFetching {
    public init() {}

    public func statuses(for pullRequests: [PullRequest]) async throws -> [Int: PRChecks] {
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
    public nonisolated static let defaultDigestInterval: Duration = .seconds(1800)

    public private(set) var state: PollState = .idle
    public private(set) var statuses: [Int: PRChecks] = [:]

    public var ciStates: [Int: CIState] { statuses.mapValues(\.ci) }

    private let client: any PullRequestSearching
    private let checks: any ChecksFetching
    private let notifier: any UserNotifier
    private let selfLogin: String?
    private let digestInterval: Duration
    private let store: any SnapshotStoring
    private var lastKnown: [Int: PRChecks]?
    private var digest: DigestBuffer?

    public init(
        client: any PullRequestSearching,
        checks: any ChecksFetching = NoChecks(),
        notifier: any UserNotifier = SilentNotifier(),
        selfLogin: String? = nil,
        digestInterval: Duration = PRMonitor.defaultDigestInterval,
        store: any SnapshotStoring = NoStore()
    ) {
        self.client = client
        self.checks = checks
        self.notifier = notifier
        self.selfLogin = selfLogin
        self.digestInterval = digestInterval
        self.store = store
        self.lastKnown = store.load()
    }

    public func poll(now: Date = Date()) async {
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

        guard let fresh = try? await checks.statuses(for: merged) else {
            statuses = [:]
            return
        }
        statuses = fresh

        for transition in TransitionDetector.detect(
            previous: lastKnown?.mapValues(\.ci), current: fresh.mapValues(\.ci)
        ) {
            if let content = NotificationContent.forCITransition(transition, in: merged) {
                await notifier.post(content)
            }
        }
        for transition in TransitionDetector.detectReviews(
            previous: lastKnown?.mapValues(\.review), current: fresh.mapValues(\.review)
        ) {
            if let content = NotificationContent.forReviewTransition(transition, in: merged) {
                await notifier.post(content)
            }
        }

        var buffer = digest ?? DigestBuffer(now: now)
        buffer.add(CommentTracker.newForeignComments(
            previous: lastKnown?.mapValues(\.commentCount),
            current: fresh,
            selfLogin: selfLogin
        ))
        if let content = buffer.flushIfDue(now: now, interval: digestInterval, in: merged) {
            await notifier.post(content)
        }
        digest = buffer

        lastKnown = fresh
        store.save(fresh)
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
