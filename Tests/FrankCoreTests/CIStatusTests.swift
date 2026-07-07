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

    @Test("a checks response decodes states keyed by pull request id")
    func decodesStatesKeyedByPullRequestId() throws {
        let ids = [111, 222]
        let data = Data("""
        {"data": {
            "pr0": {"pullRequest": {"commits": {"nodes": [
                {"commit": {"statusCheckRollup": {"state": "SUCCESS"}}}
            ]}}},
            "pr1": {"pullRequest": {"commits": {"nodes": [
                {"commit": {"statusCheckRollup": {"state": "FAILURE"}}}
            ]}}}
        }}
        """.utf8)

        let states = try ChecksResponse.states(from: data, orderedIDs: ids)

        #expect(states == [111: .passing, 222: .failing])
    }

    @Test("missing rollup, pull request or commits all mean no checks")
    func missingRollupMeansNoChecks() throws {
        let ids = [1, 2, 3]
        let data = Data("""
        {"data": {
            "pr0": {"pullRequest": {"commits": {"nodes": [
                {"commit": {"statusCheckRollup": null}}
            ]}}},
            "pr1": {"pullRequest": null},
            "pr2": {"pullRequest": {"commits": {"nodes": []}}}
        }}
        """.utf8)

        let states = try ChecksResponse.states(from: data, orderedIDs: ids)

        #expect(states == [1: .noChecks, 2: .noChecks, 3: .noChecks])
    }

    @Test("the query aliases every tracked pull request by repo and number")
    func queryCoversEveryTrackedPullRequest() {
        let query = ChecksQuery.build(for: [
            makePullRequest(id: 111, number: 42, repositoryFullName: "angie/frank"),
            makePullRequest(id: 222, number: 7, repositoryFullName: "octo-org/my.repo"),
        ])

        #expect(query.contains(#"pr0: repository(owner: "angie", name: "frank") { pullRequest(number: 42)"#))
        #expect(query.contains(#"pr1: repository(owner: "octo-org", name: "my.repo") { pullRequest(number: 7)"#))
        #expect(query.contains("statusCheckRollup"))
    }
}
