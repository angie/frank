import Foundation

public struct MenuSections: Equatable, Sendable {
    public let mine: [MenuRow]
    public let watching: [MenuRow]

    public static func compute(for pullRequests: [PullRequest], ciStates: [Int: CIState], authoredIDs: Set<Int>) -> MenuSections {
        MenuRow.sections(for: pullRequests, ciStates: ciStates, authoredIDs: authoredIDs)
    }
}

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

    public static func sections(for pullRequests: [PullRequest], ciStates: [Int: CIState], authoredIDs: Set<Int>) -> MenuSections {
        let (mine, watching) = pullRequests.reduce(into: ([PullRequest](), [PullRequest]())) { result, pr in
            if authoredIDs.contains(pr.id) {
                result.0.append(pr)
            } else {
                result.1.append(pr)
            }
        }
        return MenuSections(
            mine: rows(for: mine, ciStates: ciStates),
            watching: rows(for: watching, ciStates: ciStates)
        )
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
