# xtool

Cross-platform Xcode replacement. Build and deploy iOS apps with SwiftPM on Linux, Windows, and macOS.

## Overview

xtool is a cross-platform (Linux/WSL/macOS) tool that replicates Xcode functionality with open standards.

✅ Build a SwiftPM package into an iOS app

✅ Sign and install iOS apps

✅ Interact with Apple Developer Services programmatically

✅ Live device screen preview in your browser (ideal for WSL/Windows workflows)

## Getting Started

1. Follow the guide to install `xtool`
    - [Installation (Linux/Windows)](https://xtool.sh/documentation/xtooldocs/installation-linux)
    - [Installation (macOS)](https://xtool.sh/documentation/xtooldocs/installation-macos)
2. Create and run your first xtool-powered app by following the [tutorial](https://xtool.sh/tutorials/xtooldocs/first-app)!

## Examples

### Screenshot

![A screenshot of xtool being invoked from VSCode](Documentation/xtool.docc/Resources/Cover.png)

### Command line interface

```bash
$ xtool --help
OVERVIEW: Cross-platform Xcode replacement

USAGE: xtool <subcommand>

OPTIONS:
  -h, --help              Show help information.

CONFIGURATION SUBCOMMANDS:
  setup                   Set up xtool for iOS development
  auth                    Manage Apple Developer Services authentication
  sdk                     Manage the Darwin Swift SDK

DEVELOPMENT SUBCOMMANDS:
  new                     Create a new xtool SwiftPM project
  dev                     Build and run an xtool SwiftPM project
  ds                      Interact with Apple Developer Services

DEVICE SUBCOMMANDS:
  devices                 List devices
  install                 Install an ipa file to your device
  uninstall               Uninstall an installed app
  launch                  Launch an installed app
  preview                 Mirror iOS device screen to a browser window

  See 'xtool help <subcommand>' for detailed help.
```

## Device Screen Preview

The `preview` command streams your iOS device's screen to a browser-based viewer styled as an iPhone frame. This is especially useful on WSL/Windows where there's no native device screen mirroring.

### Standalone preview

```bash
# Start preview server and open browser
xtool preview

# Custom port and frame rate
xtool preview --port 9000 --fps 15

# Specify a device if multiple are connected
xtool preview -u <UDID>

# Use idevicescreenshot CLI instead of native capture
xtool preview --use-process-capture

# Don't auto-open the browser
xtool preview --no-browser
```

Then open `http://localhost:8034` (or your custom port) in your browser.

### Preview with live reload

The `dev` command supports a `--preview` flag that builds, installs, starts the preview, and watches for file changes to auto-rebuild:

```bash
# Build, install, then start live preview with file watching
xtool dev --preview

# Custom preview port
xtool dev --preview --preview-port 9000

# Disable file watching
xtool dev --preview --no-watch
```

When a source file changes, xtool automatically rebuilds, reinstalls to the device, and refreshes the preview.

### Prerequisites

- A connected iOS device (USB or network-paired)
- Developer Mode enabled on the device (iOS 16+)
- `libimobiledevice` installed (`sudo apt install libimobiledevice-utils` on Linux)
- Developer Disk Image is auto-mounted on start

## Building from Source

### Linux / WSL

```bash
# Install system dependencies
sudo apt install build-essential libssl-dev pkg-config liblzma-dev \
    zlib1g-dev libturbojpeg0-dev

# libimobiledevice must be built from source (apt packages are too old)
# See "Building libimobiledevice from source" below

# Debug build
swift build --product xtool

# Release build
swift build --product xtool -c release

# Or via make
make linux              # debug
make linux RELEASE=1    # release
```

The binary is at `.build/debug/xtool` or `.build/release/xtool`.

To install over an existing xtool:

```bash
sudo cp .build/release/xtool $(which xtool)
```

### macOS

```bash
# Requires XcodeGen: brew install xcodegen
make mac

# Release dist build (requires Fastlane + signing secrets)
make mac-dist
```

### Docker (for Linux builds on any host)

```bash
docker compose run --build --rm xtool bash
# Inside container:
swift build --product xtool -c release
```

The Docker image builds all native dependencies (libimobiledevice, etc.) automatically.

### Building libimobiledevice from source (Linux/WSL)

The Swift bindings require a newer libimobiledevice than what's available via apt. Build from source in a temporary directory:

```bash
sudo apt install build-essential autoconf automake libtool-bin \
    libssl-dev pkg-config libxml2-dev curl libcurl4-openssl-dev

mkdir ~/libimobiledevice-build && cd ~/libimobiledevice-build

# Build each library in order
git clone --branch 2.6.0 https://github.com/libimobiledevice/libplist.git
cd libplist && ./autogen.sh --prefix /usr --without-cython && make && sudo make install && cd ..

git clone --branch 1.3.1 https://github.com/libimobiledevice/libimobiledevice-glue.git
cd libimobiledevice-glue && ./autogen.sh --prefix /usr && make && sudo make install && cd ..

git clone --branch 2.1.0 https://github.com/libimobiledevice/libusbmuxd.git
cd libusbmuxd && ./autogen.sh --prefix /usr && make && sudo make install && cd ..

git clone --branch 1.0.4 https://github.com/libimobiledevice/libtatsu.git
cd libtatsu && ./autogen.sh --prefix /usr && make && sudo make install && cd ..

git clone https://github.com/libimobiledevice/libimobiledevice.git
cd libimobiledevice && ./autogen.sh --prefix /usr --without-cython && make && sudo make install && cd ..

sudo ldconfig

# Clean up source (libraries are installed to /usr/lib)
rm -rf ~/libimobiledevice-build
```

## Testing

```bash
swift test                      # all tests
swift test --filter XToolTests  # specific target
swift test --filter XKitTests   # requires config/config.json
```

## Linting

```bash
make lint
```

Uses SwiftLint 0.59.1. Key rules: 135 char line length, 100 line function bodies, 4-space indentation.

### Library

xtool includes a library that you can use to interact with Apple Developer Services, iOS devices, and more from your own app. You can use this by adding `XKit` as a SwiftPM dependency.

```swift
// package dependency:
.package(url: "https://github.com/xtool-org/xtool", .upToNextMinor(from: "1.2.0"))
// target dependency:
.product(name: "XKit", package: "xtool")
```
