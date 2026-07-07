import AppKit
import FrankCore
import SwiftUI

@main
struct FrankApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
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
            FrankPanel(monitor: monitor)
        } label: {
            FrankMenuBarLabel(monitor: monitor)
        }
        .menuBarExtraStyle(.window)
    }
}

private struct FrankPanel: View {
    let monitor: PRMonitor

    var body: some View {
        VStack(spacing: 0) {
            content
            Divider()
            footer
        }
        .frame(width: 380)
    }

    @ViewBuilder
    private var content: some View {
        switch monitor.state {
        case .idle:
            PanelMessage(text: "Checking GitHub…")
        case .failed:
            PanelMessage(text: "Couldn't reach GitHub — Frank keeps trying")
        case .loaded(let pullRequests) where pullRequests.isEmpty:
            PanelMessage(text: "No open pull requests.\nFrank will let you know when something needs you.")
        case .loaded(let pullRequests):
            let sections = MenuSections.compute(
                for: pullRequests,
                statuses: monitor.statuses,
                authoredIDs: monitor.authoredIDs,
                now: Date()
            )
            if pullRequests.count > 12 {
                ScrollView {
                    sectionList(sections)
                }
                .frame(height: 480)
            } else {
                sectionList(sections)
            }
        }
    }

    private func sectionList(_ sections: MenuSections) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            if !sections.mine.isEmpty {
                SectionHeader(title: "Mine")
                ForEach(sections.mine) { PRRow(row: $0) }
            }
            if !sections.watching.isEmpty {
                SectionHeader(title: "Watching")
                    .padding(.top, sections.mine.isEmpty ? 0 : 8)
                ForEach(sections.watching) { PRRow(row: $0) }
            }
        }
        .padding(6)
        .frame(width: 380, alignment: .leading)
    }

    private var footer: some View {
        HStack {
            FooterButton(title: "Refresh Now") {
                Task { await monitor.poll() }
            }
            Spacer()
            FooterButton(title: "Quit Frank") {
                NSApp.terminate(nil)
            }
            .keyboardShortcut("q")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
    }
}

private struct PanelMessage: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 28)
            .padding(.horizontal, 16)
    }
}

private struct SectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
    }
}

private struct PRRow: View {
    let row: MenuRow
    @Environment(\.dismiss) private var dismiss
    @State private var hovering = false
    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            rowButton
            if expanded {
                checksList
            }
        }
    }

    private var rowButton: some View {
        Button {
            NSWorkspace.shared.open(row.url)
            dismiss()
        } label: {
            HStack(alignment: .center, spacing: 8) {
                avatar
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        ciIcon
                        Text(row.title)
                            .font(.system(size: 13, weight: .medium))
                            .lineLimit(1)
                            .truncationMode(.tail)
                        Text(verbatim: "#\(row.number)")
                            .font(.system(size: 13))
                            .foregroundStyle(.tertiary)
                        Spacer(minLength: 0)
                    }
                    HStack(spacing: 8) {
                        Text(row.repoShortName)
                        if row.approvals > 0 {
                            Text("✓ \(row.approvals)")
                        }
                        if row.additions + row.deletions > 0 {
                            HStack(spacing: 3) {
                                Text("+\(row.additions)").foregroundStyle(Catppuccin.green)
                                Text("−\(row.deletions)").foregroundStyle(Catppuccin.red)
                            }
                        }
                        if let age = row.age {
                            Text(age)
                        }
                        Spacer(minLength: 0)
                        if let jiraURL = row.jiraURL {
                            JiraLinkText(url: jiraURL)
                        }
                        if !row.checkDetails.isEmpty {
                            checksCapsule
                        }
                    }
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(hovering ? Color.primary.opacity(0.07) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }

    private var checksCapsule: some View {
        Button {
            withAnimation(.easeOut(duration: 0.15)) { expanded.toggle() }
        } label: {
            HStack(spacing: 4) {
                HStack(spacing: 3) {
                    ForEach(Array(row.checkDetails.prefix(6).enumerated()), id: \.offset) { _, check in
                        Circle()
                            .fill(dotColor(for: check.state))
                            .frame(width: 5, height: 5)
                    }
                    if row.checkDetails.count > 6 {
                        Text("+\(row.checkDetails.count - 6)")
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                            .fixedSize()
                    }
                }
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.secondary)
                    .rotationEffect(expanded ? .degrees(180) : .zero)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Capsule().fill(Color.primary.opacity(0.08)))
            .fixedSize()
        }
        .buttonStyle(.plain)
        .help(expanded ? "Hide checks" : "Show checks")
    }

    private var checksList: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(row.checkDetails.enumerated()), id: \.offset) { _, check in
                CheckRowView(check: check, color: dotColor(for: check.state))
            }
        }
        .padding(.leading, 46)
        .padding(.trailing, 8)
        .padding(.top, 1)
        .padding(.bottom, 5)
    }

    private func dotColor(for state: CIState) -> Color {
        switch state {
        case .passing:
            return Catppuccin.green
        case .failing:
            return Catppuccin.red
        case .pending:
            return Catppuccin.peach
        case .noChecks:
            return Color.secondary.opacity(0.4)
        }
    }

    private var avatar: some View {
        AsyncImage(url: row.avatarURL) { image in
            image.resizable()
        } placeholder: {
            Circle()
                .fill(.quaternary)
                .overlay(
                    Image(systemName: "person.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                )
        }
        .frame(width: 22, height: 22)
        .clipShape(Circle())
    }

    @ViewBuilder
    private var ciIcon: some View {
        switch row.ci {
        case .passing:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 11))
                .foregroundStyle(Catppuccin.green)
        case .failing:
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 11))
                .foregroundStyle(Catppuccin.red)
        case .pending:
            Image(systemName: "clock.fill")
                .font(.system(size: 11))
                .foregroundStyle(Catppuccin.peach)
        case .noChecks:
            EmptyView()
        }
    }
}

private struct JiraLinkText: View {
    let url: URL
    @Environment(\.dismiss) private var dismiss
    @State private var hovering = false

    var body: some View {
        Button {
            NSWorkspace.shared.open(url)
            dismiss()
        } label: {
            Text("jira ↗")
                .font(.system(size: 11))
                .foregroundStyle(Catppuccin.blue)
                .underline(hovering)
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help("Open Jira ticket")
    }
}

private struct CheckRowView: View {
    let check: CheckDetail
    let color: Color
    @Environment(\.dismiss) private var dismiss
    @State private var hovering = false

    var body: some View {
        if let url = check.url {
            Button {
                NSWorkspace.shared.open(url)
                dismiss()
            } label: {
                label.underline(hovering)
            }
            .buttonStyle(.plain)
            .onHover { hovering = $0 }
            .help("Open this run")
        } else {
            label
        }
    }

    private var label: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(check.name)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }
}

private struct FooterButton: View {
    let title: String
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12))
                .foregroundStyle(hovering ? .primary : .secondary)
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
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
