// By Dennis Müller

import CoreGraphics
import Foundation
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif
@testable import Tessera
import Testing

@Test @MainActor func `tile PNG export contains visible pixels`() async throws {
  let tile = makeTestTile()
  let temporaryDirectory = FileManager.default.temporaryDirectory
  let fileName = UUID().uuidString

  let exportedURL = try await tile.export(
    .png,
    options: .init(
      directory: temporaryDirectory,
      fileName: fileName,
    ),
  )
  defer { try? FileManager.default.removeItem(at: exportedURL) }

  let cgImage = try cgImageFromPNGFile(at: exportedURL)
  #expect(imageContainsVisiblePixels(cgImage))
}

@Test @MainActor func `tile PDF export contains visible pixels`() async throws {
  let tile = makeTestTile()
  let temporaryDirectory = FileManager.default.temporaryDirectory
  let fileName = UUID().uuidString

  let exportedURL = try await tile.export(
    .pdf,
    options: .init(
      directory: temporaryDirectory,
      fileName: fileName,
    ),
  )
  defer { try? FileManager.default.removeItem(at: exportedURL) }

  let cgImage = try cgImageFromPDFFile(at: exportedURL)
  #expect(imageContainsVisiblePixels(cgImage))
}

@Test @MainActor func `canvas PNG export uses transparent background by default`() async throws {
  let canvasSize = CGSize(width: 128, height: 128)
  let tessera = makeTestCanvasWithCenteredFixedCircle(canvasSize: canvasSize)
  let temporaryDirectory = FileManager.default.temporaryDirectory
  let fileName = UUID().uuidString

  let exportedURL = try await tessera.export(
    .png,
    options: .init(directory: temporaryDirectory, fileName: fileName),
    canvasSize: canvasSize,
  )
  defer { try? FileManager.default.removeItem(at: exportedURL) }

  let cgImage = try cgImageFromPNGFile(at: exportedURL)
  let cornerPixel = try pixelComponents(in: cgImage, x: 0, y: 0)
  #expect(cornerPixel.alpha == 0)
}

@Test @MainActor func `canvas PNG export renders background color when provided`() async throws {
  let canvasSize = CGSize(width: 128, height: 128)
  let tessera = makeTestCanvasWithCenteredFixedCircle(canvasSize: canvasSize)
  let temporaryDirectory = FileManager.default.temporaryDirectory
  let fileName = UUID().uuidString

  let greenBackgroundURL = try await tessera.export(
    .png,
    options: .init(
      directory: temporaryDirectory,
      fileName: "\(fileName)-green",
      backgroundColor: .green,
    ),
    canvasSize: canvasSize,
  )
  defer { try? FileManager.default.removeItem(at: greenBackgroundURL) }

  let blueBackgroundURL = try await tessera.export(
    .png,
    options: .init(
      directory: temporaryDirectory,
      fileName: "\(fileName)-blue",
      backgroundColor: .blue,
    ),
    canvasSize: canvasSize,
  )
  defer { try? FileManager.default.removeItem(at: blueBackgroundURL) }

  let greenImage = try cgImageFromPNGFile(at: greenBackgroundURL)
  let greenCornerPixel = try pixelComponents(in: greenImage, x: 0, y: 0)
  #expect(greenCornerPixel.alpha > 200)

  let blueImage = try cgImageFromPNGFile(at: blueBackgroundURL)
  let blueCornerPixel = try pixelComponents(in: blueImage, x: 0, y: 0)
  #expect(blueCornerPixel.alpha > 200)

  let greenExcess = Int(greenCornerPixel.green) - Int(greenCornerPixel.blue)
  let blueExcess = Int(blueCornerPixel.green) - Int(blueCornerPixel.blue)
  #expect(greenExcess > 20)
  #expect(blueExcess < -20)
}

