# AGENTS.md

Tessera is a Swift package that turns a single generated tile composed of arbitrary SwiftUI views into an endlessly repeating, seamlessly wrapping pattern.

This document gives a high-level view of how the project is structured and how it is intended to evolve, so that contributors can extend it without breaking the overall design.

---

## How to work in this repo

These are the defaults and conventions that keep changes consistent and easy to review.

### Expectations

- **After code changes:** build the app to make sure it still compiles.
- **After test changes:** run the relevant unit/UI tests (and the suite when appropriate).
- **Text & localization:** use the repo’s SwiftUI localization approach (String Catalog with plain `Text` / `LocalizedStringKey`).
- **Style bias:** readability beats cleverness; keep types and files small where possible.
- **Commits:** only commit when you’re explicitly asked to.

### Before you wrap up

- Always build the project for all supported platforms (and run tests if your changes touch them or could reasonably affect them).
- If you changed Swift files, always run: `swiftformat --config ".swiftformat" {files}`

---

## Code Review

- Every code review must include a full pass of the `$simplify-code` skill.

## Code Readability Skill

- Optimize for readability and traceability before cleverness or DRY in non-performance-critical paths.
- Keep behavior-defining logic explicit and centralized so case behavior is visible in one obvious place.
- Keep indirection shallow; avoid registry/flag/dispatch patterns for simple mappings.
- Allow small duplication when it improves local reasoning; abstractions must improve readability, correctness, testability, or proven reuse.

---

## Project guidelines

### Documentation

- If you touch it, give it solid doc strings.
- For anything non-trivial, leave a comment explaining the "what" and “why”.

### Swift & file conventions

- Prefer descriptive, English-like names (skip abbreviations unless they’re truly standard).
- If a file is getting large or multi-purpose, feel free to split it into reusable components when that improves clarity.

### SwiftUI view organization

- Prefer composition; keep views small and focused.
- Avoid “actions” extensions on views; keep `@State` private. If logic grows, split into subviews or helper types instead of moving long functions into `extension SomeView`
- Apply local conventions: prefer SwiftUI-native state, keep state local when possible, and use environment injection for shared dependencies.
- Prefer a shared `@Observable` session/model injected via `@Environment` for heavily shared state to keep view initializers compact.
- Use `#Preview(traits: .tesseraDesigner)` for previews.
- For state-driven animation, prefer `.animation(.default, value: ...)` over scattered `withAnimation`.
- Prefer `$`-derived bindings (`$state`, `$binding`, `@Bindable` projections).
  - Prefer state-derived bindings + `onChange` side effects; use IdentifiedCollections for ID-based access instead of index-based bindings.
- Prefer `.onChange(of: value) { ... }` with no closure arguments; read `value` inside the closure.
- Use async/await with .task and explicit loading/error states.
- Use `@ViewBuilder` where possible

---

## Build & test commands

- Use the FlowDeck skill and CLI for all iOS/macOS build, run, test, and debug tasks.
- Always point FlowDeck at the repo workspace, `Tessera.xcworkspace`, for repo build and test commands. Do not target `Examples/ExampleApp.xcodeproj` when you need package schemes.
- The primary build scheme is `ExampleApp`. It builds the demo app and the SDK together.
- The primary test scheme is `TesseraTests`.
- Reuse the agent-owned derived data folders `.xcode-deriveddata/ios`, `.xcode-deriveddata/tesseratests-ios`, and `.xcode-deriveddata/macos` for incremental work. These folders are reserved for coding-agent work in this repo and are not shared with other users.
- When updating, resolving, or clearing Swift packages, always target the same `--derived-data-path` as the build or test root you will validate next. Otherwise FlowDeck can refresh one `SourcePackages` cache while the later build or test keeps reading a different stale cache.
- If build and test may overlap, keep them on separate derived-data roots. Sharing one iOS root across concurrent FlowDeck commands can lock `Build/Intermediates.noindex/XCBuildData/build.db`.
- Do not use xcodebuild, xcrun simctl, or other Apple CLI tools unless FlowDeck is unavailable.
- If a FlowDeck command fails, troubleshoot using FlowDeck output and retry before falling back.
- Use `flowdeck context --json` to resolve an iOS simulator first. Use a simulator UDID when the name is ambiguous.
- `flowdeck test discover` currently reports `No tests found` for `TesseraTests` in this workspace even though the suite runs. Treat `flowdeck test --verbose` as the source of truth for package test results here.
- If package resolution fails with `Couldn’t check out revision` / `fatal: unable to read tree`, retry on the affected root in this order: `update --derived-data-path ...`, `resolve --derived-data-path ...`, `clear --derived-data-path ...`, then rerun the same build or test command.

### Shortcuts

- Use this section to proactively and autonomously manage common flowdeck commands.
- Whenever you use a command that likely will be reused, proactively add it in this section
- Proactively keep the commands up to date, like when the scheme or devices change.

- Resolve simulators: `flowdeck context --json`
- List schemes: `flowdeck project schemes -w "$PWD/Tessera.xcworkspace"`
- Update packages for ExampleApp builds: `flowdeck project packages update -w "$PWD/Tessera.xcworkspace" -s "ExampleApp" --derived-data-path ".xcode-deriveddata/ios"`
- Resolve packages for ExampleApp builds: `flowdeck project packages resolve -w "$PWD/Tessera.xcworkspace" -s "ExampleApp" --derived-data-path ".xcode-deriveddata/ios"`
- Clear packages for ExampleApp builds: `flowdeck project packages clear -w "$PWD/Tessera.xcworkspace" --derived-data-path ".xcode-deriveddata/ios"`
- Update packages for TesseraTests runs: `flowdeck project packages update -w "$PWD/Tessera.xcworkspace" -s "TesseraTests" --derived-data-path ".xcode-deriveddata/tesseratests-ios"`
- Resolve packages for TesseraTests runs: `flowdeck project packages resolve -w "$PWD/Tessera.xcworkspace" -s "TesseraTests" --derived-data-path ".xcode-deriveddata/tesseratests-ios"`
- Clear packages for TesseraTests runs: `flowdeck project packages clear -w "$PWD/Tessera.xcworkspace" --derived-data-path ".xcode-deriveddata/tesseratests-ios"`
- Build ExampleApp: `flowdeck build -w "$PWD/Tessera.xcworkspace" -s "ExampleApp" -S "<SIMULATOR_UDID>" -d ".xcode-deriveddata/ios"`
- Run TesseraTests: `flowdeck test -w "$PWD/Tessera.xcworkspace" -s "TesseraTests" -S "<SIMULATOR_UDID>" -d ".xcode-deriveddata/tesseratests-ios" --verbose`
