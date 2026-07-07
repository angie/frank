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
            switch monitor.state {
            case .idle:
                Text("Checking GitHub…")
            case .failed:
                Text("Couldn't reach GitHub")
            case .loaded(let pullRequests) where pullRequests.isEmpty:
                Text("No open pull requests")
            case .loaded(let pullRequests):
                ForEach(MenuRow.rows(for: pullRequests)) { row in
                    Button(row.text) { NSWorkspace.shared.open(row.url) }
                }
            }
            Divider()
            Button("Refresh Now") { Task { await monitor.poll() } }
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