@Test @MainActor func `canvas PNG export renders pinned symbols above generated symbols`() async throws {
  let canvasSize = CGSize(width: 128, height: 128)
  let generatedSymbol = makeColoredGeneratedSymbol(
    color: .blue,
    size: CGSize(width: 120, height: 120),
    zIndex: 0,
    collisionCenter: CGPoint(x: -50, y: 0),
    collisionSize: CGSize(width: 8, height: 8),
  )
  let pinnedSymbol = makeColoredPinnedSymbol(
    color: .red,
    size: CGSize(width: 60, height: 60),
    zIndex: 0,
    collisionCenter: CGPoint(x: 50, y: 0),
    collisionSize: CGSize(width: 8, height: 8),
  )
  let tessera = makeCanvasTessera(
    symbols: [generatedSymbol],
    pinnedSymbols: [pinnedSymbol],
  )

  let cgImage = try await exportedCGImage(
    from: tessera,
    format: .png,
    canvasSize: canvasSize,
  )
  let centerPixel = try pixelComponents(in: cgImage, x: cgImage.width / 2, y: cgImage.height / 2)

  #expect(centerPixel.alpha > 200)
  #expect(centerPixel.red > 200)
  #expect(Int(centerPixel.red) - Int(centerPixel.green) > 100)
  #expect(Int(centerPixel.red) - Int(centerPixel.blue) > 100)
}

@Test @MainActor func `canvas PNG export honors Z index across generated and pinned symbols`() async throws {
  let canvasSize = CGSize(width: 128, height: 128)
  let generatedSymbol = makeColoredGeneratedSymbol(
    color: .blue,
    size: CGSize(width: 120, height: 120),
    zIndex: 5,
    collisionCenter: CGPoint(x: -50, y: 0),
    collisionSize: CGSize(width: 8, height: 8),
  )
  let pinnedSymbol = makeColoredPinnedSymbol(
    color: .red,
    size: CGSize(width: 80, height: 80),
    zIndex: 3,
    collisionCenter: CGPoint(x: 50, y: 0),
    collisionSize: CGSize(width: 8, height: 8),
  )
  let tessera = makeCanvasTessera(
    symbols: [generatedSymbol],
    pinnedSymbols: [pinnedSymbol],
  )

  let cgImage = try await exportedCGImage(
    from: tessera,
    format: .png,
    canvasSize: canvasSize,
  )
  let centerPixel = try pixelComponents(in: cgImage, x: cgImage.width / 2, y: cgImage.height / 2)

  #expect(centerPixel.alpha > 200)
  #expect(centerPixel.blue > 200)
  #expect(Int(centerPixel.blue) - Int(centerPixel.red) > 100)
}

@Test @MainActor func `canvas PNG export honors Z index across pinned symbols`() async throws {
  let canvasSize = CGSize(width: 128, height: 128)
  let backPinnedSymbol = makeColoredPinnedSymbol(color: .blue, size: CGSize(width: 80, height: 80), zIndex: 0)
  let frontPinnedSymbol = makeColoredPinnedSymbol(color: .red, size: CGSize(width: 60, height: 60), zIndex: 5)
  let tessera = makeCanvasTessera(
    symbols: [],
    pinnedSymbols: [frontPinnedSymbol, backPinnedSymbol],
  )

  let cgImage = try await exportedCGImage(
    from: tessera,
    format: .png,
    canvasSize: canvasSize,
  )
  let centerPixel = try pixelComponents(in: cgImage, x: cgImage.width / 2, y: cgImage.height / 2)

  #expect(centerPixel.alpha > 200)
  #expect(centerPixel.red > 200)
  #expect(Int(centerPixel.red) - Int(centerPixel.blue) > 100)
}

