# Plan: Mindful PR Notifications (Frank)

**Branch**: main (trunk-based; one slice = one small merge to main)
**Status**: Active

## Goal

A calm macOS menu bar app that watches GitHub PRs I authored or commented on, and surfaces only meaningful state transitions — CI flips, approvals, and changes-requested immediately; comments as batched digests — never repeat-nagging.

## Context & Decisions

- **Stack**: Swift 6.2 + SwiftUI `MenuBarExtra`. Core logic lives in an SPM library target (`FrankCore`) tested with `swift test`; the app shell (`Frank` executable target) stays thin.
- **Data**: Poll GitHub every ~60s using the token from `gh auth token` (already authenticated as `angie`, repo scope). REST search API for PR discovery; GraphQL `statusCheckRollup` once CI state is needed.
- **PR scope**: `is:pr is:open author:@me` plus `is:pr is:open commenter:@me`, deduped.
- **Philosophy**: tiered urgency. Immediate: CI pass→fail / fail→pass, approval, changes-requested. Digest: comments. Notify on transitions only; the menu bar glyph reflects aggregate state at all times.
- **Known constraint**: the app must run from a real `.app` bundle. `UNUserNotificationCenter` requires one, and on macOS 26 a bare SPM executable's status item did not appear in our testing. `scripts/make-app.sh` (added during slice 1) wraps the build in a minimal bundle (Info.plist, `LSUIElement`, ad-hoc codesign); launch with `scripts/make-app.sh && open .build/Frank.app`.
- **Menu bar managers**: Barbee hides new status items by default (parks them off-screen, x ≈ -8400). Verify presence via Accessibility (`menu bar 2` of the app's process in System Events), not by screenshot alone; pin Frank visible in Barbee.
- **Mutation testing**: muter v1.3.0 misreports Swift Testing kills as `runtimeError` (XCTest-only output regex; fix open as muter PR #306, June 2026). Use manual mutation per the `mutation-testing` skill; re-check #306 at each MUTATE phase and adopt muter once a release contains the fix.
- **Name & identity**: "Frank" — a tortoise (SF Symbol `tortoise`) who reports frankly on PRs that are slowing you down. Calm label shows the bare tortoise; "–" on poll failure; counts live in the menu headline. An attention dot on the tortoise arrives with the attention states (slices 4–8) in place of any number in the bar.

## Acceptance Criteria

- [ ] Menu bar shows an at-a-glance aggregate of my open PRs' health
- [ ] PRs I authored and PRs I commented on are both tracked
- [ ] CI fail→pass and pass→fail produce an immediate notification, once per transition
- [ ] Approval and changes-requested produce an immediate notification, once per event
- [ ] New comments accumulate and surface as a periodic digest, never individually
- [ ] Nothing re-notifies after an app restart (seen-state persists)
- [ ] Clicking a PR in the menu opens it in the browser

## Slices

Every slice follows RED-GREEN-MUTATE-KILL MUTANTS-REFACTOR. No production code without a failing test. Load `tdd`, `testing`, `mutation-testing`, `refactoring` before each slice; present the slice's acceptance criteria and wait for approval before writing code.

### Slice 1: Menu bar shows the live count of my open authored PRs, refreshed every 60s

**Value**: Angie glances at the menu bar and knows how many PRs she has in flight, without opening GitHub.
**Path**: App launch → read token via `gh auth token` → GET `search/issues?q=is:pr+is:open+author:@me` → decode into `PullRequest` models → `MenuBarExtra` label renders the count → timer repeats every 60s. Skipped states: API errors render as `–` (no retry logic yet).
**Follow pattern**: None — new project. Establish: SPM package with `FrankCore` (library, tested) + `Frank` (executable, thin), Swift Testing (`@Test`) style.
**Acceptance criteria**: Running `swift run Frank` puts an item in the menu bar showing the number of open PRs authored by me; the number changes within ~60s of opening/closing a PR; `swift test` passes; decoding and count-presentation logic covered by tests. GitHub client is behind a protocol seam so tests never hit the network.
**RED**: Failing tests for: decoding a GitHub search response fixture into `[PullRequest]`; presenter mapping `[PullRequest]` → menu bar label text (0 → calm idle glyph text, n → "n"); poll scheduler asking the client at the configured interval (fake clock). Mutant watch: boundary on empty list, interval constant, dropped-error path.
**GREEN**: `PullRequest` model + `Codable` decoding, `GitHubSearchClient` (URLSession, token from `gh auth token` via one `Process` call at startup), `PRSummaryPresenter`, `MenuBarExtra` shell wiring.
**MUTATE / KILL MUTANTS / REFACTOR**: per skills.
**Done when**: Count visible in the menu bar against the real GitHub account; tests green; mutation report reviewed; commit approved.

### Slice 2: The menu lists each PR (repo, title) and clicking one opens it in the browser

**Value**: The menu bar item becomes a launchpad — see what's in flight, jump straight to a PR.
**Path**: Click menu bar item → SwiftUI menu renders one row per PR (repo short name, title) → click row → `NSWorkspace.shared.open(url)`. Plus Refresh-now and Quit items. Empty state: "No open PRs" row.
**Follow pattern**: Slice 1's presenter/test style.
**Acceptance criteria**: Menu shows all my open authored PRs with repo and title; clicking a row opens the PR's `html_url` in the default browser; empty state renders; row-model logic tested.
**RED**: Failing tests for row-model mapping (`PullRequest` → title/subtitle/url), ordering (most recently updated first), empty-state model. Mutant watch: sort direction, URL passthrough.
**GREEN**: `MenuRowModel` mapping in `FrankCore`; SwiftUI menu content + open-URL action in shell.
**Done when**: Real PRs listed and clickable; tests green; commit approved.

### Slice 3: PRs I commented on are tracked alongside authored ones

**Value**: PRs where Angie is participating (not just authoring) show up — the full "things I care about" set.
**Path**: Poll now issues both searches (`author:@me`, `commenter:@me`), merges and dedupes by PR id, then flows through the existing presenter/menu path unchanged.
**Follow pattern**: `GitHubSearchClient` from slice 1.
**Acceptance criteria**: A PR I only commented on appears in the menu; a PR I authored *and* commented on appears once; count reflects the deduped union.
**RED**: Failing tests for union/dedupe (overlap, disjoint, one source empty), and that both queries are issued. Mutant watch: dedupe key, dropped second query.
**GREEN**: `PRScope` merge logic in `FrankCore`; client issues two searches.
**Done when**: Commented-on PR visible in the real menu; tests green; commit approved.

### Slice 4: Each menu row shows its PR's CI rollup state (passing / failing / pending)

**Value**: One glance tells Angie which PRs are red without opening CI.
**Path**: After search, one GraphQL query fetches `statusCheckRollup` for all tracked PRs → `CIState` per PR (`passing`/`failing`/`pending`/`none`) → glyph per menu row.
**Follow pattern**: Client seam + presenter style from slices 1–2.
**Acceptance criteria**: Rows show a state glyph matching the PR's actual check rollup; PRs with no checks show no glyph; rollup decoding and state mapping tested against fixtures.
**RED**: Failing tests for GraphQL response decoding, rollup → `CIState` mapping (SUCCESS/FAILURE/PENDING/ERROR/EXPECTED/null), row-model glyph selection. Mutant watch: enum case swaps, null handling.
**GREEN**: `GitHubChecksClient` (GraphQL), `CIState`, row-model extension.
**Done when**: Real red/green states match GitHub; tests green; commit approved.

### Slice 5: CI flips (pass→fail, fail→pass) fire an immediate notification, once per transition

**Value**: Angie learns the moment a PR unblocks or breaks — the two events most worth an interruption.
**Path**: Each poll diffs new `CIState` against previous snapshot → `Transition` events → notification policy classifies as immediate → `UNUserNotificationCenter` banner ("✅ CI passing on repo#123" / "❌ CI failing…"). The `.app` bundle enabler already exists (`scripts/make-app.sh`, pulled into slice 1 when the bare executable's status item failed to appear); this slice only requests notification permission and posts banners.
**Follow pattern**: Presenter/test seams from earlier slices; notification centre behind a protocol.
**Acceptance criteria**: A PR whose checks go red then green produces exactly two banners (fail, then pass); same-state polls produce none; first sighting of a PR produces none (no baseline spam); transition detector fully unit-tested with a spy notifier. In-memory snapshot only — restart re-baselines silently (persistence is slice 8).
**RED**: Failing tests for `TransitionDetector` (nil→state = baseline not transition, state→same = nothing, pass→fail and fail→pass = events, pending involvement), policy routing transitions to the immediate lane, notification content formatting. Mutant watch: direction swap, baseline suppression, duplicate-fire.
**GREEN**: `TransitionDetector`, `NotificationPolicy` (immediate lane only), `UserNotifier` protocol + UN adapter, bundle script.
**Done when**: Real CI flip produces one banner; tests green; commit approved.

### Slice 6: Approvals and changes-requested fire an immediate notification

**Value**: Review verdicts unblock (or redirect) work, so they interrupt — the second half of the immediate tier.
**Path**: Extend the GraphQL query with `reviewDecision` / latest reviews → diff against snapshot → `.approved` / `.changesRequested` transitions → immediate lane → banner ("👍 angie-reviewer approved repo#123").
**Follow pattern**: `TransitionDetector` + policy from slice 5.
**Acceptance criteria**: An approval on a tracked PR produces exactly one banner; changes-requested likewise; re-polls produce none; detector and formatting tested.
**RED**: Failing tests for review-decision decoding, review transitions (none→approved, approved→changesRequested, no-change), content formatting. Mutant watch: decision-enum swaps, duplicate suppression.
**GREEN**: Extend checks query + detector + policy.
**Done when**: Real approval produces one banner; tests green; commit approved.

### Slice 7: New comments accumulate into a periodic digest notification

**Value**: Conversation stays visible without ever interrupting — the calm tier.
**Path**: Poll tracks comment counts / latest comment per PR → new comments enqueue in `DigestBuffer` → every digest interval (default 30 min, only if non-empty) one summary banner ("💬 5 new comments across 3 PRs") → buffer clears. Own comments excluded.
**Follow pattern**: Policy/notifier seams from slices 5–6.
**Acceptance criteria**: Multiple comments inside one window produce exactly one digest banner at the tick; empty windows produce nothing; my own comments never enqueue; buffer and scheduling tested with a fake clock.
**RED**: Failing tests for enqueue/flush, empty-window suppression, self-comment exclusion, digest text (counts, PR grouping). Mutant watch: off-by-one on counts, flush-clears-buffer, interval constant.
**GREEN**: `DigestBuffer`, digest lane in `NotificationPolicy`, digest formatter.
**Done when**: Two test comments yield one digest banner at the tick; tests green; commit approved.

### Slice 8: Aggregate menu bar glyph + seen-state persists across restarts (no repeat-nag, ever)

**Value**: The icon itself becomes the calm summary (all-clear / attention / red), and relaunching the app never replays old notifications.
**Path**: Aggregate state = worst-of tracked PRs (any failing → red dot, any changes-requested → attention, else calm) → `MenuBarExtra` glyph. Snapshot (CI states, review decisions, comment high-water marks) serialises to `~/Library/Application Support/Frank/state.json` after each poll; loaded at launch as the baseline.
**Follow pattern**: Presenter + snapshot types from earlier slices.
**Acceptance criteria**: Glyph reflects worst state and updates on poll; after quit+relaunch with unchanged GitHub state, zero notifications fire; a transition that happened *while quit* fires exactly once on next poll; round-trip and aggregation tested.
**RED**: Failing tests for worst-of aggregation (orderings, empty set), snapshot round-trip, relaunch-suppression (persisted baseline → no events), missed-transition-fires-once. Mutant watch: severity ordering, load-fallback-to-empty.
**GREEN**: `AggregateState`, `SnapshotStore` (JSON file behind a protocol), glyph mapping.
**Done when**: Relaunch is silent; glyph matches reality; tests green; commit approved.

## Pre-PR Quality Gate

Before each merge to main:
1. Mutation testing — `mutation-testing` skill (muter, or manual if muter can't handle Swift 6.2)
2. Refactoring assessment — `refactoring` skill
3. `swift build` warnings-clean and `swift test` pass
4. Real-world smoke: run the app, observe the slice's behaviour against live GitHub

## Later (explicitly out of scope for this plan)

Quiet hours / focus-mode awareness; per-repo mute; explicit pin/watchlist; review-requested scope; launch-at-login; app icon & polish; Sparkle-style updates.

CI glyph redesign — Angie dislikes the slice-4 checkmark/xmark/clock circles; explore other SF Symbols, colour, or subtler dot indicators during polish.

Clicking a notification banner should open the PR (needs a UNUserNotificationCenter delegate; the URL already rides in userInfo).

---
*Delete this file when the plan is complete. If `plans/` is empty, delete the directory.*
