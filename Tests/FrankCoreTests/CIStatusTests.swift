import Foundation
import FrankCore
import Testing

@Suite("CI status")
struct CIStatusTests {
    @Test("rollup states map onto CI states", arguments: [
        ("SUCCESS", CIState.passing),
        ("FAILURE", CIState.failing),
        ("ERROR", CIState.failing),
        ("PENDING", CIState.pending),
        ("EXPECTED", CIState.pending),
    ])
    func mapsRollupStatesToCIStates(rollup: String, expected: CIState) {
        #expect(CIState(rollupState: rollup) == expected)
    }

    @Test("an unknown rollup state means no checks")
    func unknownRollupMeansNone() {
        #expect(CIState(rollupState: "SOMETHING_NEW") == CIState.noChecks)
    }

    @Test("review decisions map onto GitHub's values", arguments: [
        ("APPROVED", ReviewDecision.approved),
        ("CHANGES_REQUESTED", ReviewDecision.changesRequested),
        ("REVIEW_REQUIRED", ReviewDecision.awaitingReview),
        ("SOMETHING_NEW", ReviewDecision.noDecision),
    ])
    func mapsReviewDecisions(raw: String, expected: ReviewDecision) {
        #expect(ReviewDecision(graphQL: raw) == expected)
    }

    @Test("a missing review decision means no decision")
    func missingReviewDecisionMeansNoDecision() {
        #expect(ReviewDecision(graphQL: nil) == ReviewDecision.noDecision)
    }