@Test @MainActor func `canvas PNG export clips subgrid content when requested`() async throws {
  let canvasSize = CGSize(width: 160, height: 160)
  let subgridSymbol = Symbol(
    rotation: .degrees(0)...(.degrees(0)),
    scale: 1...1,
    collider: .shape(.rectangle(center: .zero, size: CGSize(width: 120, height: 120))),
  ) {
    Rectangle()
      .fill(Color.red)
      .frame(width: 120, height: 120)
  }
  let tessera = Tessera(
    Pattern(
      symbols: [],
      placement: .grid(
        TesseraPlacement.Grid(
          sizing: .count(columns: 2, rows: 2),
          seed: 1,
          subgrids: [
            .init(
              at: .init(row: 0, column: 0),
              spanning: .init(rows: 1, columns: 1),
              symbols: [subgridSymbol],
              clipsToBounds: true,
              grid: .init(
                sizing: .fixed(cellSize: CGSize(width: 100, height: 100)),
              ),
            ),
          ],
        ),
      ),
    ),
  )
  .mode(.canvas(edgeBehavior: .finite))
  .seed(.fixed(1))

  let cgImage = try await exportedCGImage(
    from: tessera,
    format: .png,
    canvasSize: canvasSize,
  )
  let exportScale = CGFloat(cgImage.width) / canvasSize.width
  let insidePixel = try pixelComponents(
    in: cgImage,
    x: Int((40 * exportScale).rounded(.down)),
    y: Int((40 * exportScale).rounded(.down)),
  )
  let outsidePixel = try pixelComponents(
    in: cgImage,
    x: Int((90 * exportScale).rounded(.down)),
    y: Int((40 * exportScale).rounded(.down)),
  )

  #expect(insidePixel.alpha > 200)
  #expect(insidePixel.red > 200)
  #expect(outsidePixel.alpha == 0)
}

@Test @MainActor func `snapshot PNG export renders collision overlay for generated symbols`() async throws {
  let canvasSize = CGSize(width: 128, height: 128)
  let renderer = makeGeneratedCollisionOverlayRenderer()
  let snapshot = try await renderer.makeSnapshot(
    mode: .canvas(size: canvasSize, edgeBehavior: .finite),
    seed: .fixed(1),
  )
  let temporaryDirectory = FileManager.default.temporaryDirectory
  let fileName = UUID().uuidString

  let baselineURL = try renderer.export(
    .png,
    snapshot: snapshot,
    options: .init(
      directory: temporaryDirectory,
      fileName: "\(fileName)-baseline",
      render: .init(targetPixelSize: canvasSize),
    ),
  )
  defer { try? FileManager.default.removeItem(at: baselineURL) }

  let overlayURL = try renderer.export(
    .png,
    snapshot: snapshot,
    options: .init(
      directory: temporaryDirectory,
      fileName: "\(fileName)-overlay",
      render: .init(
        targetPixelSize: canvasSize,
        showsCollisionOverlay: true,
      ),
    ),
  )
  defer { try? FileManager.default.removeItem(at: overlayURL) }

  let baselineImage = try cgImageFromPNGFile(at: baselineURL)
  let overlayImage = try cgImageFromPNGFile(at: overlayURL)
  let baselinePixel = try pixelComponents(
    in: baselineImage,
    x: collisionOverlaySamplePoint.x,
    y: collisionOverlaySamplePoint.y,
  )
  let overlayPixel = try pixelComponents(
    in: overlayImage,
    x: collisionOverlaySamplePoint.x,
    y: collisionOverlaySamplePoint.y,
  )

  #expect(baselinePixel.alpha == 0)
  #expect(overlayPixel.alpha > 0)
  #expect(overlayPixel.blue > overlayPixel.red)
  #expect(imagesArePixelEqual(baselineImage, overlayImage) == false)
}

@Test @MainActor func `snapshot PNG export renders collision overlay for pinned symbols`() async throws {
  let canvasSize = CGSize(width: 128, height: 128)
  let renderer = TesseraRenderer(
    Pattern(
      symbols: [],
      placement: .grid(columns: 1, rows: 1),
    ),
  )
  let snapshot = try await renderer.makeSnapshot(
    mode: .canvas(size: canvasSize, edgeBehavior: .finite),
    seed: .fixed(1),
    pinnedSymbols: [makeCollisionOverlayPinnedSymbol(at: CGPoint(x: 64, y: 64))],
  )
  let temporaryDirectory = FileManager.default.temporaryDirectory
  let fileName = UUID().uuidString

  let baselineURL = try renderer.export(
    .png,
    snapshot: snapshot,
    options: .init(
      directory: temporaryDirectory,
      fileName: "\(fileName)-baseline",
      render: .init(targetPixelSize: canvasSize),
    ),
  )
  defer { try? FileManager.default.removeItem(at: baselineURL) }

  let overlayURL = try renderer.export(
    .png,
    snapshot: snapshot,
    options: .init(
      directory: temporaryDirectory,
      fileName: "\(fileName)-overlay",
      render: .init(
        targetPixelSize: canvasSize,
        showsCollisionOverlay: true,
      ),
    ),
  )
  defer { try? FileManager.default.removeItem(at: overlayURL) }

  let baselineImage = try cgImageFromPNGFile(at: baselineURL)
  let overlayImage = try cgImageFromPNGFile(at: overlayURL)
  let baselinePixel = try pixelComponents(
    in: baselineImage,
    x: collisionOverlaySamplePoint.x,
    y: collisionOverlaySamplePoint.y,
  )
  let overlayPixel = try pixelComponents(
    in: overlayImage,
    x: collisionOverlaySamplePoint.x,
    y: collisionOverlaySamplePoint.y,
  )

  #expect(baselinePixel.alpha == 0)
  #expect(overlayPixel.alpha > 0)
  #expect(overlayPixel.blue > overlayPixel.red)
}

