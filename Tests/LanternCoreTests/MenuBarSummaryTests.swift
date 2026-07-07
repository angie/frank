import Foundation
import LanternCore
import Testing

@Suite("Menu bar summary")
struct MenuBarSummaryTests {
    @Test("shows no text before the first poll completes")
    func idleShowsNothing() {
        #expect(MenuBarSummary.labelText(for: .idle) == nil)
    }

    @Test("shows no text when there are no open pull requests")
    func emptyShowsNothing() {
        #expect(MenuBarSummary.labelText(for: .loaded([])) == nil)
    }

    @Test("shows the count of open pull requests")
    func countsOpenPullRequests() {
        #expect(MenuBarSummary.labelText(for: .loaded([makePullRequest()])) == "1")
        #expect(MenuBarSummary.labelText(for: .loaded([
            makePullRequest(id: 1),
            makePullRequest(id: 2),
            makePullRequest(id: 3),
        ])) == "3")
    }

    @Test("shows a dash when the last poll failed")
    func failureShowsDash() {
        #expect(MenuBarSummary.labelText(for: .failed) == "–")
    }
}
