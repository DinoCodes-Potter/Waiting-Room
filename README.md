# Waiting Room

**A macOS utility that watches any region of your screen and notifies you when it starts or stops changing.** (Not **notarized** yet)

Waiting Room helps you keep an eye on long-running tasks without constantly checking your screen. Monitor build processes, progress bars, terminal output, and more — with automatic change detection and on-device text recognition.

## Features

- **Watch any screen region** — Select a rectangular area on any connected display.
- **Multiple simultaneous watches** — Monitor several regions independently.
- **Pixel-level change detection** — Captures each watched region every second and detects changes, including slowly advancing progress bars.
- **Reduced false positives** — Compares the current frame with the frame from two seconds earlier, helping ignore periodically blinking elements such as terminal cursors.
- **Two monitoring modes** — Get notified when a region starts changing or stops changing.
- **Configurable sensitivity** — Set the required duration of stillness and adjust sensitivity for completion detection.
- **On-device text recognition** — Uses Apple's Vision framework to recognize text when a watch triggers.
- **Native notifications** — Receive macOS notifications with a sound, a concise status summary, and the last few lines of recognized text.
- **Activity chime** — Plays a chime when a change is detected.
- **Privacy-first design** — Screenshots are analyzed locally and discarded. No network calls are made.

## How It Works

1. **Select a region:** Click `Watch a region…`. Your screens dim, allowing you to drag a rectangle around the area you want to monitor.
2. **Configure a watch:** Choose whether to be notified when the selected region starts changing or stops changing. For inactivity monitoring, configure the required duration of stillness and sensitivity.
3. **Monitor automatically:** Waiting Room captures the selected region once per second and compares its pixels against previous frames.
4. **Get notified:** When the configured condition is met, Waiting Room uses Apple's Vision framework to recognize visible text and sends a macOS notification with a sound and a concise summary.

### Example Notifications

- `SUCCESS` — Looks successful
- `WARNING` — Looks like an error

Notifications also include the last couple of lines of recognized text, providing additional context without requiring you to reopen the monitored application.

## Privacy

Waiting Room is designed to keep your screen data on your Mac.

- Screenshot analysis happens locally.
- Text recognition uses Apple's Vision framework on-device.
- Captured screenshots are analyzed and discarded.
- No network calls are made.

**Your screen content stays on your Mac.**

## Built With

- **Swift** — Application development
- **Apple Vision** — On-device text recognition
- **macOS Notification Center** — Native system alerts

## Requirements

- An apple silicon Mac
- The macOS version and other system requirements specified by the project

## Licence

Waiting Room is licensed under the [MIT License](LICENSE).

Copyright (c) 2026 Waiting Room contributors.

See the [`LICENSE`](LICENSE) file for the full licence text.

