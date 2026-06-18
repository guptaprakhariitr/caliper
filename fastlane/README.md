fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

## Mac

### mac gen

```sh
[bundle exec] fastlane mac gen
```

Generate Xcode project from project.yml

### mac build

```sh
[bundle exec] fastlane mac build
```

Archive + export a Mac App Store build

### mac upload

```sh
[bundle exec] fastlane mac upload
```

Upload binary + metadata + screenshots to App Store Connect (does NOT submit for review)

### mac release

```sh
[bundle exec] fastlane mac release
```

Full pipeline: build → upload (review submission stays manual in App Store Connect)

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
