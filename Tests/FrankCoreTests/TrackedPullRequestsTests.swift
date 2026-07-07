import Foundation
import FrankCore
import Testing

@Suite("Tracked pull requests")
struct TrackedPullRequestsTests {
    @Test("a PR both authored and commented on appears once")
    func overlappingPullRequestAppearsOnce() {
        let authored = makePullRequest(id: 1, title: "From authored search")
        let sameFromCommented = makePullRequest(id: 1, title: "From commented search")

        let merged = PRScope.merge(authored: [authored], commented: [sameFromCommented])

        #expect(merged == [authored])
    }

    @Test("authored and commented-only PRs union, authored first")
    func disjointSetsUnion() {
        let authored = makePullRequest(id: 1)
        let commented = makePullRequest(id: 2)

        let merged = PRScope.merge(authored: [authored], commented: [commented])

        #expect(merged == [authored, commented])
    }

    @Test("PRs I only commented on are tracked even with nothing authored")
    func emptyAuthoredStillShowsCommented() {
        let commented = makePullRequest(id: 7)

        #expect(PRScope.merge(authored: [], commented: [commented]) == [commented])
    }

    @Test("distinct PRs with the same number in different repos both survive")
    func sameNumberDifferentReposBothSurvive() {
        let a = makePullRequest(id: 1, number: 42, repositoryFullName: "angie/one")
        let b = makePullRequest(id: 2, number: 42, repositoryFullName: "angie/two")

        #expect(PRScope.merge(authored: [a], commented: [b]).count == 2)
    }
}
