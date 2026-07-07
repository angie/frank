import Foundation
import FrankCore
import Testing

@Suite("Review transitions")
struct ReviewTransitionsTests {
    @Test("the first poll ever is a baseline")
    func firstPollIsBaseline() {
        let transitions = TransitionDetector.detectReviews(previous: nil, current: [1: .approved])

        #expect(transitions.isEmpty)
    }

    @Test("a newly tracked PR is a baseline")
    func newPRIsBaseline() {
        let transitions = TransitionDetector.detectReviews(
            previous: [1: .awaitingReview],
            current: [1: .awaitingReview, 2: .approved]
        )

        #expect(transitions.isEmpty)
    }

    @Test("an unchanged decision stays silent")
    func sameDecisionIsSilent() {
        let decisions: [Int: ReviewDecision] = [1: .approved, 2: .changesRequested]

        #expect(TransitionDetector.detectReviews(previous: decisions, current: decisions).isEmpty)
    }

    @Test("becoming approved notifies", arguments: [ReviewDecision.awaitingReview, .changesRequested, .noDecision])
    func becomingApprovedNotifies(from previous: ReviewDecision) {
        let transitions = TransitionDetector.detectReviews(previous: [1: previous], current: [1: .approved])

        #expect(transitions == [ReviewTransition(pullRequestID: 1, to: .approved)])
    }

    @Test("changes requested notifies", arguments: [ReviewDecision.awaitingReview, .approved, .noDecision])
    func changesRequestedNotifies(from previous: ReviewDecision) {
        let transitions = TransitionDetector.detectReviews(previous: [1: previous], current: [1: .changesRequested])

        #expect(transitions == [ReviewTransition(pullRequestID: 1, to: .changesRequested)])
    }

    @Test("returning to awaiting review or no decision stays silent")
    func returningToNeutralIsSilent() {
        let transitions = TransitionDetector.detectReviews(
            previous: [1: .approved, 2: .changesRequested],
            current: [1: .awaitingReview, 2: .noDecision]
        )

        #expect(transitions.isEmpty)
    }
}
