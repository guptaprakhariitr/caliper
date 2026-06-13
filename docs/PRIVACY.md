# Caliper — Privacy Policy

_Last updated: 2026_

Caliper processes pixels **entirely on your Mac**.

- **No data is collected or transmitted.** The screen regions Caliper reads to measure pixels and pick colors never leave your device.
- **Edge detection and color sampling run on-device.** No image or pixel data is sent anywhere.
- **Screen Recording permission** is used only to capture the area under the ruler/loupe at runtime; you grant it on first use and can revoke it in System Settings.
- **No analytics or tracking** is included in the shipped build.
- **No account** is required.

## Update checks

On launch, Caliper makes **one anonymous HTTPS request** to a version service (Google Firestore) to check whether a critical update is required. Only the app version is compared against the latest published version — **no personal data, identifiers, or usage information are sent or stored**. If the device is offline or the service is unreachable, the check **fails open** (the app starts normally and is never blocked).

If a future version adds optional cloud or analytics features, this policy and the App Store privacy label will be updated, and any such feature will be opt-in.

Questions: open an issue at https://github.com/guptaprakhariitr/caliper
