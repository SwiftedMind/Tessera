// By Dennis Müller

import CoreGraphics
import Foundation
import SwiftUI
@testable import Tessera
import Testing

@Test @MainActor func rendererComputesCanvasSnapshot() async throws {
  let pattern = Pattern(
    symbols: [
      Symbol(collider: .automatic(size: CGSize(width: 20, height: 20))) {
        Circle().fill(Color.blue).frame(width: 20, height: 20)
      },
    ],
    placement: .grid(columns: 2, rows: 2),
  )

  let snapshot = try await TesseraRenderer(pattern).makeSnapshot(
    mode: .canvas(size: CGSize(width: 120, height: 120), edgeBehavior: .finite),
  )

  #expect(snapshot.size == CGSize(width: 120, height: 120))
  #expect(snapshot.mode == .canvas(size: CGSize(width: 120, height: 120), edgeBehavior: .finite))
  #expect(snapshot.renderModel.basePlacements.isEmpty == false)
}

@Test @MainActor func fullCoverageMosaicExcludesBasePlacements() async throws {
  let baseSymbol = Symbol(collider: .automatic(size: CGSize(width: 24, height: 24))) {
    Circle().fill(Color.blue).frame(width: 24, height: 24)
  }
  let mosaicFillSymbol = Symbol(collider: .automatic(size: CGSize(width: 24, height: 24))) {
    Rectangle().fill(Color.red).frame(width: 24, height: 24)
  }
  let fullMaskSymbol = Symbol(collider: .automatic(size: CGSize(width: 120, height: 120))) {
    Rectangle()
      .fill(Color.white)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  let mosaic = Mosaic(
    mask: MosaicMask(
      symbol: fullMaskSymbol,
      position: .centered(),
    ),
    symbols: [mosaicFillSymbol],
    placement: .grid(columns: 1, rows: 1),
  )
  let pattern = Pattern(
    symbols: [baseSymbol],
    placement: .grid(columns: 1, rows: 1),
    mosaics: [mosaic],
  )

  let snapshot = try await TesseraRenderer(pattern).makeSnapshot(
    mode: .canvas(size: CGSize(width: 120, height: 120), edgeBehavior: .finite),
  )

  #expect(snapshot.renderModel.basePlacements.isEmpty)
  #expect(snapshot.renderModel.mosaics.count == 1)
  #expect(snapshot.renderModel.mosaics[0].placements.isEmpty == false)
}

@Test @MainActor func overlappingMosaicsDoNotResolveOwnershipWhenMasksOverlap() async throws {
  let fillSymbol = Symbol(collider: .automatic(size: CGSize(width: 20, height: 20))) {
    Circle().fill(Color.blue).frame(width: 20, height: 20)
  }
  let fullMaskSymbol = Symbol(collider: .automatic(size: CGSize(width: 120, height: 120))) {
    Rectangle()
      .fill(Color.white)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  let mosaicA = Mosaic(
    id: UUID(uuidString: "00000000-0000-0000-0000-0000000000C1")!,
    mask: MosaicMask(symbol: fullMaskSymbol),
    symbols: [fillSymbol],
    placement: .grid(columns: 1, rows: 1),
  )
  let mosaicB = Mosaic(
    id: UUID(uuidString: "00000000-0000-0000-0000-0000000000C2")!,
    mask: MosaicMask(symbol: fullMaskSymbol),
    symbols: [fillSymbol],
    placement: .grid(columns: 1, rows: 1),
  )
  let pattern = Pattern(
    symbols: [],
    placement: .grid(columns: 1, rows: 1),
    mosaics: [mosaicA, mosaicB],
  )

  let snapshot = try await TesseraRenderer(pattern).makeSnapshot(
    mode: .canvas(size: CGSize(width: 120, height: 120), edgeBehavior: .finite),
  )

  #expect(snapshot.renderModel.mosaics.count == 2)
  #expect(snapshot.renderModel.mosaics[0].mask.filledFraction > 0.95)
  #expect(snapshot.renderModel.mosaics[1].mask.filledFraction > 0.95)
}

@Test @MainActor func tinyMosaicKeepsLocalizedVectorBoundsInSnapshot() async throws {
  let fillSymbol = Symbol(collider: .automatic(size: CGSize(width: 12, height: 12))) {
    Circle().fill(Color.blue).frame(width: 12, height: 12)
  }
  let maskSymbol = Symbol(collider: .automatic(size: CGSize(width: 60, height: 60))) {
    Circle().fill(Color.white).frame(width: 60, height: 60)
  }

  let mosaic = Mosaic(
    mask: MosaicMask(symbol: maskSymbol, position: .centered()),
    symbols: [fillSymbol],
    placement: .grid(columns: 2, rows: 2),
  )
  let pattern = Pattern(
    symbols: [],
    placement: .grid(columns: 1, rows: 1),
    mosaics: [mosaic],
  )

  let snapshot = try await TesseraRenderer(pattern).makeSnapshot(
    mode: .canvas(size: CGSize(width: 900, height: 900), edgeBehavior: .finite),
  )
  let mask = try #require(snapshot.renderModel.mosaics.first?.mask)
  let bounds = try #require(mask.filledBounds())

  #expect(bounds.width > 0)
  #expect(bounds.height > 0)
  #expect(bounds.width < 900)
  #expect(bounds.height < 900)
}

@Test @MainActor func exportThrowsOnSnapshotFingerprintMismatch() async throws {
  let symbolA = Symbol(collider: .automatic(size: CGSize(width: 20, height: 20))) {
    Circle().fill(Color.blue).frame(width: 20, height: 20)
  }
  let symbolB = Symbol(collider: .automatic(size: CGSize(width: 20, height: 20))) {
    Circle().fill(Color.red).frame(width: 20, height: 20)
  }

  let rendererA = TesseraRenderer(
    Pattern(symbols: [symbolA], placement: .grid(columns: 1, rows: 1)),
  )
  let rendererB = TesseraRenderer(
    Pattern(symbols: [symbolB], placement: .grid(columns: 1, rows: 1)),
  )

  let snapshot = try await rendererA.makeSnapshot(
    mode: .canvas(size: CGSize(width: 80, height: 80), edgeBehavior: .finite),
  )

  #expect(throws: RenderError.snapshotFingerprintMismatch) {
    try rendererB.export(
      .png,
      snapshot: snapshot,
      options: .init(
        directory: FileManager.default.temporaryDirectory,
        fileName: UUID().uuidString,
      ),
    )
  }
}

@Test func alphaMaskWithInvalidBufferFailsSafely() {
  let invalidMask = TesseraAlphaMask(
    size: CGSize(width: 20, height: 20),
    pixelsWide: 4,
    pixelsHigh: 4,
    alphaBytes: [255, 255],
    thresholdByte: 128,
    sampling: .nearest,
    invert: false,
  )

  #expect(invalidMask.contains(CGPoint(x: 10, y: 10)) == false)
  #expect(invalidMask.filledFraction == 0)
  #expect(invalidMask.maskImage() == nil)
}

@Test func alphaMaskRegionFingerprintUsesDeterministicCacheKeyValue() {
  struct CollidingCacheKey: Hashable, Sendable {
    var rawValue: String

    static func == (lhs: CollidingCacheKey, rhs: CollidingCacheKey) -> Bool {
      lhs.rawValue == rhs.rawValue
    }

    func hash(into hasher: inout Hasher) {
      hasher.combine(0)
    }
  }

  let regionA = Region.alphaMask(
    TesseraAlphaMaskRegion(
      cacheKey: TesseraRegionID(CollidingCacheKey(rawValue: "A")),
      source: .view { AnyView(Rectangle().fill(Color.white)) },
    ),
  )
  let regionB = Region.alphaMask(
    TesseraAlphaMaskRegion(
      cacheKey: TesseraRegionID(CollidingCacheKey(rawValue: "B")),
      source: .view { AnyView(Rectangle().fill(Color.white)) },
    ),
  )

  let pattern = Pattern(symbols: [], placement: .grid(columns: 1, rows: 1))
  let requestA = SnapshotRequestKey.make(
    mode: .canvas(size: CGSize(width: 100, height: 100), edgeBehavior: .finite),
    resolvedSeed: 42,
    region: regionA,
    regionRendering: .clipped,
    pinnedSymbols: [],
  )
  let requestB = SnapshotRequestKey.make(
    mode: .canvas(size: CGSize(width: 100, height: 100), edgeBehavior: .finite),
    resolvedSeed: 42,
    region: regionB,
    regionRendering: .clipped,
    pinnedSymbols: [],
  )

  let fingerprintA = TesseraFingerprintBuilder.fingerprint(pattern: pattern, requestKey: requestA)
  let fingerprintB = TesseraFingerprintBuilder.fingerprint(pattern: pattern, requestKey: requestB)
  #expect(fingerprintA != fingerprintB)
}

@Test func mosaicRenderingClipModeMatrixIsStable() {
  #expect(MosaicRendering.contained.clipsToMask)
  #expect(MosaicRendering.clipped.clipsToMask)
  #expect(MosaicRendering.unclipped.clipsToMask == false)
}

@Test @MainActor func snapshotMaskImageCacheRetainsAllMaskRolesForActiveSnapshot() {
  SnapshotMaskImageCache.testingReset()
  defer { SnapshotMaskImageCache.testingReset() }

  let mask = makeOpaqueTestAlphaMask()
  let snapshotFingerprint: UInt64 = 0xC0FFEE
  let mosaicIDs = (0..<12).map { _ in UUID() }

  #expect(SnapshotMaskImageCache.maskView(
    for: mask,
    snapshotFingerprint: snapshotFingerprint,
    role: .globalRegionMask,
  ) != nil)

  for mosaicID in mosaicIDs {
    #expect(SnapshotMaskImageCache.maskView(
      for: mask,
      snapshotFingerprint: snapshotFingerprint,
      role: .mosaic(mosaicID),
    ) != nil)
  }

  let generatedAfterFirstPass = SnapshotMaskImageCache.testingGeneratedImageCount()
  #expect(generatedAfterFirstPass == mosaicIDs.count + 1)

  #expect(SnapshotMaskImageCache.maskView(
    for: mask,
    snapshotFingerprint: snapshotFingerprint,
    role: .globalRegionMask,
  ) != nil)

  for mosaicID in mosaicIDs {
    #expect(SnapshotMaskImageCache.maskView(
      for: mask,
      snapshotFingerprint: snapshotFingerprint,
      role: .mosaic(mosaicID),
    ) != nil)
  }

  #expect(SnapshotMaskImageCache.testingGeneratedImageCount() == generatedAfterFirstPass)
}

