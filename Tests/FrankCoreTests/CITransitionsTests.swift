import Foundation
import FrankCore
import Testing

@Suite("CI transitions")
struct CITransitionsTests {
    @Test("the first poll ever is a baseline, not a wave of notifications")
    func firstPollIsBaseline() {
        let transitions = TransitionDetector.detect(previous: nil, current: [1: .failing, 2: .passing])

        #expect(transitions.isEmpty)
    }

    @Test("a newly tracked PR is a baseline even mid-run")
    func newPRIsBaseline() {
        let transitions = TransitionDetector.detect(previous: [1: .passing], current: [1: .passing, 2: .failing])

        #expect(transitions.isEmpty)
    }

    @Test("an unchanged state stays silent")
    func sameStateIsSilent() {
        let states: [Int: CIState] = [1: .passing, 2: .failing, 3: .pending]

        #expect(TransitionDetector.detect(previous: states, current: states).isEmpty)
    }

    @Test("becoming failing notifies", arguments: [CIState.passing, .pending, .noChecks])
    func becomingFailingNotifies(from previous: CIState) {
        let transitions = TransitionDetector.detect(previous: [1: previous], current: [1: .failing])

        #expect(transitions == [CITransition(pullRequestID: 1, to: .failing)])
    }

    @Test("becoming passing notifies", arguments: [CIState.failing, .pending, .noChecks])
    func becomingPassingNotifies(from previous: CIState) {
        let transitions = TransitionDetector.detect(previous: [1: previous], current: [1: .passing])

        #expect(transitions == [CITransition(pullRequestID: 1, to: .passing)])
    }

    @Test("becoming pending or losing checks stays silent")
    func becomingPendingOrNoChecksIsSilent() {
        let transitions = TransitionDetector.detect(
            previous: [1: .passing, 2: .failing],
            current: [1: .pending, 2: .noChecks]
        )

        #expect(transitions.isEmpty)
    }
}