@Test @MainActor func `tessera PNG export matches renderer snapshot export`() async throws {
  let canvasSize = CGSize(width: 128, height: 128)
  let pinnedSymbol = makeCollisionOverlayPinnedSymbol(at: CGPoint(x: 64, y: 64))
  let pattern = Pattern(
    symbols: [],
    placement: .organic(
      minimumSpacing: 10,
      density: 0,
      maximumCount: 0,
    ),
  )
  let tessera = Tessera(pattern)
    .mode(.canvas(edgeBehavior: .finite))
    .seed(.fixed(1))
    .pinnedSymbols([pinnedSymbol])
  let renderer = TesseraRenderer(pattern)
  let snapshot = try await renderer.makeSnapshot(
    mode: .canvas(size: canvasSize, edgeBehavior: .finite),
    seed: .fixed(1),
    pinnedSymbols: [pinnedSymbol],
  )
  let temporaryDirectory = FileManager.default.temporaryDirectory
  let fileName = UUID().uuidString

  let tesseraURL = try await tessera.export(
    .png,
    options: .init(
      directory: temporaryDirectory,
      fileName: "\(fileName)-tessera",
      render: .init(
        targetPixelSize: canvasSize,
        showsCollisionOverlay: true,
      ),
    ),
    canvasSize: canvasSize,
  )
  defer { try? FileManager.default.removeItem(at: tesseraURL) }

  let snapshotURL = try renderer.export(
    .png,
    snapshot: snapshot,
    options: .init(
      directory: temporaryDirectory,
      fileName: "\(fileName)-snapshot",
      render: .init(
        targetPixelSize: canvasSize,
        showsCollisionOverlay: true,
      ),
    ),
  )
  defer { try? FileManager.default.removeItem(at: snapshotURL) }

  let tesseraImage = try cgImageFromPNGFile(at: tesseraURL)
  let snapshotImage = try cgImageFromPNGFile(at: snapshotURL)
  #expect(imagesArePixelEqual(tesseraImage, snapshotImage))
}

@Test @MainActor func `canvas PDF export renders pinned symbols above generated symbols`() async throws {
  let canvasSize = CGSize(width: 128, height: 128)
  let generatedSymbol = makeColoredGeneratedSymbol(
    color: .blue,
    size: CGSize(width: 120, height: 120),
    zIndex: 0,
    collisionCenter: CGPoint(x: -50, y: 0),
    collisionSize: CGSize(width: 8, height: 8),
  )
  let pinnedSymbol = makeColoredPinnedSymbol(
    color: .red,
    size: CGSize(width: 60, height: 60),
    zIndex: 0,
    collisionCenter: CGPoint(x: 50, y: 0),
    collisionSize: CGSize(width: 8, height: 8),
  )
  let tessera = makeCanvasTessera(
    symbols: [generatedSymbol],
    pinnedSymbols: [pinnedSymbol],
  )

  let cgImage = try await exportedCGImage(
    from: tessera,
    format: .pdf,
    canvasSize: canvasSize,
  )
  let centerPixel = try pixelComponents(in: cgImage, x: cgImage.width / 2, y: cgImage.height / 2)

  #expect(centerPixel.alpha > 200)
  #expect(centerPixel.red > 200)
  #expect(Int(centerPixel.red) - Int(centerPixel.green) > 100)
  #expect(Int(centerPixel.red) - Int(centerPixel.blue) > 100)
}

