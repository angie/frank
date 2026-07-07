import Foundation
import LanternCore
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
                repositoryFullName: "angie/pr-lantern",
                htmlURL: URL(string: "https://github.com/angie/pr-lantern/pull/42")!
            ),
        ])

        let row = try #require(rows.first)
        #expect(row.id == 111)
        #expect(row.text == "pr-lantern#42 · Add mindful notifications")
        #expect(row.url == URL(string: "https://github.com/angie/pr-lantern/pull/42"))
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
}
