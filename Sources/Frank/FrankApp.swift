import AppKit
import FrankCore
import SwiftUI

@main
struct FrankApp: App {
    @State private var monitor: PRMonitor

    init() {
        let monitor: PRMonitor
        if let token = try? GitHubToken.fromGhCLI() {
            let stateURL = FileManager.default
                .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("Frank/state.json")
            monitor = PRMonitor(
                client: GitHubSearchClient(token: token),
                checks: GitHubChecksClient(token: token),
                notifier: UNNotifier(),
                selfLogin: GitHubViewer.login(),
                store: FileSnapshotStore(fileURL: stateURL)
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
                let sections = MenuSections.compute(
                    for: pullRequests,
                    statuses: monitor.statuses,
                    authoredIDs: monitor.authoredIDs,
                    now: Date()
                )
                if !sections.mine.isEmpty {
                    Section("Mine") {
                        ForEach(sections.mine) { PRRowButton(row: $0) }
                    }
                }
                if !sections.watching.isEmpty {
                    Section("Watching") {
                        ForEach(sections.watching) { PRRowButton(row: $0) }
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

private struct PRRowButton: View {
    let row: MenuRow

    var body: some View {
        Button {
            NSWorkspace.shared.open(row.url)
        } label: {
            if let symbol = row.ciSymbolName {
                Label(row.text, systemImage: symbol)
            } else {
                Text(row.text)
            }
            if let detail = row.detail {
                Text(detail)
            }
        }
    }
}

private struct FrankMenuBarLabel: View {
    let monitor: PRMonitor

    private var tortoiseSymbol: String {
        let aggregate = AggregateState.compute(from: monitor.statuses, authoredIDs: monitor.authoredIDs)
        return aggregate == .calm ? "tortoise" : "tortoise.fill"
    }

    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: tortoiseSymbol)
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
