# Meeting Buzzword Bingo

## Review Gate

Implementation begins after user approval of this plan. All source editing will happen in VS Code; Xcode is used as the build/signing toolchain and, when needed, for Apple Account and device setup.

## Product

A small, polished, offline iPhone game that makes long meetings more entertaining. Generate a randomized 5x5 board, tap phrases as you hear them, and celebrate completed lines with full-screen confetti. The center square is free. Rows, columns, and both diagonals count.

### Visual Direction

- A playful editorial game-board aesthetic: warm paper background, deep ink typography, vivid coral and mint accents, rounded tactile tiles, and compact scoreboard details.
- A clear primary board screen with pack selection, completed-line progress, and a prominent new-board action.
- Distinct marked, free, and winning tile states; spring animations and a custom full-screen confetti overlay that does not block controls.
- Native sheets for settings, statistics, and concise instructions. Support light/dark appearance, safe areas, smaller iPhones, VoiceOver, Dynamic Type, and Reduce Motion.

### Replay Value

- Several generously stocked phrase packs: All Hands, Tech Talk, Strategy Session, and a mixed collection.
- Randomized unique phrases on each board, with a free center tile.
- A daily board derived deterministically from the local calendar date, with its own saved progress, plus unlimited randomized quick-play boards.
- Local lifetime statistics: boards played, boards with bingo, unique lines earned, and best completion time.
- Preserve in-progress games and settings between launches. Confirm before replacing an unfinished board.
- Continue playing after a bingo to complete additional lines or the entire board.

## Architecture

- Native Swift and SwiftUI, targeting iOS 17 or newer. Swift is justified by the explicit iOS requirement and provides direct access to Apple's accessibility, audio, haptics, and signing systems.
- No external dependencies, package downloads, account system, network requests, ads, analytics, or backend.
- A pure Swift game engine owns generation, selection, line detection, and deterministic daily-board rules. Keep it independent of SwiftUI for unit testing.
- An observable app store coordinates game actions, persisted snapshots, settings, and statistics.
- Local Codable snapshots in UserDefaults; no database service or sensitive data.
- Native short synthesized pop audio through AVFoundation, with optional haptics. Respect the silent switch and provide independent sound/haptic toggles. No microphone permission is needed.
- SwiftUI Canvas/timeline-based confetti with bounded particle lifetime. Reduce Motion uses a restrained celebration instead.
- A checked-in Xcode project and shared scheme build directly with xcodebuild, without XcodeGen, CocoaPods, or any other installed tooling.

## Files To Create

- `BuzzwordBingo.xcodeproj/project.pbxproj` and shared scheme: app and unit-test targets, automatic signing, simulator support, no paid capabilities.
- `BuzzwordBingo/App/`: application entry point and app store/persistence.
- `BuzzwordBingo/Models/`: game models, phrase library, deterministic generator, and bingo evaluation.
- `BuzzwordBingo/Views/`: board, tiles, pack/mode controls, settings/statistics sheets, and celebration views.
- `BuzzwordBingo/Services/`: short audio synthesis and haptics.
- `BuzzwordBingo/Resources/Assets.xcassets/`: accent colors and an original app icon generated using system tooling.
- `BuzzwordBingo/Info.plist` and `PrivacyInfo.xcprivacy`: app metadata, Novacoast attribution, and applicable required-reason API declaration for UserDefaults.
- `BuzzwordBingoTests/`: meaningful generation, winning-line, daily-game, persistence, and statistics tests.
- `.gitignore`, `.dockerignore`, and `kilo.json`: generated-file/secrets exclusions and Kilo secret-read guardrails. No secrets or environment variables are required.
- `.gitlab-ci.yml`: shared-runner source-level checks; iOS build/test/coverage job requires an explicitly configured macOS runner with Xcode because generic Linux runners cannot compile iOS apps.
- `README.md`: architecture, controls, prerequisites, build/test commands, signing, manual iPhone installation, seven-day renewal, privacy, and contributing.

