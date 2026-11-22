# Contributing to Waiting Room

Thanks for helping out. Bug reports, ideas and pull requests are all welcome.

## Reporting a bug or suggesting a feature

Open an [issue](https://github.com/DinoCodes-Potter/Waiting-Room/issues/new/choose) and fill in the template. For bugs, include your macOS version, your Mac model and the steps that trigger the problem.

To report a security problem, follow [SECURITY.md](SECURITY.md) instead of opening a public issue.

## Setting up

You need macOS 14 or later and Xcode 15 or later.

```sh
git clone https://github.com/DinoCodes-Potter/Waiting-Room.git
cd Waiting-Room
swift build
swift run WaitingRoom
```

The app needs the **Screen Recording** permission. When you run it from Terminal, macOS asks you to grant it to Terminal.

## Making a change

1. Fork the repository and create a branch from `main`.
2. Keep the change focused. One pull request should do one thing.
3. Follow the style of the surrounding code: Swift API Design Guidelines, four-space indentation, no force unwraps.
4. Make sure `swift build -c release` succeeds. CI runs the same command.
5. Open a pull request and describe what changed and why. Add screenshots for anything visible.

## Privacy rules

Waiting Room's promise is that your screen content never leaves your Mac. Pull requests that add network access, analytics, telemetry or any form of screenshot storage will not be accepted.

## Website changes

The project website lives in `website/` and is plain HTML, CSS and JavaScript with no build step. Open `website/index.html` in a browser to preview it. Please keep it free of third-party scripts, fonts and trackers.
