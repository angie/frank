import AppKit
import FrankCore
import SwiftUI

@main
struct FrankApp: App {
    @State private var monitor: PRMonitor

    init() {
        let client: any PullRequestSearching =
            (try? GitHubToken.fromGhCLI()).map(GitHubSearchClient.init(token:)) ?? UnauthenticatedClient()
        _monitor = State(initialValue: PRMonitor(client: client))
        NSApplication.shared.setActivationPolicy(.accessory)
    }

    var body: some Scene {
        MenuBarExtra {
            Text(MenuBarSummary.menuHeadline(for: monitor.state))
            if case .loaded(let pullRequests) = monitor.state, !pullRequests.isEmpty {
                Divider()
                ForEach(MenuRow.rows(for: pullRequests)) { row in
                    Button(row.text) { NSWorkspace.shared.open(row.url) }
                }
            }
            Divider()
            Button("Refresh Now") { Task { await monitor.poll() } }
            Button("Quit Frank") { NSApp.terminate(nil) }
        } label: {
            FrankMenuBarLabel(monitor: monitor)
        }
    }
}

private struct FrankMenuBarLabel: View {
    let monitor: PRMonitor

    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: "tortoise")
            if let text = MenuBarSummary.labelText(for: monitor.state) {
                Text(text)
            }
        }
        .task { await monitor.run() }
    }
}
