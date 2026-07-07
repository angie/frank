import Foundation

public enum CIState: String, Equatable, Sendable, Codable {
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

public enum ReviewDecision: String, Equatable, Sendable, Codable {
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

public struct CheckDetail: Equatable, Sendable, Codable {
    public let name: String
    public let state: CIState

    public init(name: String, state: CIState) {
        self.name = name
        self.state = state
    }

    public init(checkRunConclusion: String?, name: String) {
        self.name = name
        switch checkRunConclusion {
        case "SUCCESS":
            state = .passing
        case "FAILURE", "CANCELLED", "TIMED_OUT", "ACTION_REQUIRED", "STARTUP_FAILURE":
            state = .failing
        case nil:
            state = .pending
        default:
            state = .noChecks
        }
    }
}

public struct PRChecks: Equatable, Sendable, Codable {
    public let ci: CIState
    public let review: ReviewDecision
    public let commentCount: Int
    public let recentCommenters: [String]
    public let additions: Int
    public let deletions: Int
    public let approvals: Int
    public let createdAt: Date?
    public let checkDetails: [CheckDetail]

    public init(
        ci: CIState,
        review: ReviewDecision,
        commentCount: Int = 0,
        recentCommenters: [String] = [],
        additions: Int = 0,
        deletions: Int = 0,
        approvals: Int = 0,
        createdAt: Date? = nil,
        checkDetails: [CheckDetail] = []
    ) {
        self.ci = ci
        self.review = review
        self.commentCount = commentCount
        self.recentCommenters = recentCommenters
        self.additions = additions
        self.deletions = deletions
        self.approvals = approvals
        self.createdAt = createdAt
        self.checkDetails = checkDetails
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        ci = try container.decode(CIState.self, forKey: .ci)
        review = try container.decode(ReviewDecision.self, forKey: .review)
        commentCount = try container.decode(Int.self, forKey: .commentCount)
        recentCommenters = try container.decode([String].self, forKey: .recentCommenters)
        additions = try container.decodeIfPresent(Int.self, forKey: .additions) ?? 0
        deletions = try container.decodeIfPresent(Int.self, forKey: .deletions) ?? 0
        approvals = try container.decodeIfPresent(Int.self, forKey: .approvals) ?? 0
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
        checkDetails = try container.decodeIfPresent([CheckDetail].self, forKey: .checkDetails) ?? []
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
            reviewDecision additions deletions createdAt \
            reviews(states: APPROVED) { totalCount } \
            comments(last: 10) { totalCount nodes { author { login } } } \
            commits(last: 1) { nodes { commit { statusCheckRollup { state \
            contexts(first: 30) { nodes { __typename ... on CheckRun { name conclusion } ... on StatusContext { context state } } } } } } } } }
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
        let additions: Int?
        let deletions: Int?
        let createdAt: Date?
        let reviews: Reviews?
        let comments: Comments?
        let commits: Commits
    }

    private struct Reviews: Decodable {
        let totalCount: Int
    }

    private struct Comments: Decodable {
        let totalCount: Int
        let nodes: [CommentNode]
    }

    private struct CommentNode: Decodable {
        let author: Author?
    }

    private struct Author: Decodable {
        let login: String
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
        let contexts: Contexts?
    }

    private struct Contexts: Decodable {
        let nodes: [ContextNode]
    }

    private struct ContextNode: Decodable {
        let __typename: String
        let name: String?
        let conclusion: String?
        let context: String?
        let state: String?
    }

    public static func statuses(from data: Data, orderedIDs: [Int]) throws -> [Int: PRChecks] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let payload = try decoder.decode(Payload.self, from: data)
        var statuses: [Int: PRChecks] = [:]
        for (index, id) in orderedIDs.enumerated() {
            let pr = payload.data["pr\(index)"]??.pullRequest
            let rollup = pr?.commits.nodes.first?.commit.statusCheckRollup
            statuses[id] = PRChecks(
                ci: rollup.map { CIState(rollupState: $0.state) } ?? .noChecks,
                review: ReviewDecision(graphQL: pr?.reviewDecision),
                commentCount: pr?.comments?.totalCount ?? 0,
                recentCommenters: pr?.comments?.nodes.compactMap(\.author?.login) ?? [],
                additions: pr?.additions ?? 0,
                deletions: pr?.deletions ?? 0,
                approvals: pr?.reviews?.totalCount ?? 0,
                createdAt: pr?.createdAt,
                checkDetails: (rollup?.contexts?.nodes ?? []).compactMap { node in
                    switch node.__typename {
                    case "CheckRun":
                        return CheckDetail(checkRunConclusion: node.conclusion, name: node.name ?? "check")
                    case "StatusContext":
                        return CheckDetail(name: node.context ?? "status", state: CIState(rollupState: node.state))
                    default:
                        return nil
                    }
                }
            )
        }
        return statuses
    }
}
