import Foundation
import FrankCore
import Testing

@Suite("Aggregate state")
struct AggregateStateTests {
    @Test("all green or empty means calm")
    func calmWhenNothingWrong() {
        #expect(AggregateState.compute(from: [:], authoredIDs: []) == .calm)
        #expect(AggregateState.compute(from: [
            1: PRChecks(ci: .passing, review: .approved),
            2: PRChecks(ci: .pending, review: .awaitingReview),
            3: PRChecks(ci: .noChecks, review: .noDecision),
        ], authoredIDs: [1, 2, 3]) == .calm)
    }

    @Test("changes requested on my own PR means attention")
    func attentionOnChangesRequested() {
        #expect(AggregateState.compute(from: [
            1: PRChecks(ci: .passing, review: .approved),
            2: PRChecks(ci: .passing, review: .changesRequested),
        ], authoredIDs: [1, 2]) == .attention)
    }

    @Test("a failing PR of mine means alert, beating changes requested")
    func alertOnFailure() {
        #expect(AggregateState.compute(from: [
            1: PRChecks(ci: .failing, review: .approved),
        ], authoredIDs: [1]) == .alert)
        #expect(AggregateState.compute(from: [
            1: PRChecks(ci: .failing, review: .noDecision),
            2: PRChecks(ci: .passing, review: .changesRequested),
        ], authoredIDs: [1, 2]) == .alert)
    }

    @Test("trouble on PRs I only commented on leaves the tortoise calm")
    func othersProblemsStayCalm() {
        #expect(AggregateState.compute(from: [
            1: PRChecks(ci: .failing, review: .changesRequested),
            2: PRChecks(ci: .passing, review: .approved),
        ], authoredIDs: [2]) == .calm)
    }

    @Test("mixed ownership only escalates for my own PRs")
    func mixedOwnershipFiltersToMine() {
        #expect(AggregateState.compute(from: [
            1: PRChecks(ci: .failing, review: .noDecision),
            2: PRChecks(ci: .passing, review: .changesRequested),
        ], authoredIDs: [2]) == .attention)
    }
}
