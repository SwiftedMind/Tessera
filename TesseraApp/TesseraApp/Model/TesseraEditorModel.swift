// By Dennis Müller

import Foundation
import Observation
import SwiftUI
import Tessera

@Observable @MainActor
final class TesseraEditorModel {
  var tesseraItems: [EditableItem] {
    didSet {
      if oldValue.count != tesseraItems.count {
        scheduleUpdate(debounce: .seconds(0.8))
      } else {
        scheduleUpdate()
      }
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

  var baseScaleRange: ClosedRange<Double> {
    didSet {
      scheduleUpdate()
    }
  }

  var patternOffset: CGSize {
    didSet {
      scheduleUpdate()
    }
  }

  private(set) var liveTessera: Tessera

  private var updateTask: Task<Void, Never>?
  private var visibleItems: [EditableItem] {
    tesseraItems.filter(\.isVisible)
  }

  init(
    tesseraItems: [EditableItem]? = nil,
    tesseraSize: CGSize = CGSize(width: 256, height: 256),
    tesseraSeed: UInt64 = 0,
    minimumSpacing: Double = 10,
    density: Double = 0.8,
    baseScaleRange: ClosedRange<Double> = 0.5...1.2,
    patternOffset: CGSize = .zero,
  ) {
    let tesseraItems = tesseraItems ?? []

    self.tesseraItems = tesseraItems
    self.tesseraSize = tesseraSize
    self.tesseraSeed = tesseraSeed
    self.minimumSpacing = minimumSpacing
    self.density = density
    densityDraft = density
    self.baseScaleRange = baseScaleRange
    self.patternOffset = patternOffset
    let initialVisibleItems = tesseraItems.filter(\.isVisible)
    liveTessera = Tessera(
      size: tesseraSize,
      items: initialVisibleItems.map { $0.makeTesseraItem() },
      seed: tesseraSeed,
      minimumSpacing: minimumSpacing,
      density: density,
      baseScaleRange: baseScaleRange,
      patternOffset: patternOffset,
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

  private func scheduleUpdate(debounce: Duration = .milliseconds(0)) {
    updateTask?.cancel()
    updateTask = Task {
      do {
        try await Task.sleep(for: debounce)
        liveTessera = makeTessera()
      } catch {}
    }
  }

  private func makeTessera() -> Tessera {
    Tessera(
      size: tesseraSize,
      items: visibleItems.map { $0.makeTesseraItem() },
      seed: tesseraSeed,
      minimumSpacing: minimumSpacing,
      density: density,
      baseScaleRange: baseScaleRange,
      patternOffset: patternOffset,
    )
  }
}
