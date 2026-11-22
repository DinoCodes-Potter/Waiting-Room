# Security policy

## Reporting a vulnerability

Please don't open a public issue for security problems.

Use GitHub's private reporting instead: go to the [Security tab](https://github.com/DinoCodes-Potter/Waiting-Room/security/advisories/new) of this repository and choose **Report a vulnerability**. Include what you found, the steps to reproduce it and the version of Waiting Room and macOS you used.

You can expect a first reply within a week.

## What counts

Waiting Room handles screen content, so these matter most:

- Any way for screen content to leave the Mac, including through network access, logs or files on disk
- Screenshots being kept after analysis
- Anything that lets another process read what Waiting Room captures

## Supported versions

Only the latest release receives fixes.

## Download integrity

Releases are not notarized yet. Each release lists a SHA-256 checksum so you can verify the file you downloaded.
