import Foundation

public enum PollState: Equatable, Sendable {
    case idle
    case loaded([PullRequest])
    case failed
}

public enum MenuBarSummary {
    public static func labelText(for state: PollState) -> String? {
        switch state {
        case .idle:
            return nil
        case .loaded(let pullRequests):
            return pullRequests.isEmpty ? nil : String(pullRequests.count)
        case .failed:
            return "–"
        }
    }
}
