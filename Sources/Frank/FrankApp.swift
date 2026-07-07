import AppKit
import FrankCore
import SwiftUI

@main
struct FrankApp: App {
    @State private var monitor: PRMonitor

    init() {
        let monitor: PRMonitor
        if let token = try? GitHubToken.fromGhCLI() {
            monitor = PRMonitor(
                client: GitHubSearchClient(token: token),
                checks: GitHubChecksClient(token: token),
                notifier: UNNotifier()
            )
        } else {
            monitor = PRMonitor(client: UnauthenticatedClient())
        }
        _monitor = State(initialValue: monitor)
        NSApplication.shared.setActivationPolicy(.accessory)
    }

    var body: some Scene {
        MenuBarExtra {
            Text(MenuBarSummary.menuHeadline(for: monitor.state))
            if case .loaded(let pullRequests) = monitor.state, !pullRequests.isEmpty {
                Divider()
                ForEach(MenuRow.rows(for: pullRequests, ciStates: monitor.ciStates)) { row in
                    Button {
                        NSWorkspace.shared.open(row.url)
                    } label: {
                        if let symbol = row.ciSymbolName {
                            Label(row.text, systemImage: symbol)
                        } else {
                            Text(row.text)
                        }
                    }
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
        .task {
            await UNNotifier.requestPermission()
            if ProcessInfo.processInfo.environment["FRANK_TEST_NOTIFICATION"] != nil {
                await UNNotifier().post(NotificationContent(
                    title: "🐢 Frank is watching",
                    body: "Notification plumbing works",
                    url: URL(string: "https://github.com")!
                ))
            }
            await monitor.run()
        }
    }
}
