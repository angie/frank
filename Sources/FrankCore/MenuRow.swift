import Foundation

public struct MenuRow: Equatable, Sendable, Identifiable {
    public let id: Int
    public let text: String
    public let url: URL

    public static func rows(for pullRequests: [PullRequest]) -> [MenuRow] {
        pullRequests
            .sorted { $0.updatedAt > $1.updatedAt }
            .map { pr in
                let shortName = pr.repositoryFullName.components(separatedBy: "/").last ?? pr.repositoryFullName
                return MenuRow(id: pr.id, text: "\(shortName)#\(pr.number) · \(pr.title)", url: pr.htmlURL)
            }
    }
}
