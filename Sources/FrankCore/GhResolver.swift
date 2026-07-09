/// Finds the `gh` executable without trusting the inherited PATH.
/// Login items get launchd's bare PATH, which lacks Homebrew, so the
/// PATH search is followed by the two Homebrew install locations.
public enum GhResolver {
    private static let fallbackDirectories = ["/opt/homebrew/bin", "/usr/local/bin"]

    public static func resolve(
        pathEnvironment: String?,
        isExecutableFile: (String) -> Bool
    ) -> String? {
        let pathDirectories = (pathEnvironment ?? "")
            .split(separator: ":")
            .map(String.init)
        for directory in pathDirectories + fallbackDirectories {
            let candidate = directory + "/gh"
            if isExecutableFile(candidate) {
                return candidate
            }
        }
        return nil
    }
}
