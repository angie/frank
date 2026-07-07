import Foundation
import FrankCore
import Testing

@Suite("Menu bar summary")
struct MenuBarSummaryTests {
    @Test("the menu bar stays calm — no text — before and after a successful poll")
    func calmStatesShowNothing() {
        #expect(MenuBarSummary.labelText(for: .idle) == nil)
        #expect(MenuBarSummary.labelText(for: .loaded([])) == nil)
        #expect(MenuBarSummary.labelText(for: .loaded([makePullRequest()])) == nil)
    }

    @Test("the menu bar shows a dash when the last poll failed")
    func failureShowsDash() {
        #expect(MenuBarSummary.labelText(for: .failed) == "–")
    }

    @Test("the menu headline reports each state honestly")
    func menuHeadlinePerState() {
        #expect(MenuBarSummary.menuHeadline(for: .idle) == "Checking GitHub…")
        #expect(MenuBarSummary.menuHeadline(for: .failed) == "Couldn't reach GitHub")
        #expect(MenuBarSummary.menuHeadline(for: .loaded([])) == "No open pull requests")
    }

    @Test("the menu headline counts open pull requests, singular and plural")
    func menuHeadlineCounts() {
        #expect(MenuBarSummary.menuHeadline(for: .loaded([makePullRequest()])) == "1 open pull request")
        #expect(MenuBarSummary.menuHeadline(for: .loaded([
            makePullRequest(id: 1),
            makePullRequest(id: 2),
            makePullRequest(id: 3),
        ])) == "3 open pull requests")
    }
}