@Test @MainActor func `canvas PDF export honors Z index across generated and pinned symbols`() async throws {
  let canvasSize = CGSize(width: 128, height: 128)
  let generatedSymbol = makeColoredGeneratedSymbol(
    color: .blue,
    size: CGSize(width: 120, height: 120),
    zIndex: 5,
    collisionCenter: CGPoint(x: -50, y: 0),
    collisionSize: CGSize(width: 8, height: 8),
  )
  let pinnedSymbol = makeColoredPinnedSymbol(
    color: .red,
    size: CGSize(width: 80, height: 80),
    zIndex: 3,
    collisionCenter: CGPoint(x: 50, y: 0),
    collisionSize: CGSize(width: 8, height: 8),
  )
  let tessera = makeCanvasTessera(
    symbols: [generatedSymbol],
    pinnedSymbols: [pinnedSymbol],
  )

  let cgImage = try await exportedCGImage(
    from: tessera,
    format: .pdf,
    canvasSize: canvasSize,
  )
  let centerPixel = try pixelComponents(in: cgImage, x: cgImage.width / 2, y: cgImage.height / 2)

  #expect(centerPixel.alpha > 200)
  #expect(centerPixel.blue > 200)
  #expect(Int(centerPixel.blue) - Int(centerPixel.red) > 100)
}

@Test @MainActor func `canvas PDF export uses transparent background by default`() async throws {
  let canvasSize = CGSize(width: 128, height: 128)
  let pageSize = CGSize(width: 256, height: 256)
  let tessera = makeTestCanvasWithCenteredFixedCircle(canvasSize: canvasSize)

  let cgImage = try await exportedCGImage(
    from: tessera,
    format: .pdf,
    canvasSize: canvasSize,
    backgroundColor: nil,
    pageSize: pageSize,
  )
  let cornerPixel = try pixelComponents(in: cgImage, x: 0, y: 0)
  #expect(cornerPixel.alpha == 0)
}

@Test @MainActor func `canvas PDF export renders background color when provided`() async throws {
  let canvasSize = CGSize(width: 128, height: 128)
  let pageSize = CGSize(width: 256, height: 256)
  let tessera = makeTestCanvasWithCenteredFixedCircle(canvasSize: canvasSize)
  let temporaryDirectory = FileManager.default.temporaryDirectory
  let fileName = UUID().uuidString

  let greenBackgroundURL = try await tessera.export(
    .pdf,
    options: .init(
      directory: temporaryDirectory,
      fileName: "\(fileName)-green",
      backgroundColor: .green,
      pageSize: pageSize,
    ),
    canvasSize: canvasSize,
  )
  defer { try? FileManager.default.removeItem(at: greenBackgroundURL) }

  let blueBackgroundURL = try await tessera.export(
    .pdf,
    options: .init(
      directory: temporaryDirectory,
      fileName: "\(fileName)-blue",
      backgroundColor: .blue,
      pageSize: pageSize,
    ),
    canvasSize: canvasSize,
  )
  defer { try? FileManager.default.removeItem(at: blueBackgroundURL) }

  let greenImage = try cgImageFromPDFFile(at: greenBackgroundURL)
  let greenCornerPixel = try pixelComponents(in: greenImage, x: 0, y: 0)
  #expect(greenCornerPixel.alpha > 200)

  let blueImage = try cgImageFromPDFFile(at: blueBackgroundURL)
  let blueCornerPixel = try pixelComponents(in: blueImage, x: 0, y: 0)
  #expect(blueCornerPixel.alpha > 200)

  let greenExcess = Int(greenCornerPixel.green) - Int(greenCornerPixel.blue)
  let blueExcess = Int(blueCornerPixel.green) - Int(blueCornerPixel.blue)
  #expect(greenExcess > 20)
  #expect(blueExcess < -20)
}

