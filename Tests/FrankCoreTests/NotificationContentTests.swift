import Foundation
import FrankCore
import Testing

@Suite("Notification content")
struct NotificationContentTests {
    @Test("a CI transition becomes a banner with verdict title and PR body")
    func formatsCITransition() throws {
        let pr = makePullRequest(
            id: 1,
            number: 3198,
            title: "Polish the launch checklist",
            repositoryFullName: "octoco/rocket-app",
            htmlURL: URL(string: "https://github.com/octoco/rocket-app/pull/3198")!
        )

        let failing = try #require(NotificationContent.forCITransition(
            CITransition(pullRequestID: 1, to: .failing), in: [pr]
        ))
        #expect(failing.title == "❌ CI failing")
        #expect(failing.body == "rocket-app#3198 · Polish the launch checklist")
        #expect(failing.url == pr.htmlURL)

        let passing = try #require(NotificationContent.forCITransition(
            CITransition(pullRequestID: 1, to: .passing), in: [pr]
        ))
        #expect(passing.title == "✅ CI passing")
        #expect(passing.body == "rocket-app#3198 · Polish the launch checklist")
    }

    @Test("a transition for an untracked PR produces no banner")
    func untrackedPRProducesNothing() {
        let content = NotificationContent.forCITransition(
            CITransition(pullRequestID: 99, to: .failing),
            in: [makePullRequest(id: 1)]
        )

        #expect(content == nil)
    }
}
