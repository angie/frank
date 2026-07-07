import Foundation

public struct CITransition: Equatable, Sendable {
    public let pullRequestID: Int
    public let to: CIState

    public init(pullRequestID: Int, to: CIState) {
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
}
