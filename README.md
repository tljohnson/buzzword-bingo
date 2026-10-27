# Meeting Buzzword Bingo

A pocket-sized meeting survival kit for iPhone. Listen for the corporate classics, tap the tiles, and celebrate a bingo with confetti, a synthesized pop, and a tiny haptic high five. Built at Novacoast.

## Features

- Randomized 5x5 boards with a free center, four phrase collections, and unlimited free play.
- A deterministic daily challenge with separate saved progress.
- Rows, columns, and diagonals count; keep playing for all 12 lines.
- Local lifetime stats, fastest first bingo, and automatic progress restoration.
- Independent sound/haptic toggles, silent-switch support, light/dark appearance, VoiceOver labels, Dynamic Type, and Reduce Motion support.
- Offline, private, no accounts, no ads, no third-party dependencies.

## Architecture

`BuzzwordBingo/Models/GameEngine.swift` is the Foundation-only rule engine and curated phrase library. `App/GameStore.swift` coordinates observable state, timing, statistics, daily rollover, and Codable/UserDefaults persistence. SwiftUI views live in `Views/`; `Services/Feedback.swift` synthesizes a short pop using AVFoundation and produces UIKit haptics. The checked-in Xcode project uses synchronized source folders, so Swift files can be edited entirely in VS Code without project regeneration.

The daily seed uses the device's local calendar date and a stable algorithm, not Swift's randomized hash. Players on the same local date and app version receive the same daily phrases. Changing time zones can change the current daily challenge. Phrase-library changes in future releases may change future daily boards; saved valid boards remain intact.

There is no backend, database, OIDC, network API, or server deployment. No `/health`, `/metrics`, Swagger, Docker runtime, or environment secrets are applicable to this native app. Swift is used because this is an iOS application. Apple's already-installed toolchain provides every dependency; no host package installation is required.

## Prerequisites

- macOS with full Xcode installed and its license/first-run setup completed.
- iOS 17+ on an iPhone, or an installed iOS Simulator runtime.
- A free Apple Account for physical-device signing; a paid program membership is not needed.
- VS Code for source editing. Optional Swift language support improves editing but is not required to build.

Confirm the active toolchain with `xcodebuild -version`. If macOS points to Command Line Tools instead of full Xcode, select Xcode in Xcode Settings > Locations > Command Line Tools.

## Environment Variables

The app needs **no environment variables, credentials, API keys, or `.env` file**. Never add your Apple Account password or signing private keys to this repository. Team IDs and bundle identifiers are build settings, not passwords. CI optionally accepts `IOS_SIMULATOR_NAME` to select an installed simulator; the default is `iPhone 17 Pro`.

## Local Setup

Run commands from the repository root in VS Code's terminal:

```sh
xcodebuild -list -project BuzzwordBingo.xcodeproj
xcrun simctl list devices available
xcodebuild build -project BuzzwordBingo.xcodeproj -scheme BuzzwordBingo -destination 'generic/platform=iOS Simulator' -derivedDataPath build/DerivedData CODE_SIGNING_ALLOWED=NO
```

To install in Simulator, substitute an available simulator UUID from the list:

```sh
xcrun simctl boot SIMULATOR_UUID
open -a Simulator
xcrun simctl bootstatus SIMULATOR_UUID -b
xcrun simctl install SIMULATOR_UUID build/DerivedData/Build/Products/Debug-iphonesimulator/BuzzwordBingo.app
xcrun simctl launch SIMULATOR_UUID com.novacoast.meetingbuzzwordbingo
```

If a simulator is already booted, omit `simctl boot`. The default bundle identifier above applies to simulator builds unless overridden.

## How To Play

1. Choose Free play or Daily board.
2. In Free play, tap the agenda title to choose The Remix, All Hands, Tech Talk, or Strategy Session.
3. Tap phrases as you hear them; tap again to undo. The center is always marked.
4. Complete five tiles in any row, column, or diagonal to trigger confetti. Multiple lines on one tap all count.
5. Start a fresh board whenever you want. Replacing a marked quick-play board requires confirmation. Daily progress is kept separately.

Sound follows the silent switch and mixes with other audio. Settings can disable sound and haptics independently. Haptics need compatible physical hardware. No microphone is used: the app never listens to or records the meeting.

## Running Tests

Choose an installed simulator name:

```sh
xcodebuild test -project BuzzwordBingo.xcodeproj -scheme BuzzwordBingo -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath build/DerivedData -resultBundlePath build/Tests.xcresult -enableCodeCoverage YES -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO
xcrun xccov view --report build/Tests.xcresult
xcrun xccov view --report --json build/Tests.xcresult > build/coverage.json
swift tools/CheckCoverage.swift build/coverage.json
```

Use a fresh result-bundle path for another run: Xcode refuses to overwrite an existing `.xcresult`. The coverage gate requires 70% line coverage of the game and persistence core; SwiftUI rendering and hardware feedback are excluded from that core metric. Tests cover unique generation, deterministic seeds, winning lines, duplicate awards, persistence recovery, statistics, separate modes, rollover, and active-only timing.

Manual checks on an iPhone: silent-switch behavior, sound with headphones, haptics, interrupted audio, large text, VoiceOver, reduced motion, background/restoration, and reinstall preservation.

