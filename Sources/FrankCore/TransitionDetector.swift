import Foundation

public struct CITransition: Equatable, Sendable {
    public let pullRequestID: Int
    public let to: CIState

    public init(pullRequestID: Int, to: CIState) {
        self.pullRequestID = pullRequestID
        self.to = to
    }
}

public struct ReviewTransition: Equatable, Sendable {
    public let pullRequestID: Int
    public let to: ReviewDecision

    public init(pullRequestID: Int, to: ReviewDecision) {
        self.pullRequestID = pullRequestID
        self.to = to
    }
}

public enum TransitionDetector {
    public static func detect(previous: [Int: CIState]?, current: [Int: CIState]) -> [CITransition] {
        guard let previous else { return [] }
        return current.compactMap { id, state in
            guard let before = previous[id], before != state else { return nil }
            guard state == .passing || state == .failing else { return nil }
            return CITransition(pullRequestID: id, to: state)
        }
    }

    public static func detectReviews(previous: [Int: ReviewDecision]?, current: [Int: ReviewDecision]) -> [ReviewTransition] {
        guard let previous else { return [] }
        return current.compactMap { id, decision in
            guard let before = previous[id], before != decision else { return nil }
            guard decision == .approved || decision == .changesRequested else { return nil }
            return ReviewTransition(pullRequestID: id, to: decision)
        }
    }
}
