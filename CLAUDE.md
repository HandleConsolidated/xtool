# CLAUDE.md

## Project Overview

**xtool** is a cross-platform (Linux/WSL/macOS) Xcode replacement that builds and deploys iOS apps using SwiftPM. It provides CLI commands for creating, building, signing, and installing iOS apps without requiring Xcode (on non-macOS platforms).

The project is written in **Swift 6.0+** (swift-tools-version:6.0) with strict concurrency enabled.

## Repository Structure

```
Sources/
├── xtool/              # Executable entry point (@main)
├── XToolSupport/       # CLI commands (swift-argument-parser based)
├── XKit/               # Core library: signing, provisioning, Apple services
│   ├── DeveloperServices/   # Apple Developer portal API interactions
│   ├── GrandSlam/           # Apple authentication (SRP, 2FA, tokens)
│   ├── Installation/        # App installation to iOS devices
│   ├── Integration/         # Combined sign+install workflow
│   ├── Model/               # Certificates, entitlements, keypairs
│   ├── Signer/              # Code signing (AutoSigner, SignerImpl)
│   └── Utilities/           # Helpers, key-value storage, ZIP
├── PackLib/            # Build planning: xtool.yml schema, Packer, Planner
├── DeveloperAPI/       # Generated OpenAPI client for App Store Connect API
├── CXKit/              # C code: version string, mobileprovision parsing
├── XUtils/             # Small shared utilities (Foundation extensions, temp dirs)
└── XADI/               # System library module map for libxadi (Linux only)

Tests/
├── XToolTests/         # Tests for XToolSupport (e.g. SDK matcher tests)
└── XKitTests/          # Tests for XKit (signing, developer services, GrandSlam)

macOS/                  # Xcode project (generated via XcodeGen from project.yml)
Linux/                  # Linux AppImage build scripts
Documentation/          # Swift-DocC documentation
scripts/                # Helper scripts (e.g. select-identity.sh)
```

## Build Commands

### Linux (primary development target)

```bash
# Debug build
make linux
# or: swift build --product xtool

# Release build
make linux RELEASE=1

# Linux dist build (AppImage via Docker)
make linux-dist
# or: docker compose run --build --rm xtool Linux/build.sh
```

### macOS

```bash
# Debug build (requires XcodeGen: `brew install xcodegen`)
make mac

# Generate/update Xcode project only
make project

# Reload Xcode with fresh project
make reload

# Release dist build (requires Fastlane + signing secrets)
make mac-dist
```

### Docker (for Linux builds on any host)

```bash
docker compose run --build --rm xtool bash
# Then inside container: swift build --product xtool
```

## Testing

```bash
# Run all tests
swift test

# Run specific test target
swift test --filter XToolTests
swift test --filter XKitTests
```

Tests use Swift Testing (`import Testing`, `@Test`, `#expect`). XKitTests require a `config/config.json` file (see `config/config-template.json` for the schema). Test resources include a test `.app` bundle.

## Linting

SwiftLint is enforced in CI. Run locally:

```bash
make lint
```

Key SwiftLint rules:
- **Line length**: 135 characters max
- **Function body length**: 100 lines max
- **File length**: 1000 lines max
- **Type body length**: 500 lines max
- **Cyclomatic complexity**: 12 max
- **Function parameter count**: 7 max
- **Spaces not tabs**: 4-space indentation
- **No trailing `.0`** on floating point literals
- `force_try` and `force_cast` are warnings, not errors
- `unused_import` analyzer rule is enabled
- Generated code (`Sources/DeveloperAPI/Generated`) is excluded from linting

See `.swiftlint.yml` for full configuration including disabled and opt-in rules.

## CI Workflows

- **build.yml**: Builds on Linux (x86_64 + aarch64 via Docker) and macOS (native + iOS scheme)
- **swiftlint.yml**: Lint check on PRs touching `.swift` files or lint config
- **release.yml**: Triggered by git tags; builds Linux AppImages + macOS .app, creates GitHub draft release

## Key Architecture Patterns

### CLI Structure
Commands use `swift-argument-parser`. The top-level `XToolCommand` groups subcommands into Configuration (`setup`, `auth`, `sdk`), Development (`new`, `dev`, `ds`), and Device (`devices`, `install`, `uninstall`, `launch`) categories.

### Dependency Injection
Uses `swift-dependencies` (`@Dependency`, `prepareDependencies`) for injectable services like `zipCompressor`.

### Concurrency
The project uses Swift 6 strict concurrency. All public types should be `Sendable`. Async operations use `async/await` and `TaskGroup`.

### App Build Pipeline
1. `PackSchema` parses `xtool.yml` (project config: bundleID, resources, entitlements, extensions)
2. `Planner` creates a build plan from the schema + build settings
3. `Packer` executes the plan via SwiftPM, producing a `.app` bundle
4. `AutoSigner` provisions and code-signs the app via Apple Developer Services

### Platform Differences
- **Linux**: Uses `AsyncHTTPClient`, `WebSocketKit`, `OpenAPIAsyncHTTPClient`, and `XADI` (libxadi)
- **macOS**: Uses `URLSession`-based networking, `OpenAPIURLSession`; supports Xcode project generation via `XcodeGen`

Conditional compilation (`#if os(macOS)`, `.when(platforms:)`) is used throughout.

### OpenAPI Code Generation
`Sources/DeveloperAPI/Generated/` contains auto-generated App Store Connect API client. Regenerate with:

```bash
make api          # regenerate from existing spec
make update-api   # download new spec + regenerate
```

The generated `Client` type is renamed to `DeveloperAPIClient` via sed post-processing.

## Project Configuration Files

- `xtool.yml` — Per-project configuration for apps built with xtool (bundle ID, resources, entitlements, extensions)
- `Package.swift` — SPM package manifest; version is injected via `XTOOL_VERSION` env var or git info
- `macOS/project.yml` — XcodeGen project spec for the macOS app wrapper
- `.swiftlint.yml` — SwiftLint config (pinned to version 0.59.1)
- `docker-compose.yml` — Docker service for Linux builds
- `Dockerfile` — Multi-stage build: libimobiledevice stack + xadi + Swift 6.2

## Environment Variables

- `XTOOL_VERSION` — Override version string at build time
- `XTL_DEBUG_ERRORS` — Print detailed error info (set to any value to enable)
- `APPIMAGE_EXTRACT_AND_RUN=1` — Used in Docker where FUSE is unavailable
- `USBMUXD_SOCKET_ADDRESS` — Override usbmuxd socket (Docker: `host.docker.internal:27015`)

## Dependencies

Key external dependencies:
- `xtool-core` — Shared crypto, signing support, protocol codable, utilities
- `SwiftyMobileDevice` — iOS device communication (libimobiledevice wrapper)
- `zsign` — Code signing implementation
- `swift-argument-parser` — CLI framework
- `swift-openapi-*` — OpenAPI code generation and runtime
- `swift-crypto` / `swift-certificates` — Cryptographic operations
- `swift-dependencies` — Dependency injection
- `Yams` — YAML parsing (for xtool.yml)
- `XcodeGen` — Xcode project generation (macOS only)
- `unxip` — Xcode .xip extraction
