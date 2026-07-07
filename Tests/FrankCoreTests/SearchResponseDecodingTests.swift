import Foundation
import FrankCore
import Testing

private func searchResponseData(repositoryURL: String = "https://api.github.com/repos/angie/pr-frank") -> Data {
    Data("""
    {
      "total_count": 2,
      "incomplete_results": false,
      "items": [
        {
          "id": 111,
          "number": 42,
          "title": "Add mindful notifications",
          "html_url": "https://github.com/angie/pr-frank/pull/42",
          "repository_url": "\(repositoryURL)",
          "updated_at": "2026-07-01T10:00:00Z",
          "user": { "login": "angie", "avatar_url": "https://avatars.githubusercontent.com/u/1?v=4" },
          "pull_request": { "url": "https://api.github.com/repos/angie/pr-frank/pulls/42" }
        },
        {
          "id": 222,
          "number": 7,
          "title": "Fix flaky poller",
          "html_url": "https://github.com/octo-org/my.repo/pull/7",
          "repository_url": "https://api.github.com/repos/octo-org/my.repo",
          "updated_at": "2026-06-30T08:30:00Z",
          "pull_request": { "url": "https://api.github.com/repos/octo-org/my.repo/pulls/7" }
        }
      ]
    }
    """.utf8)
}

private func isoDate(_ string: String) -> Date {
    ISO8601DateFormatter().date(from: string)!
}

@Suite("Decoding GitHub PR search results")
struct SearchResponseDecodingTests {
    @Test("a search response yields pull requests with repo, title, number, url and updated date")
    func decodesPullRequests() throws {
        let response = try GitHubSearchResponse.decode(searchResponseData())

        #expect(response.items.count == 2)

        let first = try #require(response.items.first)
        #expect(first.id == 111)
        #expect(first.number == 42)
        #expect(first.title == "Add mindful notifications")
        #expect(first.repositoryFullName == "angie/pr-frank")
        #expect(first.htmlURL == URL(string: "https://github.com/angie/pr-frank/pull/42"))
        #expect(first.updatedAt == isoDate("2026-07-01T10:00:00Z"))
        #expect(first.authorLogin == "angie")
        #expect(first.avatarURL == URL(string: "https://avatars.githubusercontent.com/u/1?v=4"))

        let second = try #require(response.items.last)
        #expect(second.authorLogin == nil)
        #expect(second.id == 222)
        #expect(second.number == 7)
        #expect(second.repositoryFullName == "octo-org/my.repo")
        #expect(second.updatedAt == isoDate("2026-06-30T08:30:00Z"))
    }

    @Test("a repository_url without a /repos/ path is rejected")
    func rejectsRepositoryURLWithoutReposPath() {
        let data = searchResponseData(repositoryURL: "https://api.github.com/not-repos/angie/pr-frank")
        #expect(throws: DecodingError.self) {
            try GitHubSearchResponse.decode(data)
        }
    }
}
