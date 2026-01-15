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

## Project guidelines

### Documentation

- If you touch it, give it solid doc strings.
- For anything non-trivial, leave a comment explaining the "what" and “why”.

### Swift & file conventions

- Prefer descriptive, English-like names (skip abbreviations unless they’re truly standard).
- If a file is getting large or multi-purpose, feel free to split it into reusable components when that improves clarity.

### SwiftUI view organization

- In view types, declare properties as `var` (not `let`).
- Use `#Preview` for previews.
- For state-driven animation, prefer `.animation(.default, value: ...)` over scattered `withAnimation`.
  - Put `.animation` as high in the hierarchy as you can so containers/scroll views animate naturally.
- Prefer `$`-derived bindings (`$state`, `$binding`, `@Bindable` projections).
  - Avoid manual `Binding(get:set:)` unless it genuinely simplifies an adaptation (optional defaults, type bridging, etc.). If you do use it, leave a short note explaining why.
- Prefer `.onChange(of: value) { ... }` with no closure arguments; read `value` inside the closure.
- Push `@State` as deep as possible, but keep it as high as necessary. Don’t default to hoisting everything to the root.

---

## Build & test commands (copy/paste)

- Build from the repository root with `swift build --quiet`.
- Test from the repository root with `swift test --quiet`.
- Prefer `swift build --quiet` to reduce noise; only drop `--quiet` when debugging a failure.