Verified locally with Xcode 27.1 and an iPhone 17 Pro simulator running iOS 26.4: **45 tests passed** (43 unit tests and 2 UI smoke tests), **99.70% core line coverage** (336/337), successful simulator launch, and successful unsigned generic iOS-device build. UI smoke tests exercise a winning row, celebration banner, relaunch restoration, settings, daily/free-play switching, statistics, and accessibility text layout. Physical-device signing, installation, audio, and haptics still require your iPhone and Apple Account. Simulator testing is serialized to avoid cloned-runner stalls observed with this local Xcode/runtime combination.

## Install On Your iPhone

Free provisioning is **personal development signing**, not App Store, TestFlight, or unrestricted IPA distribution. Apple currently limits it to three apps per device, three devices, and ten App IDs. Profiles expire **seven days after issuance**. Rebuild and reinstall every seven days to keep launching the app.

### First-Time Signing Setup

1. Open `BuzzwordBingo.xcodeproj` in Xcode. This is signing setup only; all code editing can remain in VS Code.
2. In Xcode > Settings > Accounts, sign in with your free Apple Account and accept any required developer agreement.
3. Connect your unlocked iPhone over USB. Trust the computer on the phone and let Xcode finish pairing/preparing it.
4. Enable Settings > Privacy & Security > Developer Mode on the iPhone if requested, restart, and confirm.
5. In the BuzzwordBingo app target's Signing & Capabilities tab, enable automatic signing, select your **Personal Team**, and choose a unique identifier such as `com.yourname.meetingbuzzwordbingo`. The default identifier may already be registered by another person.
6. Select your iPhone as the run destination and click Run once. Xcode creates the development certificate and profile. If prompted, trust the developer under Settings > General > VPN & Device Management.

No paid capabilities are enabled. Do not enroll in the paid program just to run this app on your own phone.

### Subsequent Builds From VS Code

Find your device identifier with:

```sh
xcrun devicectl list devices
```

Use the same unique bundle identifier and Personal Team ID from Xcode. Keep both values consistent when renewing:

```sh
xcodebuild build -project BuzzwordBingo.xcodeproj -scheme BuzzwordBingo -configuration Debug -destination 'generic/platform=iOS' -derivedDataPath build/Device -allowProvisioningUpdates -allowProvisioningDeviceRegistration DEVELOPMENT_TEAM=YOUR_TEAM_ID PRODUCT_BUNDLE_IDENTIFIER=com.yourname.meetingbuzzwordbingo
xcrun devicectl device install app --device YOUR_DEVICE_ID build/Device/Build/Products/Debug-iphoneos/BuzzwordBingo.app
xcrun devicectl device process launch --device YOUR_DEVICE_ID com.yourname.meetingbuzzwordbingo
```

The phone must be paired, unlocked, and reachable. Initial signing and expired account sessions may still require Xcode's account UI. If automatic registration needs the connected device as the build destination, use `-destination 'platform=iOS,id=YOUR_DEVICE_UDID'` instead of the generic destination (the UDID is shown in Xcode's Devices and Simulators).

Renew by repeating the signed build/install commands or Xcode Run before/after expiration. **Do not delete the app first**: reinstalling the same app identifier normally preserves local boards/stats, whereas deleting the app removes them. Keep the same signing team. Provisioning renewal requires Apple's services even though gameplay is fully offline.

Apple reference: https://developer.apple.com/help/account/basics/about-your-developer-account

## API Reference

No external API is exposed. The core's contracts are `BingoGame.init(pack:mode:date:seed:)`, `toggle(index:)` returning newly awarded line IDs, and computed `completedLines`/`winningTileIndices`. `GameStore` provides mode switching, board replacement, taps, settings, and lifecycle timing. Line IDs are rows 0-4, columns 5-9, diagonals 10-11. Previously awarded lines cannot be farmed by unmarking and re-marking.

## Deployment And CI

Deployment is the Personal Team device installation described above. There is no server/container to deploy. Docker cannot legally/practically provide Apple's iOS SDK on a generic Linux runner, so Docker setup commands are intentionally not provided.

GitLab CI runs on merge requests and pushes to `main`. Enable instance runners in repository Settings > CI/CD > Runners. The lightweight validation job uses `alpine:latest` and tag `shared`. **The actual iOS test/coverage job requires a macOS shell runner with both `shared` and `macos` tags**, full Xcode, and a simulator matching `IOS_SIMULATOR_NAME`. Without that runner the job remains pending; the Linux validation job is not an iOS test substitute. No signing credentials are required for CI simulator tests.

## Privacy And Persistence

Only boards, settings, timing, and aggregate game counters are stored in the app's UserDefaults container. The privacy manifest declares the app-only UserDefaults required-reason API. No data is collected or transmitted. Corrupt or incompatible saved data resets safely to a fresh game. Stats count a daily board when opened and each unique line once per board. Best time measures active app time, not elapsed wall-clock meeting time.

## Contributing

Keep the pure engine independent of UI frameworks, add meaningful tests for changed game rules, and run simulator tests before merging. Avoid paid entitlements, network dependencies, or credentials. Source files are discovered by Xcode's synchronized folders. Regenerate the original icon with `swift tools/GenerateIcon.swift`; it requires only macOS AppKit. `.gitignore` and `kilo.json` protect common secret/signing file paths, but those guardrails do not replace careful review. Do not commit generated build output or personal signing settings.
