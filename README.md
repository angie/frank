<p align="center">
  <img src="assets/icon.png" width="128" alt="Frank, an engraved tortoise, ambling to the right">
</p>

<h1 align="center">Frank</h1>

<p align="center">
  <em>A mindful GitHub pull-request reporter for the macOS menu bar.<br>
  Slow and steady, tells you only what matters.</em>
</p>

<p align="center">
  <img alt="Swift 6" src="https://img.shields.io/badge/Swift-6-f38ba8?labelColor=1e1e2e">
  <img alt="macOS 15+" src="https://img.shields.io/badge/macOS-15%2B-a6e3a1?labelColor=1e1e2e">
  <img alt="Tests" src="https://img.shields.io/badge/tests-99-89b4fa?labelColor=1e1e2e">
</p>

---

Frank is a tortoise who lives in your menu bar and watches the pull requests you authored
or commented on. Most of the time he does nothing, which is the point. When something
changes that you'd want to know about, he taps you once. Nagging isn't in his nature;
chatter waits quietly for the digest.

## What Frank does

- **Sits quietly.** A hollow tortoise means all is well. He fills in when one of *your*
  PRs has failing CI or changes requested. Trouble on PRs you merely watch never
  grabs the bar.
- **Shows you everything in one panel.** Click him: PRs grouped into **Mine** and
  **Watching**, each row with the author's avatar, a pastel CI badge, approvals,
  coloured diff size and age. A `jira ↗` link opens the ticket; a dot-strip capsule
  unfolds into every check, and each failed check clicks through to its run.
- **Interrupts for exactly four things.** CI turning green, CI turning red, an approval,
  and changes requested. One tap per transition, none on first sighting, and an API
  outage can't make him fire twice.
- **Batches the chatter.** New comments from other people arrive as one digest per
  half hour. Your own comments never count.
- **Stays silent through restarts.** Seen-state persists to disk, so relaunching Frank
  never replays old news, while anything that happened whilst he was asleep fires
  exactly once.

Clicking a banner opens the PR. Digests open your pulls page.

## Running Frank

You need macOS 15 or later and an authenticated [`gh` CLI](https://cli.github.com).
Frank borrows its token, so setup ends there.

```sh
scripts/make-app.sh && open .build/Frank.app
```

The bundle wrapper matters because macOS 26 refuses both status items and notification
rights to bare executables. And if the tortoise seems missing after launch, look in your
menu bar manager's hidden section first.

To prove the notification plumbing without waiting for CI:

```sh
FRANK_TEST_NOTIFICATION="hello" .build/Frank.app/Contents/MacOS/Frank
```

## How he decides what's yours

When a PR body contains an Atlassian browse link, that link wins. Otherwise Frank reads
the ticket key from the title and reuses whichever Jira base he has already seen in your
other PRs, so the right instance emerges from your own data without configuration.

## Development

Core logic lives in `FrankCore` (polling, transition detection, digest buffering,
presenters), all pure and tested. The `Frank` target is a thin SwiftUI shell.

```sh
swift test
```

Changes go RED → GREEN → MUTATE → KILL MUTANTS → REFACTOR. Mutation testing is manual
for now: muter v1.3.0 misreports Swift Testing kills (fix pending in muter PR #306);
adopt it once released.

## Credits

The tortoise is a public-domain engraving from
[Openclipart](https://openclipart.org/detail/124111/tortoise), mirrored to face the
future. Regenerate the icon with `scripts/make-icon.sh`.

## Someday, at tortoise pace

- A coloured attention dot in the menu bar (needs a custom appearance-aware `NSImage`;
  the filled tortoise carries attention today)
- Quiet hours and Focus awareness; per-repo mute; a pin/watchlist; review-requested
  scope; launch at login; Sparkle-style updates
- The digest window resets on relaunch (worst case: one early digest after a restart)
