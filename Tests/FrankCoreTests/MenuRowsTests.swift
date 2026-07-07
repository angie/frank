import Foundation
import FrankCore
import Testing

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
        ])

        let row = try #require(rows.first)
        #expect(row.id == 111)
        #expect(row.text == "pr-frank#42 · Add mindful notifications")
        #expect(row.url == URL(string: "https://github.com/angie/pr-frank/pull/42"))
    }

    @Test("rows are ordered most recently updated first")
    func ordersRowsMostRecentlyUpdatedFirst() {
        let older = makePullRequest(id: 1, number: 1, updatedAt: Date(timeIntervalSince1970: 1_000))
        let newer = makePullRequest(id: 2, number: 2, updatedAt: Date(timeIntervalSince1970: 2_000))

        let rows = MenuRow.rows(for: [older, newer])

        #expect(rows.map(\.id) == [2, 1])
    }

    @Test("no open pull requests yields no rows")
    func emptyListYieldsNoRows() {
        #expect(MenuRow.rows(for: []).isEmpty)
    }

    @Test("rows carry a CI glyph matching each pull request's state", arguments: [
        (CIState.passing, "checkmark.circle"),
        (CIState.failing, "xmark.circle"),
        (CIState.pending, "clock"),
    ])
    func rowsCarryCIGlyph(state: CIState, symbol: String) throws {
        let rows = MenuRow.rows(for: [makePullRequest(id: 1)], ciStates: [1: state])

        #expect(try #require(rows.first).ciSymbolName == symbol)
    }

    @Test("rows split into mine and watching by authorship")
    func sectionsSplitByAuthorship() {
        let mine = makePullRequest(id: 1, number: 1)
        let watched = makePullRequest(id: 2, number: 2)

        let sections = MenuSections.compute(for: [mine, watched], ciStates: [:], authoredIDs: [1])

        #expect(sections.mine.map(\.id) == [1])
        #expect(sections.watching.map(\.id) == [2])
    }

    @Test("each section stays sorted by most recent activity")
    func sectionsStaySorted() {
        let older = makePullRequest(id: 1, updatedAt: Date(timeIntervalSince1970: 1_000))
        let newer = makePullRequest(id: 2, updatedAt: Date(timeIntervalSince1970: 2_000))
        let watched = makePullRequest(id: 3)

        let sections = MenuSections.compute(for: [older, watched, newer], ciStates: [:], authoredIDs: [1, 2])

        #expect(sections.mine.map(\.id) == [2, 1])
        #expect(sections.watching.map(\.id) == [3])
    }

    @Test("sections carry CI glyphs through")
    func sectionsCarryGlyphs() throws {
        let sections = MenuSections.compute(
            for: [makePullRequest(id: 1)],
            ciStates: [1: .failing],
            authoredIDs: [1]
        )

        #expect(try #require(sections.mine.first).ciSymbolName == "xmark.circle")
    }

    @Test("no checks and unknown CI state show no glyph")
    func noChecksShowsNoGlyph() throws {
        let known = MenuRow.rows(for: [makePullRequest(id: 1)], ciStates: [1: .noChecks])
        let unknown = MenuRow.rows(for: [makePullRequest(id: 2)])

        #expect(try #require(known.first).ciSymbolName == nil)
        #expect(try #require(unknown.first).ciSymbolName == nil)
    }
}
