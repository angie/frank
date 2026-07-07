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

        let shortName = pr.repositoryFullName.components(separatedBy: "/").last ?? pr.repositoryFullName
        return NotificationContent(title: title, body: "\(shortName)#\(pr.number) · \(pr.title)", url: pr.htmlURL)
    }
}
