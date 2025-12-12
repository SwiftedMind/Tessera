// By Dennis Müller

import Foundation
import SwiftUI
@testable import TesseraApp
import Testing
import UniformTypeIdentifiers

struct TesseraAppTests {
  @Test func payloadRoundTripPreservesEditorState() async throws {
    let embeddedAssetIdentifier = UUID()
    let embeddedAssetFileExtension = "png"
    let embeddedAssetData = Data([0, 1, 2, 3, 4])

    let itemStyle = ItemStylePayload(
      size: CGSizePayload(width: 64, height: 64),
      color: ColorPayload(red: 0.1, green: 0.2, blue: 0.3, alpha: 1),
      lineWidth: 2,
      fontSize: 12,
    )

    let itemPayload = EditableItemPayload(
      id: UUID(),
      customName: "Playground Image",
      presetID: "imagePlayground",
      isVisible: true,
      weight: 1,
      minimumRotation: 0,
      maximumRotation: 360,
      usesCustomScaleRange: false,
      minimumScale: 0.6,
      maximumScale: 1.2,
      style: itemStyle,
      specificOptions: .imagePlayground(
        embeddedAssetIDString: embeddedAssetIdentifier.uuidString,
        embeddedAssetFileExtension: embeddedAssetFileExtension,
      ),
    )

    let payload = TesseraDocumentPayload(
      schemaVersion: 4,
      settings: TesseraSettingsPayload(
        patternMode: .tile,
        tesseraSize: CGSizePayload(width: 200, height: 150),
        canvasSize: CGSizePayload(width: 300, height: 200),
        tesseraSeed: 42,
        minimumSpacing: 12,
        density: 0.5,
        baseScaleRange: ClosedRangePayload(lowerBound: 0.7, upperBound: 1.1),
        patternOffset: CGSizePayload(width: 3, height: 4),
        maximumItemCount: 900,
        stageBackgroundColor: ColorPayload(red: 0.9, green: 0.1, blue: 0.2, alpha: 1),
        fixedItems: [],
      ),
      items: [itemPayload],
    )

    let encodedPayloadData = try JSONEncoder().encode(payload)
    let decodedPayload = try JSONDecoder().decode(TesseraDocumentPayload.self, from: encodedPayloadData)

    #expect(decodedPayload == payload)

    let embeddedAssets = [
      embeddedAssetIdentifier: EmbeddedImageAsset(
        data: embeddedAssetData,
        fileExtension: embeddedAssetFileExtension,
      ),
    ]

    let document = TesseraDocument(payload: payload, embeddedImageAssets: embeddedAssets)
    let fileWrapper = try document.makeFileWrapper()

    #expect(fileWrapper.isDirectory)
    let packageContents = try #require(fileWrapper.fileWrappers)

    let documentJSONWrapper = try #require(packageContents["Document.json"])
    let documentJSONData = try #require(documentJSONWrapper.regularFileContents)
    let reloadedPayload = try JSONDecoder().decode(TesseraDocumentPayload.self, from: documentJSONData)
    #expect(reloadedPayload == payload)

    let assetsWrapper = try #require(packageContents["Assets"])
    let assetsContents = try #require(assetsWrapper.fileWrappers)
    let expectedAssetFileName = "\(embeddedAssetIdentifier.uuidString).\(embeddedAssetFileExtension)"
    let embeddedFileWrapper = try #require(assetsContents[expectedAssetFileName])
    let embeddedFileData = try #require(embeddedFileWrapper.regularFileContents)
    #expect(embeddedFileData == embeddedAssetData)
  }
}