@Test @MainActor func snapshotMaskImageCacheEvictsLeastRecentlyUsedSnapshots() {
  SnapshotMaskImageCache.testingReset()
  defer { SnapshotMaskImageCache.testingReset() }

  let mask = makeOpaqueTestAlphaMask()
  for index in 0...SnapshotMaskImageCache.maximumSnapshotCount {
    #expect(SnapshotMaskImageCache.maskView(
      for: mask,
      snapshotFingerprint: UInt64(index),
      role: .globalRegionMask,
    ) != nil)
  }

  let generatedAfterFirstPass = SnapshotMaskImageCache.testingGeneratedImageCount()
  #expect(generatedAfterFirstPass == SnapshotMaskImageCache.maximumSnapshotCount + 1)

  #expect(SnapshotMaskImageCache.maskView(
    for: mask,
    snapshotFingerprint: 0,
    role: .globalRegionMask,
  ) != nil)

  #expect(SnapshotMaskImageCache.testingGeneratedImageCount() == generatedAfterFirstPass + 1)
}

@Test @MainActor func snapshotMaskImageCacheReusesSliceMaskImageForMosaicRole() {
  SnapshotMaskImageCache.testingReset()
  defer { SnapshotMaskImageCache.testingReset() }

  let mask = makeOpaqueTestSliceMask()
  let snapshotFingerprint: UInt64 = 0xBEEF
  let mosaicID = UUID(uuidString: "00000000-0000-0000-0000-00000000BEEF")!

  #expect(SnapshotMaskImageCache.maskView(
    for: mask,
    snapshotFingerprint: snapshotFingerprint,
    role: .mosaic(mosaicID),
  ) != nil)
  let generatedAfterFirstPass = SnapshotMaskImageCache.testingGeneratedImageCount()
  #expect(generatedAfterFirstPass == 1)

  #expect(SnapshotMaskImageCache.maskView(
    for: mask,
    snapshotFingerprint: snapshotFingerprint,
    role: .mosaic(mosaicID),
  ) != nil)
  #expect(SnapshotMaskImageCache.testingGeneratedImageCount() == generatedAfterFirstPass)
}

