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
            mine: MenuRow.rows(for: mine, statuses: statuses, now: now, resolvingJiraAmong: pullRequests),
            watching: MenuRow.rows(for: watching, statuses: statuses, now: now, resolvingJiraAmong: pullRequests)
        )
    }
}

public struct MenuRow: Equatable, Sendable, Identifiable {
    public let id: Int
    public let title: String
    public let number: Int
    public let repoShortName: String
    public let url: URL
    public let ci: CIState
    public let approvals: Int
    public let additions: Int
    public let deletions: Int
    public let age: String?
    public let avatarURL: URL?
    public let jiraURL: URL?

    public static func rows(
        for pullRequests: [PullRequest],
        statuses: [Int: PRChecks],
        now: Date,
        resolvingJiraAmong jiraContext: [PullRequest]? = nil
    ) -> [MenuRow] {
        pullRequests
            .sorted { $0.updatedAt > $1.updatedAt }
            .map { pr in
                let checks = statuses[pr.id]
                return MenuRow(
                    id: pr.id,
                    title: pr.title,
                    number: pr.number,
                    repoShortName: pr.repositoryFullName.components(separatedBy: "/").last ?? pr.repositoryFullName,
                    url: pr.htmlURL,
                    ci: checks?.ci ?? .noChecks,
                    approvals: checks?.approvals ?? 0,
                    additions: checks?.additions ?? 0,
                    deletions: checks?.deletions ?? 0,
                    age: checks?.createdAt.map { age(from: $0, to: now) },
                    avatarURL: pr.avatarURL,
                    jiraURL: JiraLink.resolve(for: pr, among: jiraContext ?? pullRequests)
                )
            }
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
}
