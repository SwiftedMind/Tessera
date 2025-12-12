// By Dennis Müller

import Foundation
import Observation
import SwiftUI
import Tessera

@Observable @MainActor
final class TesseraEditorModel {
  @ObservationIgnored private var documentBinding: Binding<TesseraDocument>
  @ObservationIgnored private var isApplyingDocumentUpdate: Bool = false

  var tesseraItems: [EditableItem] {
    didSet {
      guard isApplyingDocumentUpdate == false else { return }

      updateDocumentPayload { payload in
        payload.items = tesseraItems.map(\.payload)
      }
      updateEmbeddedImageAssetsFromItems()

      if oldValue.count != tesseraItems.count {
        scheduleUpdate(debounce: .seconds(0.8))
      } else {
        scheduleUpdate()
      }
    }
  }

  /// Background color shown behind the stage preview.
  ///
  /// Set to `nil` to show no background.
  var stageBackgroundColor: Color? {
    didSet {
      guard isApplyingDocumentUpdate == false else { return }

      updateDocumentPayload { payload in
        payload.settings.stageBackgroundColor = stageBackgroundColor.map(ColorPayload.init)
      }
    }
  }

  var tesseraSize: CGSize {
    didSet {
      guard isApplyingDocumentUpdate == false else { return }

      updateDocumentPayload { payload in
        payload.settings.tesseraSize = CGSizePayload(tesseraSize)
      }
      scheduleUpdate()
    }
  }

  var tesseraSeed: UInt64 {
    didSet {
      guard isApplyingDocumentUpdate == false else { return }

      updateDocumentPayload { payload in
        payload.settings.tesseraSeed = tesseraSeed
      }
      scheduleUpdate()
    }
  }

  var minimumSpacing: CGFloat {
    didSet {
      guard isApplyingDocumentUpdate == false else { return }

      updateDocumentPayload { payload in
        payload.settings.minimumSpacing = Double(minimumSpacing)
      }
      scheduleUpdate()
    }
  }

  var densityDraft: Double

  var density: Double {
    didSet {
      densityDraft = density
      guard isApplyingDocumentUpdate == false else { return }

      updateDocumentPayload { payload in
        payload.settings.density = density
      }
      scheduleUpdate()
    }
  }

  var baseScaleRange: ClosedRange<Double> {
    didSet {
      guard isApplyingDocumentUpdate == false else { return }

      updateDocumentPayload { payload in
        payload.settings.baseScaleRange = ClosedRangePayload(baseScaleRange)
      }
      scheduleUpdate()
    }
  }

  var patternOffset: CGSize {
    didSet {
      guard isApplyingDocumentUpdate == false else { return }

      updateDocumentPayload { payload in
        payload.settings.patternOffset = CGSizePayload(patternOffset)
      }
      scheduleUpdate()
    }
  }

  private(set) var liveConfiguration: TesseraConfiguration

  private var updateTask: Task<Void, Never>?
  private var visibleItems: [EditableItem] {
    tesseraItems.filter(\.isVisible)
  }

  init(document: Binding<TesseraDocument>) {
    documentBinding = document
    let payload = document.wrappedValue.payload
    let embeddedAssets = document.wrappedValue.embeddedImageAssets

    let initialItems = payload.items.map { EditableItem(payload: $0, embeddedAssets: embeddedAssets) }
    let initialStageBackgroundColor = payload.settings.stageBackgroundColor?.color
    let initialTesseraSize = payload.settings.tesseraSize.coreGraphicsSize
    let initialSeed = payload.settings.tesseraSeed
    let initialMinimumSpacing = CGFloat(payload.settings.minimumSpacing)
    let initialDensity = payload.settings.density
    let initialBaseScaleRange = payload.settings.baseScaleRange.range
    let initialPatternOffset = payload.settings.patternOffset.coreGraphicsSize

    tesseraItems = initialItems
    stageBackgroundColor = initialStageBackgroundColor
    tesseraSize = initialTesseraSize
    tesseraSeed = initialSeed
    minimumSpacing = initialMinimumSpacing
    density = initialDensity
    densityDraft = initialDensity
    baseScaleRange = initialBaseScaleRange
    patternOffset = initialPatternOffset

    let initialVisibleItems = initialItems.filter(\.isVisible)
    liveConfiguration = TesseraConfiguration(
      items: initialVisibleItems.map { $0.makeTesseraItem() },
      seed: initialSeed,
      minimumSpacing: initialMinimumSpacing,
      density: initialDensity,
      baseScaleRange: initialBaseScaleRange,
      patternOffset: initialPatternOffset,
    )
  }

  func shuffleSeed() {
    tesseraSeed = TesseraConfiguration.randomSeed()
  }

  func commitDensityDraft() {
    density = densityDraft
  }

  func refreshLiveConfiguration() {
    liveConfiguration = makeConfiguration()
  }

  func reloadFromDocument() {
    isApplyingDocumentUpdate = true
    let payload = documentBinding.wrappedValue.payload
    let embeddedAssets = documentBinding.wrappedValue.embeddedImageAssets

    tesseraItems = payload.items.map { EditableItem(payload: $0, embeddedAssets: embeddedAssets) }
    stageBackgroundColor = payload.settings.stageBackgroundColor?.color
    tesseraSize = payload.settings.tesseraSize.coreGraphicsSize
    tesseraSeed = payload.settings.tesseraSeed
    minimumSpacing = CGFloat(payload.settings.minimumSpacing)
    density = payload.settings.density
    densityDraft = payload.settings.density
    baseScaleRange = payload.settings.baseScaleRange.range
    patternOffset = payload.settings.patternOffset.coreGraphicsSize

    isApplyingDocumentUpdate = false
    refreshLiveConfiguration()
  }

  private func scheduleUpdate(debounce: Duration = .milliseconds(0)) {
    updateTask?.cancel()
    updateTask = Task {
      do {
        try await Task.sleep(for: debounce)
        liveConfiguration = makeConfiguration()
      } catch {}
    }
  }

  private func updateDocumentPayload(_ update: (inout TesseraDocumentPayload) -> Void) {
    updateDocument { document in
      update(&document.payload)
    }
  }

  private func updateEmbeddedImageAssetsFromItems() {
    updateDocument { document in
      let referencedAssetIDs = Set(
        tesseraItems.compactMap(\.specificOptions.imagePlaygroundAssetID),
      )

      var updatedAssets = document.embeddedImageAssets.filter { referencedAssetIDs.contains($0.key) }

      for item in tesseraItems {
        guard let assetID = item.specificOptions.imagePlaygroundAssetID else { continue }
        guard let imageData = item.specificOptions.imagePlaygroundImageData else { continue }

        let fileExtension: String = if let itemExtension = item.specificOptions.imagePlaygroundFileExtension,
                                       itemExtension.isEmpty == false {
          itemExtension.lowercased()
        } else {
          "png"
        }

        updatedAssets[assetID] = EmbeddedImageAsset(data: imageData, fileExtension: fileExtension)
      }

      document.embeddedImageAssets = updatedAssets
    }
  }

  private func updateDocument(_ update: (inout TesseraDocument) -> Void) {
    var document = documentBinding.wrappedValue
    update(&document)
    documentBinding.wrappedValue = document
  }

  private func makeConfiguration() -> TesseraConfiguration {
    TesseraConfiguration(
      items: visibleItems.map { $0.makeTesseraItem() },
      seed: tesseraSeed,
      minimumSpacing: minimumSpacing,
      density: density,
      baseScaleRange: baseScaleRange,
      patternOffset: patternOffset,
    )
  }
}
