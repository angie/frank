import Foundation
import FrankCore
import Testing

@Suite("Aggregate state")
struct AggregateStateTests {
    @Test("all green or empty means calm")
    func calmWhenNothingWrong() {
        #expect(AggregateState.compute(from: [:]) == .calm)
        #expect(AggregateState.compute(from: [
            1: PRChecks(ci: .passing, review: .approved),
            2: PRChecks(ci: .pending, review: .awaitingReview),
            3: PRChecks(ci: .noChecks, review: .noDecision),
        ]) == .calm)
    }

    @Test("changes requested anywhere means attention")
    func attentionOnChangesRequested() {
        #expect(AggregateState.compute(from: [
            1: PRChecks(ci: .passing, review: .approved),
            2: PRChecks(ci: .passing, review: .changesRequested),
        ]) == .attention)
    }

    @Test("a failing PR anywhere means alert, beating changes requested")
    func alertOnFailure() {
        #expect(AggregateState.compute(from: [
            1: PRChecks(ci: .failing, review: .approved),
        ]) == .alert)
        #expect(AggregateState.compute(from: [
            1: PRChecks(ci: .failing, review: .noDecision),
            2: PRChecks(ci: .passing, review: .changesRequested),
        ]) == .alert)
    }
}
