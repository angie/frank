import Foundation
import FrankCore

struct GitHubSearchClient: PullRequestSearching {
    let token: String

    func openAuthoredPullRequests() async throws -> [PullRequest] {
        try await search(query: "is:pr is:open author:@me")
    }

    func openCommentedPullRequests() async throws -> [PullRequest] {
        try await search(query: "is:pr is:open commenter:@me")
    }

    private func search(query: String) async throws -> [PullRequest] {
        var components = URLComponents(string: "https://api.github.com/search/issues")!
        components.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "per_page", value: "100"),
        ]
        var request = URLRequest(url: components.url!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        return try GitHubSearchResponse.decode(data).items
    }
}

struct GitHubChecksClient: ChecksFetching {
    let token: String

    func statuses(for pullRequests: [PullRequest]) async throws -> [Int: PRChecks] {
        guard !pullRequests.isEmpty else { return [:] }
        var request = URLRequest(url: URL(string: "https://api.github.com/graphql")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(["query": ChecksQuery.build(for: pullRequests)])

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        return try ChecksResponse.statuses(from: data, orderedIDs: pullRequests.map(\.id))
    }
}

enum GitHubCLI {
    static func run(_ arguments: [String]) throws -> String {
        guard let gh = GhResolver.resolve(
            pathEnvironment: ProcessInfo.processInfo.environment["PATH"],
            isExecutableFile: { FileManager.default.isExecutableFile(atPath: $0) }
        ) else {
            throw NotAuthenticated()
        }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: gh)
        process.arguments = arguments
        let stdout = Pipe()
        process.standardOutput = stdout
        process.standardError = Pipe()
        try process.run()
        process.waitUntilExit()

        let output = String(decoding: stdout.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        let result = output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard process.terminationStatus == 0, !result.isEmpty else {
            throw NotAuthenticated()
        }
        return result
    }
}

enum GitHubToken {
    static func fromGhCLI() throws -> String {
        try GitHubCLI.run(["auth", "token"])
    }
}

enum GitHubViewer {
    static func login() -> String? {
        try? GitHubCLI.run(["api", "user", "--jq", ".login"])
    }
}

struct UnauthenticatedClient: PullRequestSearching {
    func openAuthoredPullRequests() async throws -> [PullRequest] {
        throw NotAuthenticated()
    }

    func openCommentedPullRequests() async throws -> [PullRequest] {
        throw NotAuthenticated()
    }
}
