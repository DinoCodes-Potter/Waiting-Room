<div align="center">

<h1>Waiting Room</h1>

<p><strong>Go make a coffee. Waiting Room will watch the screen.</strong></p>

<p>A macOS menu bar app that watches any region of your screen and notifies you when it starts or stops changing.</p>

<p>
  <a href="LICENSE"><img alt="License: MIT" src="https://img.shields.io/badge/license-MIT-2559e6.svg"></a>
  <img alt="Platform: macOS 14+, Apple silicon" src="https://img.shields.io/badge/platform-macOS%2014%2B%20%C2%B7%20Apple%20silicon-17202b.svg">
  <a href="https://github.com/DinoCodes-Potter/Waiting-Room/actions/workflows/ci.yml"><img alt="CI" src="https://github.com/DinoCodes-Potter/Waiting-Room/actions/workflows/ci.yml/badge.svg"></a>
</p>

<p>
  <a href="https://github.com/DinoCodes-Potter/Waiting-Room/releases/latest"><strong>Download for macOS</strong></a> &middot;
  <a href="https://dinocodes-potter.github.io/Waiting-Room/">Website</a> &middot;
  <a href="https://github.com/DinoCodes-Potter/Waiting-Room/issues/new?template=bug_report.yml">Report a bug</a>
</p>

</div>

---

Drag a box around anything slow, such as a build log, a progress bar, a file transfer or an AI agent's output. Waiting Room watches that region and sends you a notification when it stops changing, so you don't have to keep checking.

## Features

- **Keeps watching when another window covers it.** Waiting Room captures the window under your selection, not the screen, so you can cover it, move it, minimize it, switch to another Desktop or work in other apps. If you move the window, the watched region moves with it.
- **Watch any region.** Select a rectangle on any connected display, from the menu or with **Control-Option-W** in any app.
- **Watch several things at once.** Every watch runs independently, with its own name, mode and sensitivity.
- **Four alert modes.**
  - *Stops*: alert when the region has been still for a set time (2 to 60 seconds).
  - *Starts*: alert the moment something changes.
  - *Any change*: alert on every change, with a short cooldown.
  - *Text*: alert when a phrase you typed, such as `BUILD SUCCEEDED`, appears in the region (read on-device).
- **Presets.** One tap sets sensible values for a *Build*, a *Download* or an *AI agent* (agents pause to think, so they wait longer).
- **See what it sees.** Corner brackets mark every watched region on screen. They pulse while it changes and turn green when done. Each watch card shows a live line of recent activity and a ring that fills as the region stays quiet.
- **Pixel-level detection.** Each region is captured every second (every two seconds while a *Stops* watch is waiting for activity to begin), which is enough to catch slowly advancing progress bars.
- **Fewer false alarms.** A pixel only counts as changed if it differs from both of the previous two frames, so blinking terminal cursors are ignored.
- **Adjustable sensitivity.** Choose High, Medium or Low.
- **Reads the screen when it fires.** On-device text recognition (Apple Vision) reads the region and flags whether it looks like a success or an error.
- **Native alerts.** An animated banner on the watched display, a macOS notification, and a chime you can turn off. The menu bar hourglass turns over while something is being watched.
- **Pause, open at login.** Pause every watch with one click, and start Waiting Room when you log in.
- **Light on resources.** Capture pauses while the screen sleeps or the session is locked, and slows down in Low Power Mode. Waiting Room never captures its own windows.

## Install

1. [Download the latest DMG](https://github.com/DinoCodes-Potter/Waiting-Room/releases/latest).
2. Open it and drag **Waiting Room** into **Applications**.
3. Open Waiting Room. It lives in your menu bar (look for the hourglass).

### macOS will warn you the first time

Waiting Room is **not notarized yet**, so macOS blocks the first launch. To open it anyway:

1. Try to open the app once, then dismiss the warning.
2. Go to **System Settings → Privacy & Security**, scroll to the **Security** section and click **Open Anyway**.
3. Confirm with your password or Touch ID.

You only need to do this once.

### Grant Screen Recording access

To compare pixels, Waiting Room needs the **Screen Recording** permission. Click **Grant Screen Recording access…** in the menu, allow it in System Settings, then quit and reopen the app.

### Verify your download

```sh
shasum -a 256 WaitingRoom-<version>.dmg
```

Compare the result with the checksum shown on the [website](https://dinocodes-potter.github.io/Waiting-Room/#install).

### Requirements

- A Mac with Apple silicon
- macOS 14 (Sonoma) or later, which is what the ScreenCaptureKit screenshot API used by the app needs

## How it works

1. **Select a region.** Choose **Watch a region…** from the menu bar. Your screens dim and you drag a rectangle around what you want to watch.
2. **Choose an alert.** Pick *Stops*, *Starts*, *Any change* or *Text*. For *Stops*, set how long the region must stay still, and the sensitivity.
3. **Let it watch.** Waiting Room captures a small copy of the region, from the window itself so overlapping windows don't matter, and compares it with the previous two frames.
4. **Get notified.** When the condition is met, Waiting Room reads the visible text and tells you what happened, for example:

   > **Watch 1: done**
   > Stopped changing. ✅ Looks successful. 212 tests passed

   It flags `✅ Looks successful` or `⚠️ Looks like an error` by looking for words such as *passed*, *complete*, *failed* or *traceback*, and always includes the last couple of lines it read.

## Privacy

Your screen content stays on your Mac.

- Screenshots are analyzed locally and discarded.
- Text recognition runs on-device with Apple's Vision framework.
- The app makes no network calls.

The whole app is a handful of Swift files in [`Sources/WaitingRoom`](Sources/WaitingRoom), so you can check these claims yourself.

## Build from source

You need macOS 14 or later and Xcode 15 or later (or the matching Swift toolchain).

```sh
git clone https://github.com/DinoCodes-Potter/Waiting-Room.git
cd Waiting-Room
swift build -c release
.build/release/WaitingRoom
```

> **Note**
> When run directly from the command line the app has no bundle identifier, so macOS notifications are skipped. The on-screen banner and chime still work. Run it from an app bundle to get full notifications.

### Build a release DMG

```sh
scripts/make-dmg.sh 0.2
```

This builds an ad-hoc signed `Waiting Room.app` and a drag-to-install DMG in `dist/`. The **Release** workflow does the same on a macOS runner and publishes it as a GitHub Release, which the website then serves.

## Project layout

```
Sources/WaitingRoom/
├── WaitingRoomApp.swift   App entry point and menu bar item
├── Views.swift            Menu bar popover and watch cards
├── Watch.swift            A single watch: frame comparison and trigger logic
├── WatchManager.swift     Scheduling, screen capture and notifications
├── RegionSelector.swift   Full-screen region selection overlay
├── Analysis.swift         On-device text recognition and the success/error summary
└── Toast.swift            The on-screen banner
website/                   The project website (deployed with GitHub Pages)
```

## Contributing

Bug reports and pull requests are welcome. See [CONTRIBUTING.md](CONTRIBUTING.md) to get started, and [SECURITY.md](SECURITY.md) for how to report a security issue.

## Licence

[MIT](LICENSE) © 2026 Abhinav Sharma
