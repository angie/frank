import Foundation
import FrankCore
import Testing

private struct StubError: Error {}

private actor FakeSearchClient: PullRequestSearching {
    private(set) var fetchCount = 0
    private let authored: Result<[PullRequest], Error>
    private let commented: Result<[PullRequest], Error>

    init(result: Result<[PullRequest], Error>) {
        self.init(authored: result, commented: .success([]))
    }

    init(authored: Result<[PullRequest], Error>, commented: Result<[PullRequest], Error>) {
        self.authored = authored
        self.commented = commented
    }

    func openAuthoredPullRequests() async throws -> [PullRequest] {
        fetchCount += 1
        return try authored.get()
    }

    func openCommentedPullRequests() async throws -> [PullRequest] {
        try commented.get()
    }
}

private struct FakeChecksClient: ChecksFetching {
    let result: Result<[Int: CIState], Error>

    func ciStates(for pullRequests: [PullRequest]) async throws -> [Int: CIState] {
        try result.get().filter { id, _ in pullRequests.contains { $0.id == id } }
    }
}

private actor SleepRecorder {
    private(set) var durations: [Duration] = []
    private let failOnCall: Int

    init(failOnCall: Int) {
        self.failOnCall = failOnCall
    }

    func sleep(for duration: Duration) async throws {
        durations.append(duration)
        if durations.count >= failOnCall {
            throw CancellationError()
        }
    }
}

@Suite("Polling for pull requests")
struct PollingTests {
    @MainActor
    @Test("a successful poll publishes the fetched pull requests")
    func successPublishesPullRequests() async {
        let pullRequests = [makePullRequest()]
        let monitor = PRMonitor(client: FakeSearchClient(result: .success(pullRequests)))

        await monitor.poll()

        #expect(monitor.state == .loaded(pullRequests))
    }

    @MainActor
    @Test("a failed poll publishes the failed state")
    func failurePublishesFailedState() async {
        let monitor = PRMonitor(client: FakeSearchClient(result: .failure(StubError())))

        await monitor.poll()

        #expect(monitor.state == .failed)
    }

    @MainActor
    @Test("run polls immediately and again after each interval, until cancelled")
    func runPollsOnEachInterval() async {
        let client = FakeSearchClient(result: .success([makePullRequest()]))
        let recorder = SleepRecorder(failOnCall: 2)
        let monitor = PRMonitor(client: client)

        await monitor.run(interval: .seconds(60)) { try await recorder.sleep(for: $0) }

        #expect(await client.fetchCount == 2)
        #expect(await recorder.durations == [.seconds(60), .seconds(60)])
    }

    @MainActor
    @Test("poll tracks PRs I commented on alongside authored ones")
    func pollTracksCommentedOnPullRequests() async {
        let authored = makePullRequest(id: 1)
        let commented = makePullRequest(id: 2)
        let monitor = PRMonitor(client: FakeSearchClient(
            authored: .success([authored]),
            commented: .success([commented])
        ))

        await monitor.poll()

        #expect(monitor.state == .loaded([authored, commented]))
    }

    @MainActor
    @Test("a failing commented search fails the whole poll")
    func commentedFailureMarksFailed() async {
        let monitor = PRMonitor(client: FakeSearchClient(
            authored: .success([makePullRequest()]),
            commented: .failure(StubError())
        ))

        await monitor.poll()

        #expect(monitor.state == .failed)
    }

    @MainActor
    @Test("poll publishes CI states for the tracked pull requests")
    func pollPublishesCIStates() async {
        let authored = makePullRequest(id: 1)
        let commented = makePullRequest(id: 2)
        let monitor = PRMonitor(
            client: FakeSearchClient(authored: .success([authored]), commented: .success([commented])),
            checks: FakeChecksClient(result: .success([1: .passing, 2: .failing]))
        )

        await monitor.poll()

        #expect(monitor.ciStates == [1: .passing, 2: .failing])
    }

    @MainActor
    @Test("a failing checks fetch still loads pull requests and clears CI states")
    func checksFailureStillLoadsPullRequests() async {
        let pullRequests = [makePullRequest()]
        let monitor = PRMonitor(
            client: FakeSearchClient(result: .success(pullRequests)),
            checks: FakeChecksClient(result: .failure(StubError()))
        )

        await monitor.poll()

        #expect(monitor.state == .loaded(pullRequests))
        #expect(monitor.ciStates.isEmpty)
    }

    @Test("the default poll interval is sixty seconds")
    func defaultIntervalIsSixtySeconds() {
        #expect(PRMonitor.defaultInterval == .seconds(60))
    }
}
