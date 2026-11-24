# Changelog

All notable changes to this project are documented here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [0.2.1] - 2026-11

### Fixed
- A window watch no longer shows a black picture, or reports a false "stopped", when you switch Desktops. It pauses while the window is on another Desktop or minimized, says so on its card, and resumes cleanly when you come back
- Blank captures of a window are ignored instead of being treated as a change

## [0.2] - 2026-11

### Added
- Watches capture the window under the selection, so they keep working when another window covers it, and follow the window if it moves
- *Text* alert mode: alert when a phrase appears in the region
- *Build*, *Download* and *AI agent* presets
- On-screen corner brackets around watched regions that pulse while the region changes and turn green when done
- Live activity line and a quiet-time ring on every watch card
- Global shortcut (Control-Option-W) to start a selection from any app
- Pause all watches, chime toggle, and open at login
- Animated menu bar hourglass, animated alert banner with a countdown bar, and a size readout while selecting
- `scripts/make-dmg.sh` and a Release workflow that builds the DMG on a macOS runner

### Changed
- The website now serves the newest GitHub Release and shows its version, size and checksum

## [Unreleased]

### Added
- Project website in `website/`, deployed with GitHub Pages
- `Package.swift` so the app builds with `swift build`
- Continuous integration, issue templates, `CONTRIBUTING.md` and `SECURITY.md`

### Changed
- README rewritten to match the app's actual behavior, including the third alert mode (*Any change*) and the macOS 14 requirement

## [0.1] - 2026-10

### Added
- Menu bar app that watches any region of any connected display
- Multiple simultaneous watches
- Alert modes: *Stops*, *Starts* and *Any change*
- Pixel-level change detection that ignores blinking elements
- Adjustable settle time and sensitivity
- On-device text recognition with a success or error summary
- On-screen banner, macOS notification and chime
- Capture pauses while the screen sleeps or the session is locked
