# Changelog

All notable changes to this project are documented here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

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
