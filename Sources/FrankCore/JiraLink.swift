import Foundation

public enum JiraLink {
    public static func resolve(for pr: PullRequest, among all: [PullRequest]) -> URL? {
        if let direct = browseLink(in: pr.body) {
            return direct
        }
        let keyPattern = /\b[A-Z][A-Z0-9]+-\d+\b/
        guard let key = pr.title.firstMatch(of: keyPattern).map({ String($0.output) }) else {
            return nil
        }
        for other in all {
            guard let learned = browseLink(in: other.body) else { continue }
            let base = learned.absoluteString.components(separatedBy: "/browse/")[0]
            return URL(string: "\(base)/browse/\(key)")
        }
        return nil
    }

    private static func browseLink(in body: String?) -> URL? {
        let browsePattern = /https:\/\/[^\s\/)\]"'<>]+\/browse\/[A-Z][A-Z0-9]+-\d+/
        guard let body, let match = body.firstMatch(of: browsePattern) else { return nil }
        return URL(string: String(match.output))
    }
}
