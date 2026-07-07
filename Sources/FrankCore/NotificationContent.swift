import Foundation

public struct NotificationContent: Equatable, Sendable {
    public let title: String
    public let body: String
    public let url: URL

    public init(title: String, body: String, url: URL) {
        self.title = title
        self.body = body
        self.url = url
    }

    public static func forCITransition(_ transition: CITransition, in pullRequests: [PullRequest]) -> NotificationContent? {
        guard let pr = pullRequests.first(where: { $0.id == transition.pullRequestID }) else { return nil }

        let title: String
        switch transition.to {
        case .passing:
            title = "✅ CI passing"
        case .failing:
            title = "❌ CI failing"
        case .pending, .noChecks:
            return nil
        }

        return NotificationContent(title: title, body: body(for: pr), url: pr.htmlURL)
    }

    public static func forReviewTransition(_ transition: ReviewTransition, in pullRequests: [PullRequest]) -> NotificationContent? {
        guard let pr = pullRequests.first(where: { $0.id == transition.pullRequestID }) else { return nil }

        let title: String
        switch transition.to {
        case .approved:
            title = "👍 Approved"
        case .changesRequested:
            title = "🔄 Changes requested"
        case .awaitingReview, .noDecision:
            return nil
        }

        return NotificationContent(title: title, body: body(for: pr), url: pr.htmlURL)
    }

    private static func body(for pr: PullRequest) -> String {
        let shortName = pr.repositoryFullName.components(separatedBy: "/").last ?? pr.repositoryFullName
        return "\(shortName)#\(pr.number) · \(pr.title)"
    }
}
