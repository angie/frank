import Foundation
import LanternCore
import Testing

private struct StubError: Error {}

private actor FakeSearchClient: PullRequestSearching {
    private(set) var fetchCount = 0
    private let result: Result<[PullRequest], Error>

    init(result: Result<[PullRequest], Error>) {
        self.result = result
    }

    func openAuthoredPullRequests() async throws -> [PullRequest] {
        fetchCount += 1
        return try result.get()
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

    @Test("the default poll interval is sixty seconds")
    func defaultIntervalIsSixtySeconds() {
        #expect(PRMonitor.defaultInterval == .seconds(60))
    }
}
