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

enum GitHubToken {
    static func fromGhCLI() throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["gh", "auth", "token"]
        let stdout = Pipe()
        process.standardOutput = stdout
        process.standardError = Pipe()
        try process.run()
        process.waitUntilExit()

        let output = String(decoding: stdout.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        let token = output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard process.terminationStatus == 0, !token.isEmpty else {
            throw URLError(.userAuthenticationRequired)
        }
        return token
    }
}

struct UnauthenticatedClient: PullRequestSearching {
    func openAuthoredPullRequests() async throws -> [PullRequest] {
        throw URLError(.userAuthenticationRequired)
    }

    func openCommentedPullRequests() async throws -> [PullRequest] {
        throw URLError(.userAuthenticationRequired)
    }
}
