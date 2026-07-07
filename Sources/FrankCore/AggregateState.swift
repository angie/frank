import Foundation

public enum AggregateState: Equatable, Sendable {
    case calm
    case attention
    case alert

    public static func compute(from statuses: [Int: PRChecks]) -> AggregateState {
        if statuses.values.contains(where: { $0.ci == .failing }) {
            return .alert
        }
        if statuses.values.contains(where: { $0.review == .changesRequested }) {
            return .attention
        }
        return .calm
    }
}
