// By Dennis Müller

import Foundation
import Observation
import SwiftUI
import Tessera

@Observable @MainActor
final class TesseraEditorModel {
  @ObservationIgnored private var documentBinding: Binding<TesseraDocument>
  @ObservationIgnored private var isApplyingDocumentUpdate: Bool = false
  @ObservationIgnored private var pendingDocumentWrite: TesseraDocument?
  @ObservationIgnored private var pendingDocumentWriteTask: Task<Void, Never>?

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

  var patternMode: PatternMode {
    didSet {
      guard isApplyingDocumentUpdate == false else { return }

      updateDocumentPayload { payload in
        payload.settings.patternMode = patternMode
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

  var canvasSize: CGSize {
    didSet {
      guard isApplyingDocumentUpdate == false else { return }

      updateDocumentPayload { payload in
        payload.settings.canvasSize = CGSizePayload(canvasSize)
      }
      scheduleUpdate()
    }
  }

  var fixedItems: [EditableFixedItem] {
    didSet {
      guard isApplyingDocumentUpdate == false else { return }

      updateDocumentPayload { payload in
        payload.settings.fixedItems = fixedItems.map(\.payload)
      }
      updateEmbeddedImageAssetsFromItems()
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

  var maximumItemCount: Int {
    didSet {
      guard isApplyingDocumentUpdate == false else { return }

      let clampedValue = max(0, maximumItemCount)
      if clampedValue != maximumItemCount {
        maximumItemCount = clampedValue
        return
      }

      updateDocumentPayload { payload in
        payload.settings.maximumItemCount = maximumItemCount
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

  var activePatternSize: CGSize {
    switch patternMode {
    case .tile:
      tesseraSize
    case .canvas:
      canvasSize
    }
  }

  init(document: Binding<TesseraDocument>) {
    documentBinding = document
    let payload = document.wrappedValue.payload
    let embeddedAssets = document.wrappedValue.embeddedImageAssets

    let initialItems = payload.items.map { EditableItem(payload: $0, embeddedAssets: embeddedAssets) }
    let initialStageBackgroundColor = payload.settings.stageBackgroundColor?.color
    let initialPatternMode = payload.settings.patternMode
    let initialTesseraSize = payload.settings.tesseraSize.coreGraphicsSize
    let initialCanvasSize = payload.settings.canvasSize.coreGraphicsSize
    let initialFixedItems = payload.settings.fixedItems.map { EditableFixedItem(
      payload: $0,
      embeddedAssets: embeddedAssets,
    ) }
    let initialSeed = payload.settings.tesseraSeed
    let initialMinimumSpacing = CGFloat(payload.settings.minimumSpacing)
    let initialMaximumItemCount = payload.settings.maximumItemCount
    let initialDensity = payload.settings.density
    let initialBaseScaleRange = payload.settings.baseScaleRange.range
    let initialPatternOffset = payload.settings.patternOffset.coreGraphicsSize

    tesseraItems = initialItems
    stageBackgroundColor = initialStageBackgroundColor
    patternMode = initialPatternMode
    tesseraSize = initialTesseraSize
    canvasSize = initialCanvasSize
    fixedItems = initialFixedItems
    tesseraSeed = initialSeed
    minimumSpacing = initialMinimumSpacing
    maximumItemCount = initialMaximumItemCount
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
      maximumItemCount: initialMaximumItemCount,
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
    patternMode = payload.settings.patternMode
    tesseraSize = payload.settings.tesseraSize.coreGraphicsSize
    canvasSize = payload.settings.canvasSize.coreGraphicsSize
    fixedItems = payload.settings.fixedItems.map { EditableFixedItem(payload: $0, embeddedAssets: embeddedAssets) }
    tesseraSeed = payload.settings.tesseraSeed
    minimumSpacing = CGFloat(payload.settings.minimumSpacing)
    maximumItemCount = payload.settings.maximumItemCount
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
      var referencedAssetIDs = Set<UUID>()
      referencedAssetIDs.formUnion(tesseraItems.compactMap(\.specificOptions.imagePlaygroundAssetID))
      referencedAssetIDs.formUnion(tesseraItems.compactMap(\.specificOptions.uploadedImageAssetID))
      referencedAssetIDs.formUnion(fixedItems.compactMap(\.specificOptions.imagePlaygroundAssetID))
      referencedAssetIDs.formUnion(fixedItems.compactMap(\.specificOptions.uploadedImageAssetID))

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

      for item in tesseraItems {
        guard let assetID = item.specificOptions.uploadedImageAssetID else { continue }
        guard let imageData = item.specificOptions.uploadedImageData else { continue }

        let fileExtension: String = if let itemExtension = item.specificOptions.uploadedImageFileExtension,
                                       itemExtension.isEmpty == false {
          itemExtension.lowercased()
        } else {
          "png"
        }

        updatedAssets[assetID] = EmbeddedImageAsset(data: imageData, fileExtension: fileExtension)
      }

      for fixedItem in fixedItems {
        guard let assetID = fixedItem.specificOptions.imagePlaygroundAssetID else { continue }
        guard let imageData = fixedItem.specificOptions.imagePlaygroundImageData else { continue }

        let fileExtension: String = if let fixedItemExtension = fixedItem.specificOptions.imagePlaygroundFileExtension,
                                       fixedItemExtension.isEmpty == false {
          fixedItemExtension.lowercased()
        } else {
          "png"
        }

        updatedAssets[assetID] = EmbeddedImageAsset(data: imageData, fileExtension: fileExtension)
      }

      for fixedItem in fixedItems {
        guard let assetID = fixedItem.specificOptions.uploadedImageAssetID else { continue }
        guard let imageData = fixedItem.specificOptions.uploadedImageData else { continue }

        let fileExtension: String = if let fixedItemExtension = fixedItem.specificOptions.uploadedImageFileExtension,
                                       fixedItemExtension.isEmpty == false {
          fixedItemExtension.lowercased()
        } else {
          "png"
        }

        updatedAssets[assetID] = EmbeddedImageAsset(data: imageData, fileExtension: fileExtension)
      }

      document.embeddedImageAssets = updatedAssets
    }
  }

  private func updateDocument(_ update: (inout TesseraDocument) -> Void) {
    var document = pendingDocumentWrite ?? documentBinding.wrappedValue
    update(&document)
    pendingDocumentWrite = document

    if pendingDocumentWriteTask == nil {
      pendingDocumentWriteTask = Task { @MainActor [weak self] in
        await Task.yield()
        guard let self else { return }

        let documentToWrite = pendingDocumentWrite
        pendingDocumentWrite = nil
        pendingDocumentWriteTask = nil

        if let documentToWrite {
          documentBinding.wrappedValue = documentToWrite
        }
      }
    }
  }

  private func makeConfiguration() -> TesseraConfiguration {
    TesseraConfiguration(
      items: visibleItems.map { $0.makeTesseraItem() },
      seed: tesseraSeed,
      minimumSpacing: minimumSpacing,
      density: density,
      baseScaleRange: baseScaleRange,
      patternOffset: patternOffset,
      maximumItemCount: maximumItemCount,
    )
  }
}
