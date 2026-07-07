import AppKit
import LanternCore
import SwiftUI

@main
struct LanternApp: App {
    @State private var monitor: PRMonitor

    init() {
        let client: any PullRequestSearching =
            (try? GitHubToken.fromGhCLI()).map(GitHubSearchClient.init(token:)) ?? UnauthenticatedClient()
        _monitor = State(initialValue: PRMonitor(client: client))
        NSApplication.shared.setActivationPolicy(.accessory)
    }

    var body: some Scene {
        MenuBarExtra {
            Button("Quit Lantern") { NSApp.terminate(nil) }
        } label: {
            LanternMenuBarLabel(monitor: monitor)
        }
    }
}

private struct LanternMenuBarLabel: View {
    let monitor: PRMonitor

    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: "light.beacon.max")
            if let text = MenuBarSummary.labelText(for: monitor.state) {
                Text(text)
            }
        }
        .task { await monitor.run() }
    }
}