@Test @MainActor func placementsRespectMosaicMaskBoundaries() async throws {
  let baseSymbol = Symbol(collider: .shape(.rectangle(center: .zero, size: CGSize(width: 28, height: 28)))) {
    RoundedRectangle(cornerRadius: 6, style: .continuous)
      .fill(Color.blue)
      .frame(width: 28, height: 28)
  }
  let mosaicSymbol = Symbol(collider: .shape(.circle(center: .zero, radius: 8))) {
    Circle()
      .fill(Color.red)
      .frame(width: 16, height: 16)
  }
  let maskSymbol = Symbol(collider: .automatic(size: CGSize(width: 96, height: 96))) {
    RoundedRectangle(cornerRadius: 30, style: .continuous)
      .fill(Color.white)
      .frame(width: 92, height: 92)
  }

  let pattern = Pattern(
    symbols: [baseSymbol],
    placement: .grid(columns: 8, rows: 8),
    mosaics: [
      Mosaic(
        mask: MosaicMask(
          symbol: maskSymbol,
          position: .centered(),
        ),
        symbols: [mosaicSymbol],
        placement: .organic(
          TesseraPlacement.Organic(
            seed: 21,
            minimumSpacing: 4,
            density: 0.65,
            baseScaleRange: 0.9...1.1,
            maximumSymbolCount: 120,
          ),
        ),
        rendering: .contained,
      ),
    ],
  )

  let snapshot = try await TesseraRenderer(pattern).makeSnapshot(
    mode: .canvas(size: CGSize(width: 220, height: 220), edgeBehavior: .finite),
    seed: .fixed(55),
  )

  #expect(snapshot.renderModel.basePlacements.isEmpty == false)
  #expect(snapshot.renderModel.mosaics.count == 1)
  let mosaicLayer = try #require(snapshot.renderModel.mosaics.first)
  #expect(mosaicLayer.placements.isEmpty == false)

  let baseLookup = Dictionary(uniqueKeysWithValues: snapshot.renderModel.baseSymbols.map { ($0.id, $0) })
  for placement in snapshot.renderModel.basePlacements {
    let symbol = try #require(baseLookup[placement.renderSymbolId])
    for point in sampledCollisionPoints(for: symbol, placement: placement) {
      #expect(mosaicLayer.mask.contains(point) == false)
    }
  }

  let mosaicLookup = Dictionary(uniqueKeysWithValues: mosaicLayer.symbols.map { ($0.id, $0) })
  for placement in mosaicLayer.placements {
    let symbol = try #require(mosaicLookup[placement.renderSymbolId])
    for point in sampledCollisionPoints(for: symbol, placement: placement) {
      #expect(mosaicLayer.mask.contains(point))
    }
  }
}

