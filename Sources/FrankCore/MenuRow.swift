import Foundation

public struct MenuRow: Equatable, Sendable, Identifiable {
    public let id: Int
    public let text: String
    public let url: URL
    public let ciSymbolName: String?

    public static func rows(for pullRequests: [PullRequest], ciStates: [Int: CIState] = [:]) -> [MenuRow] {
        pullRequests
            .sorted { $0.updatedAt > $1.updatedAt }
            .map { pr in
                let shortName = pr.repositoryFullName.components(separatedBy: "/").last ?? pr.repositoryFullName
                return MenuRow(
                    id: pr.id,
                    text: "\(shortName)#\(pr.number) · \(pr.title)",
                    url: pr.htmlURL,
                    ciSymbolName: symbolName(for: ciStates[pr.id] ?? .noChecks)
                )
            }
    }

    private static func symbolName(for state: CIState) -> String? {
        switch state {
        case .passing:
            return "checkmark.circle"
        case .failing:
            return "xmark.circle"
        case .pending:
            return "clock"
        case .noChecks:
            return nil
        }
    }
}
