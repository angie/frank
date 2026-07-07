import Foundation

public struct MenuSections: Equatable, Sendable {
    public let mine: [MenuRow]
    public let watching: [MenuRow]

    public static func compute(
        for pullRequests: [PullRequest],
        statuses: [Int: PRChecks],
        authoredIDs: Set<Int>,
        now: Date
    ) -> MenuSections {
        let (mine, watching) = pullRequests.reduce(into: ([PullRequest](), [PullRequest]())) { result, pr in
            if authoredIDs.contains(pr.id) {
                result.0.append(pr)
            } else {
                result.1.append(pr)
            }
        }
        return MenuSections(
            mine: MenuRow.rows(for: mine, statuses: statuses, now: now),
            watching: MenuRow.rows(for: watching, statuses: statuses, now: now)
        )
    }
}

public struct MenuRow: Equatable, Sendable, Identifiable {
    public let id: Int
    public let text: String
    public let url: URL
    public let ciSymbolName: String?
    public let detail: String?

    public static func rows(for pullRequests: [PullRequest], statuses: [Int: PRChecks], now: Date) -> [MenuRow] {
        pullRequests
            .sorted { $0.updatedAt > $1.updatedAt }
            .map { pr in
                let shortName = pr.repositoryFullName.components(separatedBy: "/").last ?? pr.repositoryFullName
                let checks = statuses[pr.id]
                return MenuRow(
                    id: pr.id,
                    text: "\(shortName)#\(pr.number) · \(pr.title)",
                    url: pr.htmlURL,
                    ciSymbolName: symbolName(for: checks?.ci ?? .noChecks),
                    detail: checks.flatMap { detail(for: $0, now: now) }
                )
            }
    }

    private static func detail(for checks: PRChecks, now: Date) -> String? {
        var parts: [String] = []
        if checks.approvals > 0 {
            parts.append("✓\(checks.approvals)")
        }
        if checks.additions + checks.deletions > 0 {
            parts.append("+\(checks.additions) −\(checks.deletions)")
        }
        if let createdAt = checks.createdAt {
            parts.append(age(from: createdAt, to: now))
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private static func age(from start: Date, to now: Date) -> String {
        let seconds = max(0, now.timeIntervalSince(start))
        if seconds < 3_600 {
            return "\(Int(seconds / 60))m"
        }
        if seconds < 86_400 {
            return "\(Int(seconds / 3_600))h"
        }
        return "\(Int(seconds / 86_400))d"
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
