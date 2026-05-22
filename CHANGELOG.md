# Changelog

All notable changes to Claudoctor are documented here.

## [0.1.0] - 2026-05-21

Initial implementation of V0 + V1 per PRD / TechSpec.

### V0 (monitoring + archiving)
- Menu bar status icon with tri-state overlay (healthy / warning / bloated) and
  a question-mark state when Claude Code is not detected (CD-001).
- Dropdown panel (P-02): status header, all-sessions list sorted by size,
  expandable rows with Archive / Reveal, empty state, footer with auto-archive
  status and Settings / About / Quit.
- Manual archive of a single session — moves the `.jsonl` plus its sibling UUID
  directory to `~/claude-archive/` with a `yyyyMMdd-HHmmss-` prefix (BR-005/006).
- Auto-archive (F2): triggered on launch, on a periodic timer, and on FSEvents.
  Skips files modified within the last 30s (BR-004) and the active session.
- Session scanner: stat-only, sorted, sized; FSEvents watcher with 1s debounce.
- Settings window (P-03): thresholds with mandatory gap (BR-001/002/003),
  scan interval, archive directory picker, enable/disable auto-archive, reset.
- About window (P-04). Local notifications with permission gating (BR-025).

### V1 (Park & Restart + proxy + hygiene)
- Park & Restart (F3): pre-flight reachability check that aborts without
  touching the session on failure (BR-033/034), handoff generation via
  `claude -p --output-format json` written to `<project>/.notes/` (BR-015/016),
  archive, then launch the preferred terminal. Independent step fallback (BR-018).
- Proxy subsystem: auto-detect (port probe + reachability over the candidate),
  manual URL config with validation (BR-038), disabled mode, periodic silent
  re-test every 5 minutes (BR-032/037), and a Test connection action (IR-10).
- Proxy env injection into subprocesses (8 vars, BR-035) and an optional
  `export ... &&` prefix for spawned terminals (BR-036).
- Terminal preference with auto-detect order Ghostty > Warp > iTerm > Terminal.
- Hygiene reminders: long session (60+ turns) and stale session (7d / >3MB),
  deduped 24h (BR-019/027/028).
- Launch at login via SMAppService.
- In-app feature guide (How it works) opened from the panel header.
- zh-Hans / en localization with live in-app switching (System / English / 中文).
- Park & Restart (Auto authorize) variant that starts the new session with
  `claude --dangerously-skip-permissions` to skip every permission prompt.
- UI Design v2: Claude-native warm coral/cream palette, tabbed panel
  (Session health / Proxy status), hero area, stat cards, redesigned active
  card with a size progress bar, card-style session rows, a sidebar-navigation
  Settings window, and a refreshed About window. Windows render in a fixed
  light appearance with coral accents.
- Proxy reachability now tested via `curl --proxy` (reliable with Clash/Surge)
  instead of `URLSession`, fixing detection behind a local proxy. Proxy tab
  shows error type, tested ports, and a troubleshooting hint.
- Renamed the connection labels from "API" to "Proxy/连接" — the status
  reflects the proxy/VPN reachability, not the LLM API.
- Settings panes restyled with grouped cream cards.

### Known deviations
- Built and structured as a Swift Package (SPM). Use `build-app.sh` on a Mac to
  assemble `Claudoctor.app` with the bundled `Info.plist` (LSUIElement etc.).
- The right-click context menu (P-06) is not a separate AppKit `NSMenu` because
  SwiftUI `MenuBarExtra` cannot host one cleanly; its actions (proxy status,
  Archive all bloated, Park, Settings/About/Quit) are surfaced inside the panel.
- Programmatically opening the panel from a notification click is limited by
  `MenuBarExtra`; clicking a notification brings the app forward instead.
- Not yet verified on a Mac — see README "Status".