@Test @MainActor func baseLayerStillExcludesVisibleMosaicWhenEarlierMosaicIsOffCanvas() async throws {
  let baseSymbol = Symbol(collider: .shape(.rectangle(center: .zero, size: CGSize(width: 18, height: 18)))) {
    RoundedRectangle(cornerRadius: 4, style: .continuous)
      .fill(Color.blue)
      .frame(width: 18, height: 18)
  }
  let mosaicSymbol = Symbol(collider: .shape(.circle(center: .zero, radius: 5))) {
    Circle()
      .fill(Color.red)
      .frame(width: 10, height: 10)
  }
  let offCanvasMaskSymbol = Symbol(collider: .shape(.rectangle(center: .zero, size: CGSize(width: 48, height: 48)))) {
    Rectangle()
      .fill(Color.white)
      .frame(width: 48, height: 48)
  }
  let visibleMaskSymbol = Symbol(collider: .shape(.rectangle(center: .zero, size: CGSize(width: 96, height: 96)))) {
    Rectangle()
      .fill(Color.white)
      .frame(width: 96, height: 96)
  }

  let pattern = Pattern(
    symbols: [baseSymbol],
    placement: .grid(columns: 10, rows: 10),
    mosaics: [
      Mosaic(
        mask: MosaicMask(
          symbol: offCanvasMaskSymbol,
          position: .absolute(CGPoint(x: -200, y: -200)),
        ),
        symbols: [mosaicSymbol],
        placement: .grid(columns: 1, rows: 1),
        rendering: .clipped,
      ),
      Mosaic(
        mask: MosaicMask(
          symbol: visibleMaskSymbol,
          position: .centered(),
        ),
        symbols: [mosaicSymbol],
        placement: .grid(columns: 1, rows: 1),
        rendering: .clipped,
      ),
    ],
  )

  let snapshot = try await TesseraRenderer(pattern).makeSnapshot(
    mode: .canvas(size: CGSize(width: 240, height: 240), edgeBehavior: .finite),
    seed: .fixed(71),
  )

  #expect(snapshot.renderModel.basePlacements.isEmpty == false)
  #expect(snapshot.renderModel.mosaics.count == 2)

  let visibleLayer = try #require(snapshot.renderModel.mosaics.last)
  #expect(visibleLayer.mask.filledBounds() != nil)

  let baseLookup = Dictionary(uniqueKeysWithValues: snapshot.renderModel.baseSymbols.map { ($0.id, $0) })
  for placement in snapshot.renderModel.basePlacements {
    let symbol = try #require(baseLookup[placement.renderSymbolId])
    for point in sampledCollisionPoints(for: symbol, placement: placement) {
      #expect(visibleLayer.mask.contains(point) == false)
    }
  }
}

@Test @MainActor func mosaicRenderingModesExposeContainedAndBoundaryCrossingPlacement() async throws {
  let mosaicSymbol = Symbol(collider: .shape(.rectangle(center: .zero, size: CGSize(width: 84, height: 84)))) {
    Rectangle()
      .fill(Color.red)
      .frame(width: 84, height: 84)
  }
  let maskSymbol = Symbol(collider: .automatic(size: CGSize(width: 44, height: 44))) {
    Circle()
      .fill(Color.white)
      .frame(width: 44, height: 44)
  }

  let containedPattern = Pattern(
    symbols: [],
    placement: .grid(columns: 1, rows: 1),
    mosaics: [
      Mosaic(
        mask: MosaicMask(symbol: maskSymbol, position: .centered()),
        symbols: [mosaicSymbol],
        placement: .grid(columns: 1, rows: 1),
        rendering: .contained,
      ),
    ],
  )
  let clippedPattern = Pattern(
    symbols: [],
    placement: .grid(columns: 1, rows: 1),
    mosaics: [
      Mosaic(
        mask: MosaicMask(symbol: maskSymbol, position: .centered()),
        symbols: [mosaicSymbol],
        placement: .grid(columns: 1, rows: 1),
        rendering: .clipped,
      ),
    ],
  )
  let unclippedPattern = Pattern(
    symbols: [],
    placement: .grid(columns: 1, rows: 1),
    mosaics: [
      Mosaic(
        mask: MosaicMask(symbol: maskSymbol, position: .centered()),
        symbols: [mosaicSymbol],
        placement: .grid(columns: 1, rows: 1),
        rendering: .unclipped,
      ),
    ],
  )

  let containedSnapshot = try await TesseraRenderer(containedPattern).makeSnapshot(
    mode: .canvas(size: CGSize(width: 120, height: 120), edgeBehavior: .finite),
  )
  let clippedSnapshot = try await TesseraRenderer(clippedPattern).makeSnapshot(
    mode: .canvas(size: CGSize(width: 120, height: 120), edgeBehavior: .finite),
  )
  let unclippedSnapshot = try await TesseraRenderer(unclippedPattern).makeSnapshot(
    mode: .canvas(size: CGSize(width: 120, height: 120), edgeBehavior: .finite),
  )

  let containedLayer = try #require(containedSnapshot.renderModel.mosaics.first)
  let clippedLayer = try #require(clippedSnapshot.renderModel.mosaics.first)
  let unclippedLayer = try #require(unclippedSnapshot.renderModel.mosaics.first)

  #expect(containedLayer.placements.isEmpty)
  #expect(clippedLayer.placements.count == 1)
  #expect(unclippedLayer.placements.count == 1)

  let clippedPlacement = try #require(clippedLayer.placements.first)
  #expect(clippedLayer.mask.contains(clippedPlacement.position))
  #expect(sampledCollisionPoints(for: mosaicSymbol, placement: clippedPlacement).contains { point in
    clippedLayer.mask.contains(point) == false
  })

  let unclippedPlacement = try #require(unclippedLayer.placements.first)
  #expect(unclippedLayer.mask.contains(unclippedPlacement.position))
  #expect(sampledCollisionPoints(for: mosaicSymbol, placement: unclippedPlacement).contains { point in
    unclippedLayer.mask.contains(point) == false
  })
}