@Test @MainActor func `canvas PDF export keeps generated vector image symbols visible`() async throws {
  let canvasSize = CGSize(width: 128, height: 128)
  let tessera = makeCanvasTessera(
    symbols: [makeVectorGeneratedSymbol(size: 88, color: .red, zIndex: 2)],
    pinnedSymbols: [],
  )

  let cgImage = try await exportedCGImage(
    from: tessera,
    format: .pdf,
    canvasSize: canvasSize,
  )
  let centerPixel = try pixelComponents(in: cgImage, x: cgImage.width / 2, y: cgImage.height / 2)

  #expect(centerPixel.alpha > 200)
  #expect(centerPixel.red > 180)
  #expect(Int(centerPixel.red) - Int(centerPixel.blue) > 100)
}

@Test @MainActor func `canvas PDF export keeps pinned vector image symbols visible`() async throws {
  let canvasSize = CGSize(width: 128, height: 128)
  let tessera = makeCanvasTessera(
    symbols: [],
    pinnedSymbols: [makeVectorPinnedSymbol(size: 88, color: .red, zIndex: 2)],
  )

  let cgImage = try await exportedCGImage(
    from: tessera,
    format: .pdf,
    canvasSize: canvasSize,
  )
  let centerPixel = try pixelComponents(in: cgImage, x: cgImage.width / 2, y: cgImage.height / 2)

  #expect(centerPixel.alpha > 200)
  #expect(centerPixel.red > 180)
  #expect(Int(centerPixel.red) - Int(centerPixel.blue) > 100)
}

@Test @MainActor func `canvas exports keep mixed vector image symbols ordered consistently between PNG and PDF`(
) async throws {
  let canvasSize = CGSize(width: 128, height: 128)
  let generatedSymbol = makeColoredGeneratedSymbol(
    color: .blue,
    size: CGSize(width: 120, height: 120),
    zIndex: 4,
    collisionCenter: CGPoint(x: -50, y: 0),
    collisionSize: CGSize(width: 8, height: 8),
  )
  let pinnedSymbol = makeVectorPinnedSymbol(
    size: 72,
    color: .red,
    zIndex: 0,
    collisionCenter: CGPoint(x: 50, y: 0),
    collisionSize: CGSize(width: 8, height: 8),
  )
  let tessera = makeCanvasTessera(
    symbols: [generatedSymbol],
    pinnedSymbols: [pinnedSymbol],
  )

  let pngImage = try await exportedCGImage(
    from: tessera,
    format: .png,
    canvasSize: canvasSize,
  )
  let pdfImage = try await exportedCGImage(
    from: tessera,
    format: .pdf,
    canvasSize: canvasSize,
  )
  let pngCenterPixel = try pixelComponents(in: pngImage, x: pngImage.width / 2, y: pngImage.height / 2)
  let pdfCenterPixel = try pixelComponents(in: pdfImage, x: pdfImage.width / 2, y: pdfImage.height / 2)

  #expect(pngCenterPixel.alpha > 200)
  #expect(pdfCenterPixel.alpha > 200)
  #expect(pngCenterPixel.blue > 180)
  #expect(pdfCenterPixel.blue > 180)
  #expect(Int(pngCenterPixel.blue) - Int(pngCenterPixel.red) > 100)
  #expect(Int(pdfCenterPixel.blue) - Int(pdfCenterPixel.red) > 100)
}

private let collisionOverlaySamplePoint = (x: 84, y: 64)

@MainActor
private func makeCanvasTessera(
  symbols: [Symbol],
  pinnedSymbols: [PinnedSymbol],
) -> Tessera {
  Tessera(
    Pattern(
      symbols: symbols,
      placement: .grid(columns: 1, rows: 1),
    ),
  )
  .mode(.canvas(edgeBehavior: .finite))
  .seed(.fixed(1))
  .pinnedSymbols(pinnedSymbols)
}

@MainActor
private func makeGeneratedCollisionOverlayRenderer() -> TesseraRenderer {
  let symbol = Symbol(
    weight: 1,
    rotation: .degrees(0)...(.degrees(0)),
    scale: 1...1,
    collider: .shape(.rectangle(center: .zero, size: CGSize(width: 60, height: 60))),
  ) {
    Circle()
      .fill(Color.red)
      .frame(width: 20, height: 20)
  }

  return TesseraRenderer(
    Pattern(
      symbols: [symbol],
      placement: .grid(columns: 1, rows: 1),
    ),
  )
}

