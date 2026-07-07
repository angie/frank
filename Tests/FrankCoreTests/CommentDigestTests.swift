import Foundation
import FrankCore
import Testing

@Suite("Comment tracking")
struct CommentTrackingTests {
    @Test("the first poll ever is a baseline")
    func firstPollIsBaseline() {
        let new = CommentTracker.newForeignComments(
            previous: nil,
            current: [1: PRChecks(ci: .passing, review: .noDecision, commentCount: 5, recentCommenters: ["sam"])],
            selfLogin: "angie"
        )

        #expect(new.isEmpty)
    }

    @Test("a newly tracked PR is a baseline")
    func newPRIsBaseline() {
        let new = CommentTracker.newForeignComments(
            previous: [1: 2],
            current: [
                1: PRChecks(ci: .passing, review: .noDecision, commentCount: 2, recentCommenters: []),
                2: PRChecks(ci: .passing, review: .noDecision, commentCount: 9, recentCommenters: ["sam"]),
            ],
            selfLogin: "angie"
        )

        #expect(new.isEmpty)
    }

    @Test("new comments from others are counted")
    func countsForeignComments() {
        let new = CommentTracker.newForeignComments(
            previous: [1: 2],
            current: [1: PRChecks(ci: .passing, review: .noDecision, commentCount: 4, recentCommenters: ["kit", "sam"])],
            selfLogin: "angie"
        )

        #expect(new == [1: 2])
    }

    @Test("my own comments never count")
    func excludesOwnComments() {
        let new = CommentTracker.newForeignComments(
            previous: [1: 2],
            current: [1: PRChecks(ci: .passing, review: .noDecision, commentCount: 4, recentCommenters: ["sam", "angie"])],
            selfLogin: "angie"
        )

        #expect(new == [1: 1])
    }

    @Test("a delta that is entirely my own comments produces no entry")
    func allOwnCommentsProduceNothing() {
        let new = CommentTracker.newForeignComments(
            previous: [1: 3],
            current: [1: PRChecks(ci: .passing, review: .noDecision, commentCount: 4, recentCommenters: ["angie"])],
            selfLogin: "angie"
        )

        #expect(new.isEmpty)
    }

    @Test("comments beyond the author window count as foreign")
    func unknownAuthorsCountAsForeign() {
        let new = CommentTracker.newForeignComments(
            previous: [1: 0],
            current: [1: PRChecks(ci: .passing, review: .noDecision, commentCount: 12, recentCommenters: ["angie", "sam"])],
            selfLogin: "angie"
        )

        #expect(new == [1: 11])
    }

    @Test("only the newest comments in the window count against the delta")
    func onlyNewestCommentsCount() {
        let new = CommentTracker.newForeignComments(
            previous: [1: 5],
            current: [1: PRChecks(ci: .passing, review: .noDecision, commentCount: 7, recentCommenters: ["angie", "sam", "kit"])],
            selfLogin: "angie"
        )

        #expect(new == [1: 2])
    }

    @Test("an unchanged or shrinking count produces nothing")
    func noDeltaProducesNothing() {
        let new = CommentTracker.newForeignComments(
            previous: [1: 4, 2: 4],
            current: [
                1: PRChecks(ci: .passing, review: .noDecision, commentCount: 4, recentCommenters: ["sam"]),
                2: PRChecks(ci: .passing, review: .noDecision, commentCount: 2, recentCommenters: ["sam"]),
            ],
            selfLogin: "angie"
        )

        #expect(new.isEmpty)
    }
}

@Suite("Comment digest")
struct CommentDigestTests {
    private let epoch = Date(timeIntervalSince1970: 1_780_000_000)

    @Test("a digest summarises comments across PRs, largest first")
    func digestContent() throws {
        let prs = [
            makePullRequest(id: 1, number: 42, title: "First", repositoryFullName: "angie/frank"),
            makePullRequest(id: 2, number: 7, title: "Second", repositoryFullName: "angie/garden"),
        ]

        let content = try #require(NotificationContent.digest(counts: [1: 1, 2: 3], in: prs))

        #expect(content.title == "💬 4 new comments on 2 PRs")
        #expect(content.body == "garden#7 · 3 new\nfrank#42 · 1 new")
        #expect(content.url == URL(string: "https://github.com/pulls"))
    }

    @Test("a single comment on a single PR reads singular and links to the PR")
    func digestSingular() throws {
        let pr = makePullRequest(id: 1, number: 42, repositoryFullName: "angie/frank")

        let content = try #require(NotificationContent.digest(counts: [1: 1], in: [pr]))

        #expect(content.title == "💬 1 new comment on 1 PR")
        #expect(content.url == pr.htmlURL)
    }

    @Test("no counts or only untracked PRs produce no digest")
    func emptyDigestIsNil() {
        #expect(NotificationContent.digest(counts: [:], in: [makePullRequest(id: 1)]) == nil)
        #expect(NotificationContent.digest(counts: [99: 3], in: [makePullRequest(id: 1)]) == nil)
    }

    @Test("the buffer accumulates and only flushes when the interval has elapsed")
    func bufferFlushesOnInterval() {
        var buffer = DigestBuffer(now: epoch)
        let pr = makePullRequest(id: 1)

        buffer.add([1: 2])
        #expect(buffer.flushIfDue(now: epoch + 60, interval: .seconds(1800), in: [pr]) == nil)

        buffer.add([1: 1])
        let content = buffer.flushIfDue(now: epoch + 1800, interval: .seconds(1800), in: [pr])
        #expect(content?.title == "💬 3 new comments on 1 PR")
    }

    @Test("flushing clears the buffer and resets the window")
    func flushClearsBuffer() {
        var buffer = DigestBuffer(now: epoch)
        let pr = makePullRequest(id: 1)

        buffer.add([1: 2])
        _ = buffer.flushIfDue(now: epoch + 1800, interval: .seconds(1800), in: [pr])

        #expect(buffer.flushIfDue(now: epoch + 3600, interval: .seconds(1800), in: [pr]) == nil)
    }

    @Test("an empty window resets quietly")
    func emptyWindowFlushesNothing() {
        var buffer = DigestBuffer(now: epoch)

        #expect(buffer.flushIfDue(now: epoch + 1800, interval: .seconds(1800), in: []) == nil)

        buffer.add([1: 1])
        let tooSoon = buffer.flushIfDue(now: epoch + 1860, interval: .seconds(1800), in: [makePullRequest(id: 1)])
        #expect(tooSoon == nil)
    }
}
