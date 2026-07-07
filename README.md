<p align="center">
  <img src="assets/icon.png" width="128" alt="Frank's app icon: an engraved tortoise">
</p>

<h1 align="center">Frank</h1>

<p align="center">
  <em>A quiet GitHub pull-request reporter for the macOS menu bar.</em>
</p>

<p align="center">
  <img alt="Swift 6" src="https://img.shields.io/badge/Swift-6-f38ba8?labelColor=1e1e2e">
  <img alt="macOS 15+" src="https://img.shields.io/badge/macOS-15%2B-a6e3a1?labelColor=1e1e2e">
  <img alt="Tests" src="https://img.shields.io/badge/tests-99-89b4fa?labelColor=1e1e2e">
</p>

---

Frank watches the pull requests you authored or commented on and notifies you only when
something changes that you'd act on. Everything else waits in the panel until you ask.

## Features

- **Menu bar state.** Hollow tortoise: all fine. Filled: one of your own PRs has failing
  CI or changes requested. Watched PRs don't affect the icon.
- **Panel.** PRs grouped into Mine and Watching. Each row shows author avatar, CI badge,
  title, repo, approvals, coloured diff size, age, and a `jira ↗` link. A dot capsule
  expands into the individual checks, and failed ones click through to the run.
- **Notifications.** Four immediate triggers: CI passes, CI fails, approval, changes
  requested. One banner per transition, none on first sighting. Comments from other
  people batch into one digest per half hour. Your own don't count. Clicking a banner
  opens the PR.
- **Restart-safe.** Seen-state persists, so a relaunch replays nothing, and a transition
  that happened while quit fires once.

## Install

Requires macOS 15+ and an authenticated [`gh` CLI](https://cli.github.com); Frank
borrows its token.

```sh
scripts/make-app.sh && open .build/Frank.app
```

macOS won't grant a bare executable a status item or notification rights, so the build
script wraps one. If the tortoise doesn't appear, check your menu bar manager's hidden
section.

Test the notification plumbing without waiting for CI:

```sh
FRANK_TEST_NOTIFICATION="hello" .build/Frank.app/Contents/MacOS/Frank
```

## Jira links

A browse link in the PR body wins. Failing that, Frank combines the ticket key from the
title with a Jira base learned from your other PRs' bodies. No configuration and no
network validation.

## Development

Core logic lives in `FrankCore` (polling, transition detection, digest buffer,
presenters), all pure and tested; the `Frank` target is a thin SwiftUI shell.

```sh
swift test
```

Changes follow RED → GREEN → MUTATE → KILL MUTANTS → REFACTOR. Mutation testing is
manual until muter's Swift Testing fix (PR #306) gets released.

## Credits

Icon tortoise: public-domain engraving from
[Openclipart](https://openclipart.org/detail/124111/tortoise). Regenerate with
`scripts/make-icon.sh`.

## Roadmap

- Coloured attention dot in the menu bar (blocked on `MenuBarExtra` label rendering;
  needs a custom appearance-aware `NSImage`)
- Quiet hours / Focus awareness, per-repo mute, pin list, review-requested scope,
  launch at login, Sparkle updates
- Digest window resets on relaunch (worst case: one early digest)