@Test @MainActor func defaultMosaicRenderingMatchesClippedGridPlacementBehavior() async throws {
  let mosaicSymbol = Symbol(collider: .shape(.rectangle(center: .zero, size: CGSize(width: 56, height: 56)))) {
    Rectangle()
      .fill(Color.red)
      .frame(width: 56, height: 56)
  }
  let maskSymbol = Symbol(collider: .automatic(size: CGSize(width: 180, height: 180))) {
    Circle()
      .fill(Color.white)
      .frame(width: 180, height: 180)
  }

  let defaultPattern = Pattern(
    symbols: [],
    placement: .grid(columns: 1, rows: 1),
    mosaics: [
      Mosaic(
        mask: MosaicMask(symbol: maskSymbol, position: .centered()),
        symbols: [mosaicSymbol],
        placement: .grid(columns: 10, rows: 10),
      ),
    ],
  )
  let clippedPattern = Pattern(
    symbols: [],
    placement: .grid(columns: 1, rows: 1),
    mosaics: [
      Mosaic(
        mask: MosaicMask(symbol: maskSymbol, position: .centered()),
        symbols: [mosaicSymbol],
        placement: .grid(columns: 10, rows: 10),
        rendering: .clipped,
      ),
    ],
  )
  let containedPattern = Pattern(
    symbols: [],
    placement: .grid(columns: 1, rows: 1),
    mosaics: [
      Mosaic(
        mask: MosaicMask(symbol: maskSymbol, position: .centered()),
        symbols: [mosaicSymbol],
        placement: .grid(columns: 10, rows: 10),
        rendering: .contained,
      ),
    ],
  )

  let defaultSnapshot = try await TesseraRenderer(defaultPattern).makeSnapshot(
    mode: .canvas(size: CGSize(width: 220, height: 220), edgeBehavior: .finite),
    seed: .fixed(7),
  )
  let clippedSnapshot = try await TesseraRenderer(clippedPattern).makeSnapshot(
    mode: .canvas(size: CGSize(width: 220, height: 220), edgeBehavior: .finite),
    seed: .fixed(7),
  )
  let containedSnapshot = try await TesseraRenderer(containedPattern).makeSnapshot(
    mode: .canvas(size: CGSize(width: 220, height: 220), edgeBehavior: .finite),
    seed: .fixed(7),
  )

  let defaultLayer = try #require(defaultSnapshot.renderModel.mosaics.first)
  let clippedLayer = try #require(clippedSnapshot.renderModel.mosaics.first)
  let containedLayer = try #require(containedSnapshot.renderModel.mosaics.first)

  #expect(defaultLayer.placements.count == clippedLayer.placements.count)
  #expect(defaultLayer.placements.count > containedLayer.placements.count)
}

@Test @MainActor func mosaicRenderingModesProduceDistinctSnapshotFingerprints() async throws {
  let mosaicSymbol = Symbol(collider: .shape(.rectangle(center: .zero, size: CGSize(width: 40, height: 40)))) {
    Rectangle()
      .fill(Color.red)
      .frame(width: 40, height: 40)
  }
  let maskSymbol = Symbol(collider: .automatic(size: CGSize(width: 90, height: 90))) {
    Circle()
      .fill(Color.white)
      .frame(width: 90, height: 90)
  }

  let containedPattern = Pattern(
    symbols: [],
    placement: .grid(columns: 1, rows: 1),
    mosaics: [
      Mosaic(
        mask: MosaicMask(symbol: maskSymbol, position: .centered()),
        symbols: [mosaicSymbol],
        placement: .grid(columns: 4, rows: 4),
        rendering: .contained,
      ),
    ],
  )
  let clippedPattern = Pattern(
    symbols: [],
    placement: .grid(columns: 1, rows: 1),
    mosaics: [
      Mosaic(
        mask: MosaicMask(symbol: maskSymbol, position: .centered()),
        symbols: [mosaicSymbol],
        placement: .grid(columns: 4, rows: 4),
        rendering: .clipped,
      ),
    ],
  )
  let unclippedPattern = Pattern(
    symbols: [],
    placement: .grid(columns: 1, rows: 1),
    mosaics: [
      Mosaic(
        mask: MosaicMask(symbol: maskSymbol, position: .centered()),
        symbols: [mosaicSymbol],
        placement: .grid(columns: 4, rows: 4),
        rendering: .unclipped,
      ),
    ],
  )

  let containedSnapshot = try await TesseraRenderer(containedPattern).makeSnapshot(
    mode: .canvas(size: CGSize(width: 160, height: 160), edgeBehavior: .finite),
    seed: .fixed(91),
  )
  let clippedSnapshot = try await TesseraRenderer(clippedPattern).makeSnapshot(
    mode: .canvas(size: CGSize(width: 160, height: 160), edgeBehavior: .finite),
    seed: .fixed(91),
  )
  let unclippedSnapshot = try await TesseraRenderer(unclippedPattern).makeSnapshot(
    mode: .canvas(size: CGSize(width: 160, height: 160), edgeBehavior: .finite),
    seed: .fixed(91),
  )

  #expect(containedSnapshot.fingerprint != clippedSnapshot.fingerprint)
  #expect(containedSnapshot.fingerprint != unclippedSnapshot.fingerprint)
  #expect(clippedSnapshot.fingerprint != unclippedSnapshot.fingerprint)
}

