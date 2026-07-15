import Foundation
import FrankCore
import Testing

private let now = Date(timeIntervalSince1970: 1_780_000_000)

@Suite("Menu rows")
struct MenuRowsTests {
    @Test("a pull request becomes a structured row")
    func mapsPullRequestToRow() throws {
        let checks = PRChecks(
            ci: .failing, review: .approved,
            additions: 120, deletions: 45, approvals: 2,
            createdAt: now.addingTimeInterval(-3 * 86_400)
        )
        let rows = MenuRow.rows(for: [
            makePullRequest(
                id: 111,
                number: 42,
                title: "Add mindful notifications",
                repositoryFullName: "angie/pr-frank",
                htmlURL: URL(string: "https://github.com/angie/pr-frank/pull/42")!,
                authorLogin: "angie",
                avatarURL: URL(string: "https://avatars.githubusercontent.com/u/1?v=4")
            ),
        ], statuses: [111: checks], now: now)

        let row = try #require(rows.first)
        #expect(row.id == 111)
        #expect(row.title == "Add mindful notifications")
        #expect(row.number == 42)
        #expect(row.repoShortName == "pr-frank")
        #expect(row.url == URL(string: "https://github.com/angie/pr-frank/pull/42"))
        #expect(row.ci == .failing)
        #expect(row.approvals == 2)
        #expect(row.additions == 120)
        #expect(row.deletions == 45)
        #expect(row.age == "3d")
        #expect(row.avatarURL == URL(string: "https://avatars.githubusercontent.com/u/1?v=4"))
    }

    @Test("diff counts render compactly", arguments: [
        (0, "+0"),
        (999, "+999"),
        (1_000, "+1k"),
        (1_040, "+1k"),
        (1_951, "+2k"),
        (9_949, "+9.9k"),
        (9_950, "+10k"),
        (12_345, "+12k"),
        (999_499, "+999k"),
        (999_500, "+1m"),
        (2_400_000, "+2.4m"),
    ])
    func additionsLabelRendersCompactly(count: Int, expected: String) throws {
        let checks = PRChecks(ci: .passing, review: .noDecision, additions: count, deletions: 3)
        let rows = MenuRow.rows(for: [makePullRequest(id: 1)], statuses: [1: checks], now: now)

        #expect(try #require(rows.first).additionsLabel == expected)
    }

    @Test("the deletions label uses a real minus sign and the same compaction")
    func deletionsLabelUsesMinusSignAndCompaction() throws {
        let checks = PRChecks(ci: .passing, review: .noDecision, additions: 1, deletions: 1_040)
        let rows = MenuRow.rows(for: [makePullRequest(id: 1)], statuses: [1: checks], now: now)

        #expect(try #require(rows.first).deletionsLabel == "−1k")
    }

    @Test("a PR with no status data still rows up calmly")
    func noStatusMeansCalmRow() throws {
        let rows = MenuRow.rows(for: [makePullRequest(id: 1)], statuses: [:], now: now)

        let row = try #require(rows.first)
        #expect(row.ci == .noChecks)
        #expect(row.approvals == 0)
        #expect(row.additions == 0)
        #expect(row.deletions == 0)
        #expect(row.age == nil)
    }

    @Test("rows are ordered most recently updated first")
    func ordersRowsMostRecentlyUpdatedFirst() {
        let older = makePullRequest(id: 1, number: 1, updatedAt: Date(timeIntervalSince1970: 1_000))
        let newer = makePullRequest(id: 2, number: 2, updatedAt: Date(timeIntervalSince1970: 2_000))

        let rows = MenuRow.rows(for: [older, newer], statuses: [:], now: now)

        #expect(rows.map(\.id) == [2, 1])
    }

    @Test("no open pull requests yields no rows")
    func emptyListYieldsNoRows() {
        #expect(MenuRow.rows(for: [], statuses: [:], now: now).isEmpty)
    }

    @Test("age formats by magnitude", arguments: [
        (300.0, "5m"),
        (3_540.0, "59m"),
        (3_600.0, "1h"),
        (82_800.0, "23h"),
        (86_400.0, "1d"),
        (12 * 86_400.0, "12d"),
    ])
    func ageFormatsByMagnitude(secondsAgo: Double, expected: String) throws {
        let checks = PRChecks(ci: .passing, review: .noDecision, createdAt: now.addingTimeInterval(-secondsAgo))

        let rows = MenuRow.rows(for: [makePullRequest(id: 1)], statuses: [1: checks], now: now)

        #expect(try #require(rows.first).age == expected)
    }

    @Test("rows split into mine and watching by authorship")
    func sectionsSplitByAuthorship() {
        let mine = makePullRequest(id: 1, number: 1)
        let watched = makePullRequest(id: 2, number: 2)

        let sections = MenuSections.compute(for: [mine, watched], statuses: [:], authoredIDs: [1], now: now)

        #expect(sections.mine.map(\.id) == [1])
        #expect(sections.watching.map(\.id) == [2])
    }

    @Test("each section stays sorted by most recent activity")
    func sectionsStaySorted() {
        let older = makePullRequest(id: 1, updatedAt: Date(timeIntervalSince1970: 1_000))
        let newer = makePullRequest(id: 2, updatedAt: Date(timeIntervalSince1970: 2_000))
        let watched = makePullRequest(id: 3)

        let sections = MenuSections.compute(for: [older, watched, newer], statuses: [:], authoredIDs: [1, 2], now: now)

        #expect(sections.mine.map(\.id) == [2, 1])
        #expect(sections.watching.map(\.id) == [3])
    }

    @Test("rows carry their check details through")
    func rowsCarryCheckDetails() throws {
        let details = [CheckDetail(name: "Travis", state: .failing)]
        let checks = PRChecks(ci: .failing, review: .noDecision, checkDetails: details)

        let rows = MenuRow.rows(for: [makePullRequest(id: 1)], statuses: [1: checks], now: now)

        #expect(try #require(rows.first).checkDetails == details)
    }

    @Test("rows carry a Jira link learned across sections")
    func rowsCarryJiraLinkAcrossSections() throws {
        let mine = makePullRequest(id: 1, title: "ACME-42: my change", body: nil)
        let watched = makePullRequest(id: 2, body: "https://example.atlassian.net/browse/TREK-9")

        let sections = MenuSections.compute(for: [mine, watched], statuses: [:], authoredIDs: [1], now: now)

        #expect(try #require(sections.mine.first).jiraURL == URL(string: "https://example.atlassian.net/browse/ACME-42"))
        #expect(try #require(sections.watching.first).jiraURL == URL(string: "https://example.atlassian.net/browse/TREK-9"))
    }

    @Test("sections carry status through")
    func sectionsCarryStatus() throws {
        let sections = MenuSections.compute(
            for: [makePullRequest(id: 1)],
            statuses: [1: PRChecks(ci: .failing, review: .noDecision, createdAt: now.addingTimeInterval(-3_600))],
            authoredIDs: [1],
            now: now
        )

        let row = try #require(sections.mine.first)
        #expect(row.ci == .failing)
        #expect(row.age == "1h")
    }
}
