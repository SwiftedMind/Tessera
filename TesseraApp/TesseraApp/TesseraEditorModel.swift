// By Dennis Müller

import Foundation
import Observation
import SwiftUI
import Tessera

@Observable
final class TesseraEditorModel {
  var tesseraItems: [EditableItem] {
    didSet {
      scheduleUpdate(debounce: .seconds(1))
    }
  }
  
  var tesseraSize: CGSize {
    didSet {
      scheduleUpdate()
    }
  }
  
  var tesseraSeed: UInt64 {
    didSet {
      scheduleUpdate()
    }
  }
  
  var minimumSpacing: CGFloat {
    didSet {
      scheduleUpdate()
    }
  }
  
  var densityDraft: Double
  
  var density: Double {
    didSet {
      densityDraft = density
      scheduleUpdate()
    }
  }

  var baseScaleRange: ClosedRange<CGFloat> {
    didSet {
      scheduleUpdate()
    }
  }
  
  private(set) var liveTessera: Tessera

  private var updateTask: Task<Void, Never>?

  init(
    tesseraItems: [EditableItem] = EditableItem.demoItems,
    tesseraSize: CGSize = CGSize(width: 256, height: 256),
    tesseraSeed: UInt64 = 0,
    minimumSpacing: CGFloat = 10,
    density: Double = 0.8,
    baseScaleRange: ClosedRange<CGFloat> = 0.5...1.2,
  ) {
    self.tesseraItems = tesseraItems
    self.tesseraSize = tesseraSize
    self.tesseraSeed = tesseraSeed
    self.minimumSpacing = minimumSpacing
    self.density = density
    densityDraft = density
    self.baseScaleRange = baseScaleRange
    liveTessera = Tessera(
      size: tesseraSize,
      items: tesseraItems.map { $0.makeTesseraItem() },
      seed: tesseraSeed,
      minimumSpacing: minimumSpacing,
      density: density,
      baseScaleRange: baseScaleRange,
    )
  }

  func shuffleSeed() {
    tesseraSeed = Tessera.randomSeed()
  }

  func commitDensityDraft() {
    density = densityDraft
  }

  func refreshLiveTessera() {
    liveTessera = makeTessera()
  }

  private func scheduleUpdate(debounce: Duration = .milliseconds(200)) {
    updateTask?.cancel()
    updateTask = Task { @MainActor in
      try? await Task.sleep(for: debounce )
      liveTessera = makeTessera()
    }
  }

  private func makeTessera() -> Tessera {
    Tessera(
      size: tesseraSize,
      items: tesseraItems.map { $0.makeTesseraItem() },
      seed: tesseraSeed,
      minimumSpacing: minimumSpacing,
      density: density,
      baseScaleRange: baseScaleRange,
    )
  }
}
