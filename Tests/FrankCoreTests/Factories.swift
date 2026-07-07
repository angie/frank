import Foundation
import FrankCore

func makePullRequest(
    id: Int = 111,
    number: Int = 42,
    title: String = "Add mindful notifications",
    repositoryFullName: String = "angie/pr-frank",
    htmlURL: URL = URL(string: "https://github.com/angie/pr-frank/pull/42")!,
    updatedAt: Date = Date(timeIntervalSince1970: 1_780_000_000)
) -> PullRequest {
    PullRequest(
        id: id,
        number: number,
        title: title,
        repositoryFullName: repositoryFullName,
        htmlURL: htmlURL,
        updatedAt: updatedAt
    )
}