@Test @MainActor func mosaicGridResolvesCellCountInsideMaskBounds() async throws {
  let mosaicSymbol = Symbol(collider: .shape(.circle(center: .zero, radius: 2))) {
    Circle()
      .fill(Color.red)
      .frame(width: 4, height: 4)
  }
  let maskSymbol = Symbol(collider: .shape(.rectangle(center: .zero, size: CGSize(width: 80, height: 80)))) {
    Rectangle()
      .fill(Color.white)
      .frame(width: 80, height: 80)
  }

  let pattern = Pattern(
    symbols: [],
    placement: .grid(columns: 1, rows: 1),
    mosaics: [
      Mosaic(
        mask: MosaicMask(
          symbol: maskSymbol,
          position: .centered(),
        ),
        symbols: [mosaicSymbol],
        placement: .grid(columns: 10, rows: 10),
        rendering: .clipped,
      ),
    ],
  )

  let snapshot = try await TesseraRenderer(pattern).makeSnapshot(
    mode: .canvas(size: CGSize(width: 200, height: 200), edgeBehavior: .finite),
  )

  let layer = try #require(snapshot.renderModel.mosaics.first)
  #expect(layer.placements.count == 100)
}

@Test func bilinearMaskFilledBoundsIncludesInterpolatedEdgeArea() throws {
  let mask = TesseraAlphaMask(
    size: CGSize(width: 100, height: 100),
    pixelsWide: 2,
    pixelsHigh: 2,
    alphaBytes: [
      255, 0,
      0, 0,
    ],
    thresholdByte: 40,
    sampling: .bilinear,
    invert: false,
  )
  let interpolatedPoint = CGPoint(x: 75, y: 25)
  #expect(mask.contains(interpolatedPoint))

  let bounds = try #require(mask.filledBounds())
  #expect(bounds.contains(interpolatedPoint))
}

@Test @MainActor func emptyMosaicMaskShortCircuitsGridPlacements() async throws {
  let mosaicSymbol = Symbol(collider: .shape(.circle(center: .zero, radius: 2))) {
    Circle()
      .fill(Color.red)
      .frame(width: 4, height: 4)
  }
  let emptyMaskSymbol = Symbol(collider: .shape(.circle(center: .zero, radius: 0))) {
    Rectangle()
      .fill(Color.clear)
      .frame(width: 120, height: 120)
  }

  let pattern = Pattern(
    symbols: [],
    placement: .grid(columns: 1, rows: 1),
    mosaics: [
      Mosaic(
        mask: MosaicMask(symbol: emptyMaskSymbol, position: .centered()),
        symbols: [mosaicSymbol],
        placement: .grid(columns: 10, rows: 10),
        rendering: .clipped,
      ),
    ],
  )

  let snapshot = try await TesseraRenderer(pattern).makeSnapshot(
    mode: .canvas(size: CGSize(width: 240, height: 240), edgeBehavior: .finite),
    seed: .fixed(2),
  )

  let layer = try #require(snapshot.renderModel.mosaics.first)
  #expect(layer.mask.filledFraction == 0)
  #expect(layer.placements.isEmpty)
}

@Test @MainActor func mosaicMaskUsesCollisionShapeInsteadOfViewAlpha() async throws {
  let mosaicSymbol = Symbol(collider: .shape(.circle(center: .zero, radius: 4))) {
    Circle()
      .fill(Color.red)
      .frame(width: 8, height: 8)
  }
  let transparentMaskSymbol = Symbol(collider: .shape(.rectangle(center: .zero, size: CGSize(width: 72, height: 72)))) {
    Rectangle()
      .fill(Color.clear)
      .frame(width: 72, height: 72)
  }

  let pattern = Pattern(
    symbols: [],
    placement: .grid(columns: 1, rows: 1),
    mosaics: [
      Mosaic(
        mask: MosaicMask(symbol: transparentMaskSymbol, position: .centered()),
        symbols: [mosaicSymbol],
        placement: .grid(columns: 2, rows: 2),
        rendering: .clipped,
      ),
    ],
  )

  let snapshot = try await TesseraRenderer(pattern).makeSnapshot(
    mode: .canvas(size: CGSize(width: 160, height: 160), edgeBehavior: .finite),
    seed: .fixed(11),
  )

  let layer = try #require(snapshot.renderModel.mosaics.first)
  #expect(layer.mask.filledFraction > 0.1)
  #expect(layer.placements.count == 4)
}

