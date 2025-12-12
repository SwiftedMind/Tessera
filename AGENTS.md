# AGENTS.md — Architecture & Contribution Guide

Tessera is a Swift package that turns a single generated tile composed of arbitrary SwiftUI views into an endlessly repeating, seamlessly wrapping pattern.

This document gives a high-level view of how the project is structured and how it is intended to evolve, so that contributors can extend it without breaking the overall design.

---

## General Instructions

Pay attention to these general instructions and closely follow them!

- Whenever you make changes to the code, build the project afterwards to ensure everything still compiles.
- Whenever you make changes to unit tests, run the test suite to verify the changes.
- Always prefer readability over conciseness/compactness.
- Never commit unless instructed to do so.

### **IMPORTANT**: Before you start

- Always scan the Internal and External Resources lists for anything that applies to the work you are doing (features, providers, database, AI tools, tests, docstrings, changelog, commits, etc.) and read those guidelines before making changes.
- When asked to commit changes to the repository, always read and understand the commit guidelines before doing anything!
- If you touch anything inside `TesseraApp/`, read `TesseraApp/AGENTS.md` first; its rules apply alongside this file.

### When you are done

- Always build the project to check for compilation errors.
- When you have added or modified Swift files, always run `swiftformat --config ".swiftformat" {files}`.

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

- agents/guidelines/commit.md - Guidelines for committing changes to the repository
- agents/swift/docc.md - Guidelines on writing docstrings in Swift

---

## Build Instructions

- Build from the repository root with `swift build`.
- Prefer `swift build --quiet` to reduce noise; only drop `--quiet` when debugging a failure.

## Architectural Structural Overview

- **Public Surface**: `Sources/Tessera` exposes the SwiftUI-facing API. `Tessera` defines the tile configuration (size, items, spacing, density, seed). `TesseraItem` wraps individual SwiftUI content with weighting, rotation and scaling rules. `TesseraTiledCanvas` is the primary repeating view; it tiles a single tessera tile across a `Canvas`.
- **Rendering Pipeline**: `TesseraTiledCanvas` constructs a single cached symbol (`TesseraCanvasTile`) and draws it in a grid that covers the available space. The tile itself runs deterministic randomness via `SeededGenerator` so the same seed reproduces the same layout.
- **Point Generation**: `Internal/PoissonDiskGenerator` produces evenly spaced candidate points with toroidal wrap-around using Poisson-disc sampling. It clamps fill probability, computes a cell grid, and iteratively accepts candidates that satisfy the minimum spacing.
- **Item Placement**: `Internal/ItemAssigner` walks the generated points in shuffled order, discourages identical neighbors through a wrapped grid lookup, and chooses items by weight when necessary fallback to the full set.
- **Seamless Wrapping**: `TesseraCanvasTile` draws each symbol with a 3×3 offset lattice so symbols that touch edges wrap cleanly when tiles repeat, preserving seamless continuity in both axes.
- **Determinism and Reuse**: Seeds propagate from `Tessera` into `TesseraTiledCanvas` and internal generators, ensuring repeatable outputs while keeping symbol resolution cached for performance during canvas redraws.