File grouping may be consolidated during implementation to keep the codebase small and cohesive.

## Data Models

- `PhrasePack`: stable ID, display name, subtitle, and curated phrase collection.
- `BingoTile`: stable position, phrase, marked state, and free-square flag.
- `BingoGame`: mode, pack ID, board ID/seed, tiles, creation date, accumulated active play duration, and already-awarded line IDs.
- `GameSnapshot`: versioned persisted games, selected mode, settings, daily date key, and aggregate statistics.
- `GameStatistics`: boards started, boards won, total unique lines, and optional best first-bingo duration.
- `GameSettings`: sound and haptic preferences.

## Interaction Contracts

There are no HTTP APIs, authentication contracts, server endpoints, or environment secrets.

- `newGame(pack, mode, date)`: produces 24 unique phrases and a marked center square; daily generation is stable for the same local date and phrase-library version.
- `toggleTile(index)`: toggles a non-free tile, returns newly completed line IDs, and updates persistence. Free-square taps do not mutate state.
- `completedLines`: evaluates all 12 possible lines without duplicate awards.
- `recordCelebration(lines)`: counts each line once per board, counts a won board once, and celebrates only newly awarded lines. Unmarking and re-marking cannot farm statistics.
- `restoreSnapshot()`: restores valid state and safely starts fresh for missing, corrupt, or incompatible data.
- Daily and quick-play progress remain independent; changing the date creates the new daily board without silently replacing an active quick-play board.

## Edge Cases

- Multiple lines completed with one tap: one celebration, all newly earned lines counted.
- Unmarking after a win changes current highlights but never decrements lifetime achievements or re-awards previous lines.
- Board restoration never replays a celebration or double-counts statistics.
- Background time does not inflate active meeting duration. Relaunching preserves accumulated time.
- Date rollover, time-zone changes, deterministic daily generation, and limited phrase pools are explicitly handled and tested.
- Interrupted or unavailable audio does not prevent marking tiles; no force-unwrapped resources or required sound files.
- Compact screens and large text can scroll while preserving usable touch targets; accessible tile labels announce phrase, selection, and winning state.

## Verification

1. Build the iOS Simulator app with xcodebuild and no signing credentials.
2. Run XCTest with code coverage enabled; aim for at least 70% coverage of the pure game/persistence core and report measured coverage honestly. UI rendering and hardware feedback are not substitutes for unit tests.
3. Install and launch in an available simulator; inspect screenshots and exercise key flows where automation tooling permits.
4. Build for a generic iOS device without signing to catch device-specific compilation issues.
5. Document hardware checks for pop sound, silent mode, haptics, and physical-device signing that cannot be fully verified in Simulator.

## Manual iPhone Installation

- Sign into the free Apple Account in Xcode Settings, connect and trust the iPhone, and enable Developer Mode when prompted.
- Select the Personal Team and a unique bundle identifier with automatic signing. These are local user-specific settings, not embedded credentials.
- Build/install using the configured team and device through xcodebuild/xcrun devicectl, or use Xcode Run for the initial provisioning step. All source remains editable in VS Code.
- Free provisioning expires seven days after issuance: rebuild and reinstall using the same bundle identifier to renew. Apple currently permits up to three apps per device, three registered devices, and ten App IDs under free provisioning limits.
- No TestFlight, App Store distribution, push notifications, iCloud, or paid-program capabilities are needed or promised.

Apple reference: https://developer.apple.com/help/account/basics/about-your-developer-account

## Standards Applicability

This is an offline native iOS app, not a hosted service. Docker runtime, PostgreSQL, OIDC, Swagger, health endpoints, Prometheus endpoints, and Parker API routing are not applicable. No host dependency installation is needed. Apple's SDKs already installed with Xcode are the only build dependencies. The plan and README explain the macOS CI requirement instead of claiming iOS tests can run in a generic Linux container.
