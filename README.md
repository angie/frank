# Frank 🐢

Frank is a mindful GitHub PR status reporter that lives in the macOS menu bar. A tortoise
keeps an eye on the pull requests you authored or commented on, and interrupts you only
when something genuinely changes.

## What Frank tells you

- **Menu bar tortoise** — hollow when all is calm; filled when something needs attention
  (failing CI or changes requested). A dash appears beside him when GitHub is unreachable.
- **The panel** — click the tortoise for a rich dropdown: PRs grouped into **Mine** and
  **Watching**, each row with author avatar, Catppuccin-pastel CI badge, title, repo,
  approvals, coloured +/− diff size and age. Click a row to open the PR; a right-aligned
  `jira ↗` link opens the ticket (resolved from a browse link in the PR body, or the
  title's ticket key plus a Jira base learned from sibling PRs).
- **Immediate banners** (the interruption tier): CI flips to passing or failing, approvals,
  and changes-requested — once per transition, never on first sighting, never repeated.
- **Comment digests** (the calm tier): new comments from other people accumulate into one
  banner per half-hour window. Your own comments never count.
- **Restart silence** — the status snapshot persists to
  `~/Library/Application Support/Frank/state.json`, so relaunching never replays old
  notifications, while a transition that happened whilst quit still fires exactly once.

## Running

Requires macOS 15+ and an authenticated [`gh` CLI](https://cli.github.com) (Frank borrows
its token via `gh auth token`).

```sh
scripts/make-app.sh && open .build/Frank.app
```

The bundle wrapper matters: on macOS 26 a bare SPM executable gets neither a status item
nor notification rights. If the tortoise seems missing, check your menu bar manager's
hidden section (Barbee parks new items off-screen by default).

To verify notification plumbing without waiting for CI:

```sh
FRANK_TEST_NOTIFICATION=1 .build/Frank.app/Contents/MacOS/Frank
```

## Development

Core logic lives in `FrankCore` (poll monitor, transition detection, digest buffer,
presenters — all pure and tested); the `Frank` target is a thin SwiftUI/adapter shell.

```sh
swift test
```

Changes follow RED → GREEN → MUTATE → KILL MUTANTS → REFACTOR. Mutation testing is manual
for now: muter v1.3.0 misreports Swift Testing kills as runtime errors (fix pending in
muter PR #306 — adopt it once released).

## Later ideas

- A subtle coloured attention dot in the menu bar — `MenuBarExtra` labels fight this:
  emoji render huge, shapes get template-stripped, font/transform sizing is ignored;
  needs a custom appearance-aware `NSImage` (the filled tortoise carries attention today)
- Clicking a banner opens the PR (URL already rides in `userInfo`; needs a
  `UNUserNotificationCenter` delegate)
- Per-check detail on each row (PullBar-style submenu of individual check suites)
- A `defaults` override for the Jira base, for when no PR body carries a browse link
- Quiet hours / Focus awareness; per-repo mute; explicit pin/watchlist;
  review-requested scope; launch at login; app icon; Sparkle-style updates
- Digest window resets on relaunch (worst case: one early digest after a restart)
