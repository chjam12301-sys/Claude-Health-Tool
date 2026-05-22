# Claudoctor

**English** · [简体中文](README.md)

> A Mac menu bar app that keeps your **Claude Code CLI** sessions healthy.

**Claudoctor is a companion that enhances the Claude Code CLI (the `claude` command-line tool).** It doesn't replace the CLI — it manages the session history the CLI produces. Claude Code stores every session as a `.jsonl` file under `~/.claude/projects/`; long-running sessions bloat, polluting context and slowing things down. Claudoctor watches those files from the menu bar, shows health at a glance, auto-archives the bloated ones, and offers a one-click **Park & Restart** that starts a fresh session while carrying your context forward.

---

## Install

Requires **macOS 13 (Ventura) or later**, the Xcode 15+ / Swift 5.9+ toolchain, and the Claude Code CLI (`claude` on your `PATH`).

```bash
git clone https://github.com/chjam12301-sys/Claude-Health-Tool.git
cd Claude-Health-Tool
./build-app.sh
open Claudoctor.app
```

`build-app.sh` compiles with `swift build -c release` and assembles `Claudoctor.app`. You can also open `Package.swift` directly in Xcode.

**First launch asks for two kinds of permission:**

- **Notifications** — archive results, hygiene tips.
- **Automation / Accessibility** — to open a new terminal running `claude` on Park & Restart.
  - Terminal / iTerm / Ghostty: only **Automation** is needed.
  - Warp: also enable Claudoctor under **System Settings → Privacy & Security → Accessibility** (Warp is driven by typing the command in).

The icon lives in the menu bar (not the Dock) — a stethoscope 🩺.

---

## Screenshots

| Session health | Proxy status |
|---|---|
| ![Session health](docs/screenshots/session-health.png) | ![Proxy status](docs/screenshots/proxy-status.png) |

---

## What it does

### Session health at a glance
Tri-state menu bar icon: healthy / warning (≥5 MB) / bloated (≥10 MB, thresholds adjustable). Open the panel to see every project's sessions sorted by size, with the current session highlighted and a size progress bar with the bloated threshold marked.

### Auto-archive
Bloated sessions over the threshold are moved to `~/claude-archive/` automatically (timestamp-prefixed, **moved, never deleted**). The active, currently-writing session is skipped so your live conversation is never touched. Triggers: on launch, on a timer, and on file changes (FSEvents).

### Park & Restart
A one-click "painless relay":

1. **Pre-flight** — test reachability first; if it fails, abort and leave the session untouched.
2. **Close the old session** — terminate the old `claude` process whose working directory is this project.
3. **Generate a handoff note** — have Claude summarize the session (run inside the project) and write it to `.notes/`.
4. **Archive** — move the old session's `.jsonl` into `~/claude-archive/`.
5. **Start fresh** — open a new `claude` in your preferred terminal that **opens by reading the handoff note to catch up**.

There's also an **Auto authorize** variant that starts the new session with `claude --dangerously-skip-permissions`, skipping every permission prompt (use with care).

### Proxy / connection (built for users behind a proxy)
A GUI app can't read proxy variables from your `.zshrc`, so Claudoctor manages them itself:

- **Auto-detect** — read the system proxy + probe common local ports (7890 / 7897 / 7993 / 1087 / 6152 …) and use `curl` to find which one actually reaches `api.anthropic.com`.
- **Manual** — enter `http://host:port` or `socks5://host:port`.
- **Disabled** — direct connection.
- Injects proxy env into the `claude` subprocess, and can optionally prepend `export …` to the spawned terminal command.
- A dedicated **Proxy status** tab: connection state, latency, error type, one-tap re-test.

### And more
- **Hygiene reminders** — gentle notifications for long sessions (60+ turns) and stale ones (7 days / >3 MB), deduped over 24h.
- **Localization** — System / English / 中文, switchable instantly in Settings.
- **Launch at login** — optional.
- **Privacy first** — no telemetry; no network requests beyond the optional proxy reachability probe; reads only `~/.claude/projects/` and your chosen archive directory.

---

## The panel

| Tab | Contents |
|---|---|
| **Session health** | Status overview + three stat cards (projects / largest / proxy latency) + current session card (progress bar + Park / Auto / Reveal) + the rest of the sessions |
| **Proxy status** | Connection hero + details (mode / URL / last test / error type) + Test now |

Footer: Settings · Open Claude Code · More (How it works / About / Quit).

---

## Settings

A left sidebar: Thresholds · Auto-archive · Proxy · Terminal · Startup · Language · Advanced. Changes take effect immediately and persist automatically.

- **Thresholds** — warning 1–20 MB, bloated 5–50 MB (bloated must be ≥ warning + 1).
- **Auto-archive** — toggle, scan interval (1–30 min), archive directory.
- **Terminal** — auto-detect (Ghostty > Warp > iTerm > Terminal) or pick one.
- **Advanced** — skip pre-flight on Park (not recommended).

---

## Restoring an archived session

Archiving only moves files. To resume an old session: rename `~/claude-archive/<timestamp>-<uuid>.jsonl` back to `<uuid>.jsonl`, move it into the matching `~/.claude/projects/<encoded-dir>/`, then run `claude --resume <uuid>`. The handoff summaries live in the project's `.notes/`.

---

## Built with

Swift 5.9 · SwiftUI (MenuBarExtra) · FSEvents · UserNotifications · SMAppService. Zero third-party dependencies — all system frameworks. Source layout under `Sources/Claudoctor/` (App / Models / Services / ViewModels / Views / Utilities).

---

## License

MIT — see [LICENSE](LICENSE).