@Test @MainActor func clippedMosaicsRenderInOverlappingMaskArea() async throws {
  let redFillSymbol = Symbol(
    rotation: .degrees(0)...(.degrees(0)),
    scale: 1...1,
    collider: .shape(.rectangle(center: .zero, size: CGSize(width: 100, height: 120))),
  ) {
    Rectangle()
      .fill(Color.red)
      .frame(width: 100, height: 120)
  }
  let greenFillSymbol = Symbol(
    rotation: .degrees(0)...(.degrees(0)),
    scale: 1...1,
    collider: .shape(.rectangle(center: .zero, size: CGSize(width: 80, height: 120))),
  ) {
    Rectangle()
      .fill(Color.green)
      .frame(width: 80, height: 120)
  }
  let rectangularMaskSymbol = Symbol(collider: .shape(.rectangle(
    center: .zero,
    size: CGSize(width: 80, height: 120),
  ))) {
    Rectangle()
      .fill(Color.white)
      .frame(width: 80, height: 120)
  }

  let pattern = Pattern(
    symbols: [],
    placement: .grid(columns: 1, rows: 1),
    mosaics: [
      Mosaic(
        id: UUID(uuidString: "00000000-0000-0000-0000-0000000000D1")!,
        mask: MosaicMask(
          symbol: rectangularMaskSymbol,
          position: .absolute(CGPoint(x: 40, y: 60)),
        ),
        symbols: [redFillSymbol],
        placement: .grid(columns: 1, rows: 1),
        rendering: .clipped,
        offset: CGSize(width: -30, height: 0),
      ),
      Mosaic(
        id: UUID(uuidString: "00000000-0000-0000-0000-0000000000D2")!,
        mask: MosaicMask(
          symbol: rectangularMaskSymbol,
          position: .absolute(CGPoint(x: 80, y: 60)),
        ),
        symbols: [greenFillSymbol],
        placement: .grid(columns: 1, rows: 1),
        rendering: .clipped,
        offset: CGSize(width: 30, height: 0),
      ),
    ],
  )
  let renderer = TesseraRenderer(pattern)
  let snapshot = try await renderer.makeSnapshot(
    mode: .canvas(size: CGSize(width: 120, height: 120), edgeBehavior: .finite),
    seed: .fixed(42),
  )
  let temporaryDirectory = FileManager.default.temporaryDirectory
  let fileName = UUID().uuidString
  let exportedURL = try renderer.export(
    .png,
    snapshot: snapshot,
    options: .init(directory: temporaryDirectory, fileName: fileName),
  )
  defer { try? FileManager.default.removeItem(at: exportedURL) }

  #expect(snapshot.renderModel.mosaics.count == 2)
  let firstLayer = try #require(snapshot.renderModel.mosaics.first)
  let secondLayer = try #require(snapshot.renderModel.mosaics.last)
  let overlapPoint = CGPoint(x: 70, y: 60)
  #expect(firstLayer.mask.contains(overlapPoint))
  #expect(secondLayer.mask.contains(overlapPoint))
  #expect(secondLayer.placements.isEmpty == false)

  let exportedImage = try cgImageFromPNGFile(at: exportedURL)
  let overlapPixel = try pixelComponents(in: exportedImage, x: 70, y: 60)

  #expect(overlapPixel.alpha > 200)
}

@Test func newerSnapshotRequestCancelsPreviousComputationEvents() async throws {
  let renderer = makeCancellationStressRenderer()
  let mode = Mode.canvas(size: CGSize(width: 1200, height: 1200), edgeBehavior: .finite)

  async let firstEventKindsTask = collectEventKinds(
    from: renderer.makeSnapshotEvents(mode: mode, seed: Seed.fixed(1001)),
  )
  try await Task.sleep(nanoseconds: 20_000_000)
  let secondEventKinds = try await collectEventKinds(
    from: renderer.makeSnapshotEvents(mode: mode, seed: Seed.fixed(1002)),
  )
  let firstEventKinds = try await firstEventKindsTask

  #expect(firstEventKinds.contains(EventKind.started))
  #expect(firstEventKinds.contains(EventKind.completed) == false)
  #expect(secondEventKinds.contains(EventKind.completed))
}

@Test func circleMaskNormalizesNegativeRadius() throws {
  let circleMaskSymbol = Symbol(collider: .shape(.circle(center: .zero, radius: -24))) {
    Circle()
      .fill(Color.white)
      .frame(width: 48, height: 48)
  }
  let mask = MosaicMask(
    symbol: circleMaskSymbol,
    position: .absolute(CGPoint(x: 72, y: 84)),
  )
  let shapeMask = MosaicShapeMask(
    mosaicMask: mask,
    canvasSize: CGSize(width: 200, height: 200),
  )
  let bounds = try #require(shapeMask.bounds)
  let epsilon: CGFloat = 0.001

  #expect(abs(bounds.width - 48) <= epsilon)
  #expect(abs(bounds.height - 48) <= epsilon)
  #expect(shapeMask.contains(CGPoint(x: 72, y: 84)))
  #expect(shapeMask.contains(CGPoint(x: 95.9, y: 84)))
  #expect(shapeMask.contains(CGPoint(x: 96.2, y: 84)) == false)
}

@Test func mosaicDebugMaskPathUsesExactCircleCurve() throws {
  let circleMaskSymbol = Symbol(collider: .shape(.circle(center: .zero, radius: 24))) {
    Circle()
      .fill(Color.white)
      .frame(width: 48, height: 48)
  }
  let mask = MosaicMask(
    symbol: circleMaskSymbol,
    position: .absolute(CGPoint(x: 72, y: 84)),
    scale: 1.5,
  )
  let shapeMask = MosaicShapeMask(
    mosaicMask: mask,
    canvasSize: CGSize(width: 200, height: 200),
  )
  let debugPath = try #require(shapeMask.debugCGPath())

  let elementTypes = cgPathElementTypes(debugPath)
  #expect(elementTypes.contains(.addCurveToPoint))
  #expect(debugPath.contains(CGPoint(x: 72, y: 84)))

  let expectedBounds = try #require(shapeMask.bounds)
  let actualBounds = debugPath.boundingBoxOfPath
  expectRectApproximatelyEqual(actualBounds, expectedBounds)
}

