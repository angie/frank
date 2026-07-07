import Foundation

public struct PullRequest: Equatable, Sendable, Identifiable {
    public let id: Int
    public let number: Int
    public let title: String
    public let repositoryFullName: String
    public let htmlURL: URL
    public let updatedAt: Date

    public init(id: Int, number: Int, title: String, repositoryFullName: String, htmlURL: URL, updatedAt: Date) {
        self.id = id
        self.number = number
        self.title = title
        self.repositoryFullName = repositoryFullName
        self.htmlURL = htmlURL
        self.updatedAt = updatedAt
    }
}

extension PullRequest: Decodable {
    private enum CodingKeys: String, CodingKey {
        case id, number, title
        case htmlURL = "html_url"
        case repositoryURL = "repository_url"
        case updatedAt = "updated_at"
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        number = try container.decode(Int.self, forKey: .number)
        title = try container.decode(String.self, forKey: .title)
        htmlURL = try container.decode(URL.self, forKey: .htmlURL)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)

        let repositoryURL = try container.decode(String.self, forKey: .repositoryURL)
        guard let range = repositoryURL.range(of: "/repos/") else {
            throw DecodingError.dataCorruptedError(
                forKey: .repositoryURL,
                in: container,
                debugDescription: "Expected a /repos/ path in repository_url: \(repositoryURL)"
            )
        }
        repositoryFullName = String(repositoryURL[range.upperBound...])
    }
}

public struct GitHubSearchResponse: Decodable, Sendable {
    public let items: [PullRequest]

    public static func decode(_ data: Data) throws -> GitHubSearchResponse {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(GitHubSearchResponse.self, from: data)
    }
}
