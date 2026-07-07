import Foundation

public enum PRScope {
    public static func merge(authored: [PullRequest], commented: [PullRequest]) -> [PullRequest] {
        var seen = Set<Int>()
        return (authored + commented).filter { seen.insert($0.id).inserted }
    }
}