@Test func mosaicDebugMaskPathUsesExactTransformedRectangle() throws {
  let rectangleMaskSymbol = Symbol(collider: .shape(.rectangle(center: .zero, size: CGSize(width: 80, height: 40)))) {
    Rectangle()
      .fill(Color.white)
      .frame(width: 80, height: 40)
  }
  let mask = MosaicMask(
    symbol: rectangleMaskSymbol,
    position: .absolute(CGPoint(x: 110, y: 90)),
    rotation: .degrees(31),
    scale: 1.2,
  )
  let shapeMask = MosaicShapeMask(
    mosaicMask: mask,
    canvasSize: CGSize(width: 260, height: 220),
  )
  let debugPath = try #require(shapeMask.debugCGPath())

  let elementTypes = cgPathElementTypes(debugPath)
  #expect(elementTypes.contains(.addCurveToPoint) == false)
  #expect(elementTypes.contains(.addLineToPoint))

  let expectedBounds = try #require(shapeMask.bounds)
  let actualBounds = debugPath.boundingBoxOfPath
  expectRectApproximatelyEqual(actualBounds, expectedBounds)
}

private func sampledCollisionPoints(
  for symbol: Symbol,
  placement: SnapshotPlacementDescriptor,
) -> [CGPoint] {
  let polygons = CollisionMath.polygons(for: symbol.collisionShape)
  let collisionTransform = CollisionTransform(
    position: placement.position,
    rotation: CGFloat(placement.rotationRadians),
    scale: placement.scale,
  )
  return ShapePlacementMaskConstraint.sampledPoints(
    collisionTransform: collisionTransform,
    polygons: polygons,
  )
}

private func makeCancellationStressRenderer() -> TesseraRenderer {
  let mosaicFillSymbol = Symbol(collider: .shape(.circle(center: .zero, radius: 5))) {
    Circle()
      .fill(Color.red)
      .frame(width: 10, height: 10)
  }
  let maskSymbol = Symbol(
    collider: .shape(
      .roundedRectangle(
        size: CGSize(width: 960, height: 960),
        cornerRadius: 180,
      ),
    ),
  ) {
    RoundedRectangle(cornerRadius: 180, style: .continuous)
      .fill(Color.white)
      .frame(width: 960, height: 960)
  }

  let pattern = Pattern(
    symbols: [],
    placement: .grid(columns: 1, rows: 1),
    mosaics: [
      Mosaic(
        mask: MosaicMask(symbol: maskSymbol, position: .centered()),
        symbols: [mosaicFillSymbol],
        placement: .grid(columns: 72, rows: 72),
        rendering: .clipped,
      ),
    ],
  )
  return TesseraRenderer(pattern)
}

private enum EventKind: Equatable {
  case started
  case preparingMasks
  case placingMosaics
  case placingBaseSymbols
  case completed
}

private func collectEventKinds(
  from stream: AsyncThrowingStream<TesseraComputationEvent, Error>,
) async throws -> [EventKind] {
  var eventKinds: [EventKind] = []
  for try await event in stream {
    switch event {
    case .started:
      eventKinds.append(.started)
    case .preparingMasks:
      eventKinds.append(.preparingMasks)
    case .placingMosaics:
      eventKinds.append(.placingMosaics)
    case .placingBaseSymbols:
      eventKinds.append(.placingBaseSymbols)
    case .completed:
      eventKinds.append(.completed)
    }
  }
  return eventKinds
}

private func cgPathElementTypes(_ path: CGPath) -> [CGPathElementType] {
  var elementTypes: [CGPathElementType] = []
  path.applyWithBlock { pointer in
    elementTypes.append(pointer.pointee.type)
  }
  return elementTypes
}

private func expectRectApproximatelyEqual(
  _ lhs: CGRect,
  _ rhs: CGRect,
  tolerance: CGFloat = 0.001,
) {
  #expect(abs(lhs.minX - rhs.minX) <= tolerance)
  #expect(abs(lhs.minY - rhs.minY) <= tolerance)
  #expect(abs(lhs.width - rhs.width) <= tolerance)
  #expect(abs(lhs.height - rhs.height) <= tolerance)
}

private func makeOpaqueTestAlphaMask() -> TesseraAlphaMask {
  TesseraAlphaMask(
    size: CGSize(width: 2, height: 2),
    pixelsWide: 2,
    pixelsHigh: 2,
    alphaBytes: [255, 255, 255, 255],
    thresholdByte: 128,
    sampling: .nearest,
    invert: false,
  )
}

private func makeOpaqueTestSliceMask() -> SliceAlphaMask {
  SliceAlphaMask(
    rasterSize: CGSize(width: 10, height: 10),
    rasterPixelsWide: 10,
    rasterPixelsHigh: 10,
    sliceOriginX: 2,
    sliceOriginY: 2,
    slicePixelsWide: 3,
    slicePixelsHigh: 3,
    alphaBytes: [UInt8](repeating: 255, count: 9),
    thresholdByte: 128,
    sampling: .nearest,
    invert: false,
  )
}
