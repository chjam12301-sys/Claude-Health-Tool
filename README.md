# Claudoctor

> A Mac menu bar app that automatically monitors and cleans up Claude Code's
> local session history, so your sessions stay healthy and your context stays
> clean.

Claude Code stores every session as a `.jsonl` file under
`~/.claude/projects/`. Long-running sessions bloat, polluting context and
slowing things down. Claudoctor watches those files, surfaces health at a
glance from the menu bar, auto-archives the bloated ones, and (V1) gives you a
one-click **Park & Restart** that writes a handoff note before starting fresh.

This repository implements the V0 + V1 scope described in `PRD.md` /
`TechSpec.md`.

## Features

- **Tri-state menu bar icon** — healthy / warning / bloated at a glance.
- **Dropdown panel** — all sessions sorted by size; expand a row to Archive or
  Reveal in Finder.
- **Auto-archive** — bloated sessions (`> 10 MB` by default) move to
  `~/claude-archive/` automatically; the active, recently-written session is
  never touched.
- **Park & Restart** (V1) — pre-flight network check, generate a handoff
  summary into `<project>/.notes/`, archive, then open a fresh terminal.
- **Proxy subsystem** (V1) — auto-detect common local proxy ports, manual
  config, or disabled; injects proxy env into the `claude` subprocess and
  (optionally) spawned terminals. Built for users behind a proxy.
- **Hygiene reminders** (V1) — nudges for long or stale sessions, deduped 24h.
- **Launch at login** (V1) via `SMAppService`.

Everything runs locally. No telemetry, no network calls except the optional
reachability check against `api.anthropic.com`.

## Requirements

- macOS 13.0 (Ventura) or later
- Xcode 15+ / Swift 5.9+ toolchain
- Claude Code CLI (`claude`) on your `PATH` (for Park & Restart)

## Build & run

This project is a Swift Package. On a Mac:

```bash
# quick logic build + tests
swift build
swift test

# assemble a runnable Claudoctor.app (bundles Info.plist with LSUIElement)
./build-app.sh
open Claudoctor.app
```

You can also open `Package.swift` directly in Xcode 15+. On first launch the app
requests Notification and (for Park & Restart) Automation permissions.

## Project layout

```
Sources/Claudoctor/
  App/          @main app + AppDelegate (single-instance guard)
  Models/       SessionInfo, HealthStatus, AppSettings, TerminalApp, ProxyConfig
  Services/     scanner, FSEvents watcher, archiver, CLI, terminal launcher,
                handoff generator, notifications, proxy detect/test/env, park coordinator
  ViewModels/   AppViewModel (orchestrates all flows F1–F7)
  Views/        MenuBarPanel, SessionRow, StatusBadge, ParkButton, About,
                Settings/ (window, threshold slider, proxy section)
  Utilities/    PathDecoder, Formatters, ProcessRunner, Theme, AppInfo
Tests/ClaudoctorTests/   model / proxy / archiver logic tests
```

## Status

The full V0 + V1 source is implemented per the TechSpec business rules
(BR-001…BR-038) and flows (F1…F7). It has **not yet been compiled or run on a
Mac** — it was authored in a Linux environment without the Apple toolchain, so
build, UI, and the manual acceptance checklists in TechSpec §12 still need to be
exercised on macOS. See `CHANGELOG.md` for known deviations (SPM packaging, the
P-06 right-click menu, and notification-click panel opening).

## License

MIT — see [LICENSE](LICENSE).
