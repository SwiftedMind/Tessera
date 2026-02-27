// By Dennis Müller

import Foundation

/// Groups related examples into a section shown in the main demo list.
struct DemoCatalogSection: Identifiable {
  let id: String
  let title: String
  let summary: String
  let examples: [DemoCatalogExample]

  func replacingExamples(_ examples: [DemoCatalogExample]) -> Self {
    Self(id: id, title: title, summary: summary, examples: examples)
  }
}

/// Stores display metadata and destination for a single demo entry.
struct DemoCatalogExample: Identifiable {
  let destination: DemoDestination
  let title: String
  let summary: String
  let systemImage: String

  var id: DemoDestination { destination }

  func matches(query: String) -> Bool {
    title.localizedCaseInsensitiveContains(query)
      || summary.localizedCaseInsensitiveContains(query)
      || destination.rawValue.localizedCaseInsensitiveContains(query)
  }
}

/// Registry of all navigable example destinations in the demo app.
enum DemoDestination: String, Hashable, Identifiable {
  case tiledCanvas
  case finiteCanvas
  case gridPlacement
  case gridColumnMajor
  case gridSubgrids
  case choiceSymbols
  case choiceIndexSequence
  case polygonRegion
  case alphaMaskRegion
  case organicSpacingGradient
  case organicScaleGradient
  case gridScaleGradient
  case organicRadialScale
  case organicRotationGradient
  case gridRadialRotation
  case gridRotationGradient
  case collisionShapeEditor

  var id: String { rawValue }
}