@MainActor
private func makeColoredGeneratedSymbol(
  color: Color,
  size: CGSize,
  zIndex: Double,
  collisionCenter: CGPoint = .zero,
  collisionSize: CGSize? = nil,
) -> Symbol {
  let resolvedCollisionSize = collisionSize ?? size
  return Symbol(
    zIndex: zIndex,
    rotation: .degrees(0)...(.degrees(0)),
    scale: 1...1,
    collider: .shape(.rectangle(center: collisionCenter, size: resolvedCollisionSize)),
  ) {
    Rectangle()
      .fill(color)
      .frame(width: size.width, height: size.height)
  }
}

@MainActor
private func makeVectorGeneratedSymbol(
  size: CGFloat,
  color: Color,
  zIndex: Double,
  collisionCenter: CGPoint = .zero,
  collisionSize: CGSize? = nil,
) -> Symbol {
  let resolvedCollisionSize = collisionSize ?? CGSize(width: size, height: size)
  return Symbol(
    zIndex: zIndex,
    rotation: .degrees(0)...(.degrees(0)),
    scale: 1...1,
    collider: .shape(.rectangle(center: collisionCenter, size: resolvedCollisionSize)),
  ) {
    Image(systemName: "square.fill")
      .resizable()
      .foregroundStyle(color)
      .frame(width: size, height: size)
  }
}

@MainActor
private func makeColoredPinnedSymbol(
  color: Color,
  size: CGSize,
  zIndex: Double,
  collisionCenter: CGPoint = .zero,
  collisionSize: CGSize? = nil,
) -> PinnedSymbol {
  let resolvedCollisionSize = collisionSize ?? size
  return PinnedSymbol(
    position: .centered(),
    zIndex: zIndex,
    collider: .shape(.rectangle(center: collisionCenter, size: resolvedCollisionSize)),
  ) {
    Rectangle()
      .fill(color)
      .frame(width: size.width, height: size.height)
  }
}

@MainActor
private func makeVectorPinnedSymbol(
  size: CGFloat,
  color: Color,
  zIndex: Double,
  collisionCenter: CGPoint = .zero,
  collisionSize: CGSize? = nil,
) -> PinnedSymbol {
  let resolvedCollisionSize = collisionSize ?? CGSize(width: size, height: size)
  return PinnedSymbol(
    position: .centered(),
    zIndex: zIndex,
    collider: .shape(.rectangle(center: collisionCenter, size: resolvedCollisionSize)),
  ) {
    Image(systemName: "square.fill")
      .resizable()
      .foregroundStyle(color)
      .frame(width: size, height: size)
  }
}

@MainActor
private func makeCollisionOverlayPinnedSymbol(at position: CGPoint) -> PinnedSymbol {
  PinnedSymbol(
    position: PinnedPosition(position),
    rotation: .degrees(0),
    scale: 1,
    collider: .shape(.rectangle(center: .zero, size: CGSize(width: 60, height: 60))),
  ) {
    Circle()
      .fill(Color.red)
      .frame(width: 20, height: 20)
  }
}

@MainActor
private func exportedCGImage(
  from tessera: Tessera,
  format: ExportFormat,
  canvasSize: CGSize,
  backgroundColor: Color? = nil,
  pageSize: CGSize? = nil,
) async throws -> CGImage {
  let temporaryDirectory = FileManager.default.temporaryDirectory
  let fileName = UUID().uuidString
  let exportedURL = try await tessera.export(
    format,
    options: .init(
      directory: temporaryDirectory,
      fileName: fileName,
      backgroundColor: backgroundColor,
      pageSize: pageSize,
    ),
    canvasSize: canvasSize,
  )
  defer { try? FileManager.default.removeItem(at: exportedURL) }

  switch format {
  case .png:
    return try cgImageFromPNGFile(at: exportedURL)
  case .pdf:
    return try cgImageFromPDFFile(at: exportedURL)
  }
}
