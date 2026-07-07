import Foundation

public enum CIState: Equatable, Sendable {
    case passing
    case failing
    case pending
    case noChecks

    public init(rollupState: String?) {
        switch rollupState {
        case "SUCCESS":
            self = .passing
        case "FAILURE", "ERROR":
            self = .failing
        case "PENDING", "EXPECTED":
            self = .pending
        default:
            self = .noChecks
        }
    }
}

public enum ReviewDecision: Equatable, Sendable {
    case approved
    case changesRequested
    case awaitingReview
    case noDecision

    public init(graphQL: String?) {
        switch graphQL {
        case "APPROVED":
            self = .approved
        case "CHANGES_REQUESTED":
            self = .changesRequested
        case "REVIEW_REQUIRED":
            self = .awaitingReview
        default:
            self = .noDecision
        }
    }
}

public struct PRChecks: Equatable, Sendable {
    public let ci: CIState
    public let review: ReviewDecision

    public init(ci: CIState, review: ReviewDecision) {
        self.ci = ci
        self.review = review
    }
}

public enum ChecksQuery {
    public static func build(for pullRequests: [PullRequest]) -> String {
        let blocks = pullRequests.enumerated().map { index, pr -> String in
            let parts = pr.repositoryFullName.split(separator: "/", maxSplits: 1)
            let owner = parts.first.map(String.init) ?? ""
            let name = parts.count > 1 ? String(parts[1]) : ""
            return """
            pr\(index): repository(owner: "\(owner)", name: "\(name)") { pullRequest(number: \(pr.number)) { \
            reviewDecision \
            commits(last: 1) { nodes { commit { statusCheckRollup { state } } } } } }
            """
        }
        return "query { \(blocks.joined(separator: " ")) }"
    }
}

public enum ChecksResponse {
    private struct Payload: Decodable {
        let data: [String: Repo?]
    }

    private struct Repo: Decodable {
        let pullRequest: PR?
    }

    private struct PR: Decodable {
        let reviewDecision: String?
        let commits: Commits
    }

    private struct Commits: Decodable {
        let nodes: [Node]
    }

    private struct Node: Decodable {
        let commit: Commit
    }

    private struct Commit: Decodable {
        let statusCheckRollup: Rollup?
    }

    private struct Rollup: Decodable {
        let state: String
    }

    public static func statuses(from data: Data, orderedIDs: [Int]) throws -> [Int: PRChecks] {
        let payload = try JSONDecoder().decode(Payload.self, from: data)
        var statuses: [Int: PRChecks] = [:]
        for (index, id) in orderedIDs.enumerated() {
            let pr = payload.data["pr\(index)"]??.pullRequest
            let rollup = pr?.commits.nodes.first?.commit.statusCheckRollup
            statuses[id] = PRChecks(
                ci: rollup.map { CIState(rollupState: $0.state) } ?? .noChecks,
                review: ReviewDecision(graphQL: pr?.reviewDecision)
            )
        }
        return statuses
    }
}
