# Security Policy

PicaMac processes pixels **entirely on-device**. It reads the screen region under the ruler via ScreenCaptureKit (with your granted Screen Recording permission) only to measure and pick colors; nothing is uploaded, and the shipped build contains no telemetry. The edge-detection engine works on local images.

## Reporting a vulnerability

Please report security issues privately to the maintainer (open a GitHub security advisory or email the address on the GitHub profile) rather than a public issue. We aim to respond within a few days.

## Notes

- `GoogleService-Info.plist` and any signing keys are never committed (see `.gitignore`).
- Screen Recording permission is requested on first capture; you can revoke it any time in System Settings → Privacy & Security → Screen Recording.
