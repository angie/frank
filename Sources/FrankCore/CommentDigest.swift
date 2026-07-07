import Foundation

public enum CommentTracker {
    public static func newForeignComments(
        previous: [Int: Int]?,
        current: [Int: PRChecks],
        selfLogin: String?
    ) -> [Int: Int] {
        guard let previous else { return [:] }
        var new: [Int: Int] = [:]
        for (id, checks) in current {
            guard let before = previous[id] else { continue }
            let delta = checks.commentCount - before
            guard delta > 0 else { continue }

            let known = checks.recentCommenters.suffix(delta)
            let foreignKnown = known.filter { $0 != selfLogin }.count
            let unknown = delta - known.count
            let foreign = foreignKnown + unknown
            if foreign > 0 {
                new[id] = foreign
            }
        }
        return new
    }
}

public struct DigestBuffer {
    private var pending: [Int: Int] = [:]
    private var windowStart: Date

    public init(now: Date) {
        windowStart = now
    }

    public mutating func add(_ counts: [Int: Int]) {
        for (id, count) in counts {
            pending[id, default: 0] += count
        }
    }

    public mutating func flushIfDue(now: Date, interval: Duration, in pullRequests: [PullRequest]) -> NotificationContent? {
        guard now.timeIntervalSince(windowStart) >= Double(interval.components.seconds) else { return nil }
        windowStart = now
        let content = NotificationContent.digest(counts: pending, in: pullRequests)
        pending = [:]
        return content
    }
}

extension NotificationContent {
    public static func digest(counts: [Int: Int], in pullRequests: [PullRequest]) -> NotificationContent? {
        let tracked = counts.compactMap { id, count -> (pr: PullRequest, count: Int)? in
            guard let pr = pullRequests.first(where: { $0.id == id }) else { return nil }
            return (pr, count)
        }
        guard !tracked.isEmpty else { return nil }

        let total = tracked.reduce(0) { $0 + $1.count }
        let commentNoun = total == 1 ? "comment" : "comments"
        let prNoun = tracked.count == 1 ? "PR" : "PRs"
        let body = tracked
            .sorted { $0.count > $1.count }
            .map { entry in
                let shortName = entry.pr.repositoryFullName.components(separatedBy: "/").last ?? entry.pr.repositoryFullName
                return "\(shortName)#\(entry.pr.number) · \(entry.count) new"
            }
            .joined(separator: "\n")

        return NotificationContent(
            title: "💬 \(total) new \(commentNoun) on \(tracked.count) \(prNoun)",
            body: body,
            url: tracked.count == 1 ? tracked[0].pr.htmlURL : URL(string: "https://github.com/pulls")!
        )
    }
}
