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

## Subagents
- ALWAYS wait for all subagents to complete before yielding.
- Spawn subagents automatically when:
  - Parallelizable work
  - Long-running or blocking tasks where a worker can run independently. 
  - Isolation for risky changes or checks

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
- Do not use xcodebuild, xcrun simctl, swift or other Apple CLI tools unless FlowDeck is unavailable.
- Do not use `swift build` or `swift test` or other Swift Package related commands unless FlowDeck is unavailable.
- If a FlowDeck command fails, troubleshoot using FlowDeck output and retry before falling back.

### Shortcuts

- Use this section to proactively and autonomously manage common flowdeck commands.
- Whenever you use a command that likely will be reused, proactively add it in this section
- Proactively keep the commands up to date, like when the scheme or devices change. 