    @Test("a checks response decodes CI state and review decision keyed by PR id")
    func decodesStatusesKeyedByPullRequestId() throws {
        let ids = [111, 222]
        let data = Data("""
        {"data": {
            "pr0": {"pullRequest": {
                "reviewDecision": "APPROVED",
                "commits": {"nodes": [{"commit": {"statusCheckRollup": {"state": "SUCCESS"}}}]}
            }},
            "pr1": {"pullRequest": {
                "reviewDecision": "CHANGES_REQUESTED",
                "commits": {"nodes": [{"commit": {"statusCheckRollup": {"state": "FAILURE"}}}]}
            }}
        }}
        """.utf8)

        let statuses = try ChecksResponse.statuses(from: data, orderedIDs: ids)

        #expect(statuses == [
            111: PRChecks(ci: .passing, review: .approved),
            222: PRChecks(ci: .failing, review: .changesRequested),
        ])
    }

    @Test("missing rollup, review, pull request or commits degrade gracefully")
    func missingPiecesDegradeGracefully() throws {
        let ids = [1, 2, 3]
        let data = Data("""
        {"data": {
            "pr0": {"pullRequest": {
                "reviewDecision": null,
                "commits": {"nodes": [{"commit": {"statusCheckRollup": null}}]}
            }},
            "pr1": {"pullRequest": null},
            "pr2": {"pullRequest": {"reviewDecision": "APPROVED", "commits": {"nodes": []}}}
        }}
        """.utf8)

        let statuses = try ChecksResponse.statuses(from: data, orderedIDs: ids)

        #expect(statuses == [
            1: PRChecks(ci: .noChecks, review: .noDecision),
            2: PRChecks(ci: .noChecks, review: .noDecision),
            3: PRChecks(ci: .noChecks, review: .approved),
        ])
    }

    @Test("the query aliases every tracked pull request and asks for reviews")
    func queryCoversEveryTrackedPullRequest() {
        let query = ChecksQuery.build(for: [
            makePullRequest(id: 111, number: 42, repositoryFullName: "angie/frank"),
            makePullRequest(id: 222, number: 7, repositoryFullName: "octo-org/my.repo"),
        ])

        #expect(query.contains(#"pr0: repository(owner: "angie", name: "frank") { pullRequest(number: 42)"#))
        #expect(query.contains(#"pr1: repository(owner: "octo-org", name: "my.repo") { pullRequest(number: 7)"#))
        #expect(query.contains("statusCheckRollup"))
        #expect(query.contains("reviewDecision"))
        #expect(query.contains("comments(last: 10) { totalCount nodes { author { login } } }"))
        #expect(query.contains("additions deletions createdAt"))
        #expect(query.contains("reviews(states: APPROVED) { totalCount }"))
    }

    @Test("a checks response decodes size, approvals and age")
    func decodesSizeApprovalsAndAge() throws {
        let data = Data("""
        {"data": {
            "pr0": {"pullRequest": {
                "reviewDecision": "APPROVED",
                "additions": 120,
                "deletions": 45,
                "createdAt": "2026-07-04T10:00:00Z",
                "reviews": {"totalCount": 2},
                "comments": {"totalCount": 0, "nodes": []},
                "commits": {"nodes": [{"commit": {"statusCheckRollup": {"state": "SUCCESS"}}}]}
            }}
        }}
        """.utf8)

        let checks = try #require(try ChecksResponse.statuses(from: data, orderedIDs: [1])[1])

        #expect(checks.additions == 120)
        #expect(checks.deletions == 45)
        #expect(checks.approvals == 2)
        #expect(checks.createdAt == ISO8601DateFormatter().date(from: "2026-07-04T10:00:00Z"))
    }

    @Test("the query asks for individual check contexts")
    func queryAsksForCheckContexts() {
        let query = ChecksQuery.build(for: [makePullRequest(id: 1)])

        #expect(query.contains("contexts(first: 30) { nodes { __typename ... on CheckRun { name conclusion detailsUrl } ... on StatusContext { context state targetUrl } } }"))
    }

    @Test("check runs and status contexts decode into named check details")
    func decodesCheckDetails() throws {
        let data = Data("""
        {"data": {
            "pr0": {"pullRequest": {
                "reviewDecision": null,
                "commits": {"nodes": [{"commit": {"statusCheckRollup": {
                    "state": "FAILURE",
                    "contexts": {"nodes": [
                        {"__typename": "CheckRun", "name": "Travis CI - Pull Request", "conclusion": "FAILURE", "detailsUrl": "https://circleci.com/run/1"},
                        {"__typename": "CheckRun", "name": "Summary", "conclusion": "SUCCESS", "detailsUrl": null},
                        {"__typename": "CheckRun", "name": "Deploy preview", "conclusion": null},
                        {"__typename": "CheckRun", "name": "Lint (optional)", "conclusion": "SKIPPED"},
                        {"__typename": "StatusContext", "context": "codecov/project", "state": "SUCCESS", "targetUrl": "https://codecov.io/project/9"},
                        {"__typename": "StatusContext", "context": "codecov/patch", "state": "PENDING"}
                    ]}
                }}}]}
            }}
        }}
        """.utf8)

        let checks = try #require(try ChecksResponse.statuses(from: data, orderedIDs: [1])[1])

        #expect(checks.checkDetails == [
            CheckDetail(name: "Travis CI - Pull Request", state: .failing, url: URL(string: "https://circleci.com/run/1")),
            CheckDetail(name: "Summary", state: .passing),
            CheckDetail(name: "Deploy preview", state: .pending),
            CheckDetail(name: "Lint (optional)", state: .noChecks),
            CheckDetail(name: "codecov/project", state: .passing, url: URL(string: "https://codecov.io/project/9")),
            CheckDetail(name: "codecov/patch", state: .pending),
        ])
    }

    @Test("cancelled and timed out check runs read as failing")
    func hardStopsReadAsFailing() throws {
        let data = Data("""
        {"data": {
            "pr0": {"pullRequest": {
                "reviewDecision": null,
                "commits": {"nodes": [{"commit": {"statusCheckRollup": {
                    "state": "FAILURE",
                    "contexts": {"nodes": [
                        {"__typename": "CheckRun", "name": "a", "conclusion": "CANCELLED"},
                        {"__typename": "CheckRun", "name": "b", "conclusion": "TIMED_OUT"},
                        {"__typename": "CheckRun", "name": "c", "conclusion": "ACTION_REQUIRED"}
                    ]}
                }}}]}
            }}
        }}
        """.utf8)

        let checks = try #require(try ChecksResponse.statuses(from: data, orderedIDs: [1])[1])

        #expect(checks.checkDetails.map(\.state) == [.failing, .failing, .failing])
    }

    @Test("a checks response decodes comment counts and recent commenters")
    func decodesComments() throws {
        let data = Data("""
        {"data": {
            "pr0": {"pullRequest": {
                "reviewDecision": null,
                "comments": {"totalCount": 7, "nodes": [{"author": {"login": "sam"}}, {"author": null}, {"author": {"login": "kit"}}]},
                "commits": {"nodes": [{"commit": {"statusCheckRollup": {"state": "SUCCESS"}}}]}
            }}
        }}
        """.utf8)

        let statuses = try ChecksResponse.statuses(from: data, orderedIDs: [111])

        #expect(statuses[111]?.commentCount == 7)
        #expect(statuses[111]?.recentCommenters == ["sam", "kit"])
    }

    @Test("missing comments decode as zero with no commenters")
    func missingCommentsDecodeAsZero() throws {
        let data = Data("""
        {"data": {"pr0": {"pullRequest": null}}}
        """.utf8)

        let statuses = try ChecksResponse.statuses(from: data, orderedIDs: [1])

        #expect(statuses[1]?.commentCount == 0)
        #expect(statuses[1]?.recentCommenters == [])
    }
}
