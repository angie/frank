import Foundation
import FrankCore
import Testing

@Suite("Jira links")
struct JiraLinkTests {
    @Test("a browse link in the PR body wins outright")
    func bodyLinkWins() {
        let pr = makePullRequest(
            id: 1,
            title: "ACME-999: something",
            body: "Fixes [ACME-1226](https://example.atlassian.net/browse/ACME-1226) properly."
        )

        #expect(JiraLink.resolve(for: pr, among: [pr]) == URL(string: "https://example.atlassian.net/browse/ACME-1226"))
    }

    @Test("a title key resolves against a base learned from a sibling PR's body")
    func titleKeyUsesLearnedBase() {
        let sibling = makePullRequest(
            id: 2,
            body: "See https://example.atlassian.net/browse/TREK-9 for details"
        )
        let pr = makePullRequest(id: 1, title: "ACME-1226: localise the empty-state copy", body: "No links here")

        #expect(JiraLink.resolve(for: pr, among: [pr, sibling]) == URL(string: "https://example.atlassian.net/browse/ACME-1226"))
    }

    @Test("a title key with no learned base resolves to nothing")
    func titleKeyWithoutBaseIsNil() {
        let pr = makePullRequest(id: 1, title: "ACME-1226: localise the empty-state copy", body: "plain text")

        #expect(JiraLink.resolve(for: pr, among: [pr]) == nil)
    }

    @Test("titles without a ticket key resolve to nothing", arguments: [
        "fix flaky poller",
        "feat(health): sub-slice 1.2",
        "acme-123 lowercase is not a ticket",
        "X-1 single-letter project is not a ticket",
    ])
    func nonTicketTitlesAreNil(title: String) {
        let sibling = makePullRequest(id: 2, body: "https://example.atlassian.net/browse/ACME-1 exists")
        let pr = makePullRequest(id: 1, title: title, body: nil)

        #expect(JiraLink.resolve(for: pr, among: [pr, sibling]) == nil)
    }

    @Test("ticket keys with digits in the project resolve too")
    func digitProjectKeysResolve() {
        let sibling = makePullRequest(id: 2, body: "https://x.atlassian.net/browse/AB1-2")
        let pr = makePullRequest(id: 1, title: "AB1-77: numbered project", body: nil)

        #expect(JiraLink.resolve(for: pr, among: [pr, sibling]) == URL(string: "https://x.atlassian.net/browse/AB1-77"))
    }
}
