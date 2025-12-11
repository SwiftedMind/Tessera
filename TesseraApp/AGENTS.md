# AGENTS.md — TesseraApp Architecture & Contribution Guide

> **Read this file first whenever you touch anything inside `TesseraApp/`.**

TesseraApp is a macOS SwiftUI editor that uses the Tessera Swift package to design, preview, and export seamless tiling patterns.

---

## General Instructions

Pay attention to these general instructions and closely follow them!

- When you change code, build the app afterwards to ensure it still compiles.
- When you modify unit or UI tests, run the test suite.
- Follow the repository naming and SwiftUI text localization rules (string catalog with plain `Text`/`LocalizedStringKey`).
- Prefer readability over conciseness.
- Never commit unless instructed to do so.

### **IMPORTANT**: Before you start

- Read `TesseraApp/AGENTS.md` together with the root `AGENTS.md`; the root guide still applies to shared tooling and style rules.
- Check Internal and External Resources in the root guide for anything relevant (docstrings, commit rules, etc.).

### When you are done

- Build the macOS target with `xcodebuild -project TesseraApp.xcodeproj -scheme "TesseraApp Debug" -destination 'platform=macOS' -quiet`.
- Run tests when you touched test targets: `xcodebuild test -project TesseraApp.xcodeproj -scheme "TesseraApp Debug" -destination 'platform=macOS' -quiet`.
- After changing Swift files, run `swiftformat --config "../.swiftformat" {files}` from the `TesseraApp` directory.

## Symbol Inspection (`monocle` cli)

- Treat the `monocle` cli as your **default tool** for Swift symbol info. 
  Whenever you need the definition file, signature, parameters, or doc comment for any Swift symbol (type, class, struct, enum, method, property, etc.), call `monocle` rather than guessing or doing project-wide searches.
- Resolve the symbol at a specific location: `monocle inspect --file <path> --line <line> --column <column> --json`
- Line and column values are **1-based**, not 0-based; the column must point inside the identifier
- Search workspace symbols by name when you only know the identifier: `monocle symbol --query "TypeOrMember" --limit 5 --enrich --json`.
  - `--limit` caps the number of results (default 5).
  - `--enrich` fetches signature, documentation, and the precise definition location for each match.
- Use `monocle` especially for symbols involved in errors/warnings or coming from external package dependencies.

## Internal Resources

Use these documents proactively whenever you work on the corresponding area; they define the constraints and patterns you must follow.

- `agents/guidelines/commit.md` — Commit guidelines (root).
- `agents/swift/docc.md` — Docstring guidance for Swift (root).

---

## Build Instructions

- Build from `TesseraApp/` with `xcodebuild -workspace Tessera.xcworkspace -scheme "TesseraApp Debug" -destination 'platform=macOS' -quiet`.
- Prefer the `-quiet` flag at all times; only drop it when debugging a failure.
- Use the `TesseraApp Production` scheme only when preparing a release artifact; keep `-quiet` there as well.

## Architectural Structural Overview

- **Entry Surface**: `TesseraApp` launches `Root`, which hosts the canvas, export menu, and inspector toggle within a `NavigationStack`.
- **Editor Model**: `TesseraEditorModel` is `@Observable @MainActor` and owns tessera configuration (items, size, seed, spacing, density, scale range). It debounces updates and rebuilds `liveTessera` using the Tessera package.
- **Canvas Rendering**: `PatternStage` switches between the seamless `TesseraPattern` view (repeating tile) and a single-tile preview with material framing, animating transitions.
- **Inspector and Controls**: Inspector panels (see `Views/Inspector`, `Views/Pattern`, `Views/Items`) mutate the shared editor model, which propagates through SwiftUI environment.
- **Export Pipeline**: `TesseraExportDocument` implements `FileDocument` to export the current tessera as PNG or PDF using `Tessera.renderPNG`/`renderPDF`, seeded from the live configuration for deterministic output.
- **Editable Items Bridge**: `EditableItem` converts UI-driven properties into `TesseraItem` instances, keeping weighting, rotation, and scaling aligned with the package API.
