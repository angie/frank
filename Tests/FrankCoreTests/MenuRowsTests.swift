import Foundation
import FrankCore
import Testing

private let now = Date(timeIntervalSince1970: 1_780_000_000)

@Suite("Menu rows")
struct MenuRowsTests {
    @Test("a pull request becomes a row with repo#number, title and its web URL")
    func mapsPullRequestToRowTextAndURL() throws {
        let rows = MenuRow.rows(for: [
            makePullRequest(
                id: 111,
                number: 42,
                title: "Add mindful notifications",
                repositoryFullName: "angie/pr-frank",
                htmlURL: URL(string: "https://github.com/angie/pr-frank/pull/42")!
            ),
        ], statuses: [:], now: now)

        let row = try #require(rows.first)
        #expect(row.id == 111)
        #expect(row.text == "pr-frank#42 · Add mindful notifications")
        #expect(row.url == URL(string: "https://github.com/angie/pr-frank/pull/42"))
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

    @Test("rows carry a CI glyph matching each pull request's state", arguments: [
        (CIState.passing, "checkmark.circle"),
        (CIState.failing, "xmark.circle"),
        (CIState.pending, "clock"),
    ])
    func rowsCarryCIGlyph(state: CIState, symbol: String) throws {
        let statuses = [1: PRChecks(ci: state, review: .noDecision)]

        let rows = MenuRow.rows(for: [makePullRequest(id: 1)], statuses: statuses, now: now)

        #expect(try #require(rows.first).ciSymbolName == symbol)
    }

    @Test("no checks and unknown CI state show no glyph")
    func noChecksShowsNoGlyph() throws {
        let known = MenuRow.rows(
            for: [makePullRequest(id: 1)],
            statuses: [1: PRChecks(ci: .noChecks, review: .noDecision)],
            now: now
        )
        let unknown = MenuRow.rows(for: [makePullRequest(id: 2)], statuses: [:], now: now)

        #expect(try #require(known.first).ciSymbolName == nil)
        #expect(try #require(unknown.first).ciSymbolName == nil)
    }

    @Test("a row's detail shows approvals, diff size and age")
    func detailShowsApprovalsDiffAndAge() throws {
        let checks = PRChecks(
            ci: .passing, review: .approved,
            additions: 120, deletions: 45, approvals: 2,
            createdAt: now.addingTimeInterval(-3 * 86_400)
        )

        let rows = MenuRow.rows(for: [makePullRequest(id: 1)], statuses: [1: checks], now: now)

        #expect(try #require(rows.first).detail == "✓2 · +120 −45 · 3d")
    }

    @Test("zero approvals and an empty diff are omitted from the detail")
    func detailOmitsEmptyParts() throws {
        let checks = PRChecks(
            ci: .pending, review: .noDecision,
            additions: 0, deletions: 0, approvals: 0,
            createdAt: now.addingTimeInterval(-300)
        )

        let rows = MenuRow.rows(for: [makePullRequest(id: 1)], statuses: [1: checks], now: now)

        #expect(try #require(rows.first).detail == "5m")
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
        let checks = PRChecks(
            ci: .passing, review: .noDecision,
            additions: 0, deletions: 0, approvals: 0,
            createdAt: now.addingTimeInterval(-secondsAgo)
        )

        let rows = MenuRow.rows(for: [makePullRequest(id: 1)], statuses: [1: checks], now: now)

        #expect(try #require(rows.first).detail == expected)
    }

    @Test("a PR with no status data has no detail")
    func noStatusMeansNoDetail() throws {
        let rows = MenuRow.rows(for: [makePullRequest(id: 1)], statuses: [:], now: now)

        #expect(try #require(rows.first).detail == nil)
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

    @Test("sections carry CI glyphs and detail through")
    func sectionsCarryGlyphsAndDetail() throws {
        let sections = MenuSections.compute(
            for: [makePullRequest(id: 1)],
            statuses: [1: PRChecks(ci: .failing, review: .noDecision, createdAt: now.addingTimeInterval(-3_600))],
            authoredIDs: [1],
            now: now
        )

        let row = try #require(sections.mine.first)
        #expect(row.ciSymbolName == "xmark.circle")
        #expect(row.detail == "1h")
    }
}
