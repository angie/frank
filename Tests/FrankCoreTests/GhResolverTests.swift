import FrankCore
import Testing

@Suite("Resolving the gh executable")
struct GhResolverTests {
    @Test("gh is found in a PATH directory")
    func foundInPath() {
        let resolved = GhResolver.resolve(
            pathEnvironment: "/somewhere/bin",
            isExecutableFile: { $0 == "/somewhere/bin/gh" }
        )
        #expect(resolved == "/somewhere/bin/gh")
    }

    @Test("the first matching PATH directory wins")
    func firstPathDirectoryWins() {
        let resolved = GhResolver.resolve(
            pathEnvironment: "/first/bin:/second/bin",
            isExecutableFile: { $0 == "/first/bin/gh" || $0 == "/second/bin/gh" }
        )
        #expect(resolved == "/first/bin/gh")
    }

    @Test("PATH wins over the Homebrew fallbacks")
    func pathWinsOverFallbacks() {
        let resolved = GhResolver.resolve(
            pathEnvironment: "/somewhere/bin",
            isExecutableFile: { $0 == "/somewhere/bin/gh" || $0 == "/opt/homebrew/bin/gh" }
        )
        #expect(resolved == "/somewhere/bin/gh")
    }

    @Test("a bare launchd PATH falls back to Apple silicon Homebrew")
    func fallsBackToHomebrew() {
        let resolved = GhResolver.resolve(
            pathEnvironment: "/usr/bin:/bin:/usr/sbin:/sbin",
            isExecutableFile: { $0 == "/opt/homebrew/bin/gh" }
        )
        #expect(resolved == "/opt/homebrew/bin/gh")
    }

    @Test("Apple silicon Homebrew is preferred over Intel Homebrew")
    func appleSiliconPreferred() {
        let resolved = GhResolver.resolve(
            pathEnvironment: nil,
            isExecutableFile: { $0 == "/opt/homebrew/bin/gh" || $0 == "/usr/local/bin/gh" }
        )
        #expect(resolved == "/opt/homebrew/bin/gh")
    }

    @Test("Intel Homebrew is found when Apple silicon Homebrew is absent")
    func intelHomebrewFallback() {
        let resolved = GhResolver.resolve(
            pathEnvironment: nil,
            isExecutableFile: { $0 == "/usr/local/bin/gh" }
        )
        #expect(resolved == "/usr/local/bin/gh")
    }

    @Test("a missing PATH still finds the fallbacks")
    func nilPathStillResolves() {
        let resolved = GhResolver.resolve(
            pathEnvironment: nil,
            isExecutableFile: { $0 == "/opt/homebrew/bin/gh" }
        )
        #expect(resolved == "/opt/homebrew/bin/gh")
    }

    @Test("nothing executable anywhere resolves to nil")
    func nothingFound() {
        let resolved = GhResolver.resolve(
            pathEnvironment: "/usr/bin:/bin",
            isExecutableFile: { _ in false }
        )
        #expect(resolved == nil)
    }

    @Test("empty PATH segments never produce a bare /gh candidate")
    func emptySegmentsSkipped() {
        var probed: [String] = []
        _ = GhResolver.resolve(
            pathEnvironment: "::/somewhere/bin:",
            isExecutableFile: { probed.append($0); return false }
        )
        #expect(!probed.contains("/gh"))
        #expect(probed.contains("/somewhere/bin/gh"))
    }
}
