import Foundation

public enum AggregateState: Equatable, Sendable {
    case calm
    case attention
    case alert

    public static func compute(from statuses: [Int: PRChecks], authoredIDs: Set<Int>) -> AggregateState {
        let mine = statuses.filter { authoredIDs.contains($0.key) }
        if mine.values.contains(where: { $0.ci == .failing }) {
            return .alert
        }
        if mine.values.contains(where: { $0.review == .changesRequested }) {
            return .attention
        }
        return .calm
    }
}
