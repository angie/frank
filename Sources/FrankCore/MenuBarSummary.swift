import Foundation

public enum PollState: Equatable, Sendable {
    case idle
    case loaded([PullRequest])
    case failed
}

public enum MenuBarSummary {
    public static func labelText(for state: PollState) -> String? {
        switch state {
        case .idle, .loaded:
            return nil
        case .failed:
            return "–"
        }
    }

    public static func menuHeadline(for state: PollState) -> String {
        switch state {
        case .idle:
            return "Checking GitHub…"
        case .failed:
            return "Couldn't reach GitHub"
        case .loaded(let pullRequests) where pullRequests.isEmpty:
            return "No open pull requests"
        case .loaded(let pullRequests) where pullRequests.count == 1:
            return "1 open pull request"
        case .loaded(let pullRequests):
            return "\(pullRequests.count) open pull requests"
        }
    }
}
