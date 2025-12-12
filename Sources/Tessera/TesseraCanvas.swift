// By Dennis Müller

import CoreGraphics
import Foundation
import ImageIO
import SwiftUI
import UniformTypeIdentifiers

/// Defines how a tessera canvas treats its edges.
public enum TesseraCanvasEdgeBehavior: Sendable {
  /// No wrapping. Items are clipped at the canvas bounds.
  case finite
  /// Toroidal wrapping like a tile, producing a seamlessly tileable canvas.
  case seamlessWrapping
}

/// A fixed view placed once into a finite tessera canvas.
///
/// Fixed placements participate in collision checks so generated items fill around them.
public struct TesseraFixedPlacement: Identifiable {
  public var id: UUID
  /// Center position in canvas coordinates (origin at top-left).
  public var position: CGPoint
  /// Rotation applied to drawing and collision checks.
  public var rotation: Angle
  /// Uniform scale applied to drawing and collision checks.
  public var scale: CGFloat
  /// Collision geometry used as an obstacle for generated items.
  public var collisionShape: CollisionShape
  private let builder: () -> AnyView

  /// Creates a fixed placement.
  /// - Parameters:
  ///   - position: Center position in canvas space.
  ///   - rotation: Rotation applied to drawing and collisions.
  ///   - scale: Uniform scale applied to drawing and collisions.
  ///   - collisionShape: Obstacle shape in local space, centered on origin.
  ///   - content: View builder for the fixed symbol.
  public init(
    id: UUID = UUID(),
    position: CGPoint,
    rotation: Angle = .degrees(0),
    scale: CGFloat = 1,
    collisionShape: CollisionShape,
    @ViewBuilder content: @escaping () -> some View,
  ) {
    self.id = id
    self.position = position
    self.rotation = rotation
    self.scale = scale
    self.collisionShape = collisionShape
    builder = { AnyView(content()) }
  }

  /// Convenience initializer that derives a circular collision shape from an approximate size.
  /// - Parameters:
  ///   - position: Center position in canvas space.
  ///   - rotation: Rotation applied to drawing and collisions.
  ///   - scale: Uniform scale applied to drawing and collisions.
  ///   - approximateSize: Size used to build a conservative circular collider.
  ///   - content: View builder for the fixed symbol.
  public init(
    id: UUID = UUID(),
    position: CGPoint,
    rotation: Angle = .degrees(0),
    scale: CGFloat = 1,
    approximateSize: CGSize = CGSize(width: 30, height: 30),
    @ViewBuilder content: @escaping () -> some View,
  ) {
    let radius = hypot(approximateSize.width, approximateSize.height) / 2
    self.init(
      id: id,
      position: position,
      rotation: rotation,
      scale: scale,
      collisionShape: .circle(radius: radius),
      content: content,
    )
  }

  @ViewBuilder
  func makeView() -> some View {
    builder()
  }
}

/// Fills a finite canvas once using a tessera configuration, respecting fixed placements.
public struct TesseraCanvas: View {
  public var configuration: TesseraConfiguration
  public var canvasSize: CGSize
  public var fixedPlacements: [TesseraFixedPlacement]
  public var seed: UInt64
  public var edgeBehavior: TesseraCanvasEdgeBehavior

  @State private var cachedPlacedItemDescriptors: [ShapePlacementEngine.PlacedItemDescriptor] = []

  /// Creates a finite tessera canvas.
  /// - Parameters:
  ///   - configuration: Base configuration (items, spacing, density, seed).
  ///   - canvasSize: The full output size to fill (e.g. 1920×1080, 3840×2160).
  ///   - fixedPlacements: Views placed once; treated as obstacles.
  ///   - seed: Optional override for deterministic output.
  ///   - edgeBehavior: Whether to wrap edges toroidally or not.
  public init(
    _ configuration: TesseraConfiguration,
    canvasSize: CGSize,
    fixedPlacements: [TesseraFixedPlacement] = [],
    seed: UInt64? = nil,
    edgeBehavior: TesseraCanvasEdgeBehavior = .finite,
  ) {
    self.configuration = configuration
    self.canvasSize = canvasSize
    self.fixedPlacements = fixedPlacements
    self.seed = seed ?? configuration.seed
    self.edgeBehavior = edgeBehavior
  }

  public var body: some View {
    let configuration = configuration
    let fixedPlacements = fixedPlacements
    let edgeBehavior = edgeBehavior
    let placedItemDescriptors = cachedPlacedItemDescriptors

    Canvas(opaque: false, colorMode: .nonLinear, rendersAsynchronously: true) { context, size in
      let wrappedOffset = CGSize(
        width: configuration.patternOffset.width.truncatingRemainder(dividingBy: size.width),
        height: configuration.patternOffset.height.truncatingRemainder(dividingBy: size.height),
      )

      let offsets: [CGSize] = switch edgeBehavior {
      case .finite:
        [.zero]
      case .seamlessWrapping:
        [
          .zero,
          CGSize(width: size.width, height: 0),
          CGSize(width: -size.width, height: 0),
          CGSize(width: 0, height: size.height),
          CGSize(width: 0, height: -size.height),
          CGSize(width: size.width, height: size.height),
          CGSize(width: size.width, height: -size.height),
          CGSize(width: -size.width, height: size.height),
          CGSize(width: -size.width, height: -size.height),
        ]
      }

      for fixedPlacement in fixedPlacements {
        guard let symbol = context.resolveSymbol(id: fixedPlacement.id) else { continue }

        for offset in offsets {
          var symbolContext = context
          symbolContext.translateBy(x: offset.width, y: offset.height)
          symbolContext.translateBy(x: fixedPlacement.position.x, y: fixedPlacement.position.y)
          symbolContext.rotate(by: fixedPlacement.rotation)
          symbolContext.scaleBy(x: fixedPlacement.scale, y: fixedPlacement.scale)
          symbolContext.draw(symbol, at: .zero, anchor: .center)
        }
      }

      for placedItem in placedItemDescriptors {
        guard let symbol = context.resolveSymbol(id: placedItem.itemId) else { continue }

        for offset in offsets {
          var symbolContext = context
          symbolContext.translateBy(x: offset.width + wrappedOffset.width, y: offset.height + wrappedOffset.height)
          symbolContext.translateBy(x: placedItem.position.x, y: placedItem.position.y)
          symbolContext.rotate(by: .radians(placedItem.rotationRadians))
          symbolContext.scaleBy(x: placedItem.scale, y: placedItem.scale)
          symbolContext.draw(symbol, at: .zero, anchor: .center)
        }
      }
    } symbols: {
      ForEach(configuration.items) { item in
        item.makeView().tag(item.id)
      }
      ForEach(fixedPlacements) { placement in
        placement.makeView().tag(placement.id)
      }
    }
    .frame(width: canvasSize.width, height: canvasSize.height)
    .clipped()
    .task(id: currentComputationKey) {
      let snapshot = makeComputationSnapshot()
      await computePlacements(using: snapshot)
    }
  }

  /// Renders the tessera canvas to a PNG file.
  /// - Parameters:
  ///   - directory: Target directory where the file will be created.
  ///   - fileName: Base file name without extension; `.png` is appended automatically.
  ///   - options: Rendering configuration such as output pixel size and scale.
  /// - Returns: The resolved file URL that was written.
  @discardableResult public func renderPNG(
    to directory: URL,
    fileName: String = "tessera-canvas",
    options: TesseraRenderOptions = TesseraRenderOptions(),
  ) throws -> URL {
    let destinationURL = resolvedOutputURL(directory: directory, fileName: fileName, fileExtension: "png")
    let placedItemDescriptors = makeSynchronousPlacedDescriptors()
    let renderView = TesseraCanvasStaticRenderView(
      configuration: configuration,
      canvasSize: canvasSize,
      fixedPlacements: fixedPlacements,
      placedItemDescriptors: placedItemDescriptors,
      edgeBehavior: edgeBehavior,
    )
    let renderer = ImageRenderer(content: renderView)
    renderer.proposedSize = ProposedViewSize(canvasSize)
    renderer.scale = options.resolvedScale(contentSize: canvasSize)
    renderer.isOpaque = options.isOpaque
    renderer.colorMode = options.colorMode

    guard let cgImage = renderer.cgImage else {
      throw TesseraRenderError.failedToCreateImage
    }
    guard let destination = CGImageDestinationCreateWithURL(
      destinationURL as CFURL,
      UTType.png.identifier as CFString,
      1,
      nil,
    ) else {
      throw TesseraRenderError.failedToCreateDestination
    }

    CGImageDestinationAddImage(destination, cgImage, nil)

    guard CGImageDestinationFinalize(destination) else {
      throw TesseraRenderError.failedToFinalizeDestination
    }

    return destinationURL
  }

  /// Renders the tessera canvas to a PDF file, preserving vector content when possible.
  /// - Parameters:
  ///   - directory: Target directory where the file will be created.
  ///   - fileName: Base file name without extension; `.pdf` is appended automatically.
  ///   - pageSize: Optional PDF page size in points; defaults to the canvas size.
  ///   - options: Rendering configuration such as output pixel size and scale, applied while drawing into the PDF
  /// context.
  /// - Returns: The resolved file URL that was written.
  @discardableResult public func renderPDF(
    to directory: URL,
    fileName: String = "tessera-canvas",
    pageSize: CGSize? = nil,
    options: TesseraRenderOptions = TesseraRenderOptions(scale: 1),
  ) throws -> URL {
    let destinationURL = resolvedOutputURL(directory: directory, fileName: fileName, fileExtension: "pdf")
    let renderSize = pageSize ?? canvasSize
    var mediaBox = CGRect(origin: .zero, size: renderSize)

    guard
      let consumer = CGDataConsumer(url: destinationURL as CFURL),
      let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil)
    else {
      throw TesseraRenderError.failedToCreateDestination
    }

    let placedItemDescriptors = makeSynchronousPlacedDescriptors()
    let renderView = TesseraCanvasStaticRenderView(
      configuration: configuration,
      canvasSize: canvasSize,
      fixedPlacements: fixedPlacements,
      placedItemDescriptors: placedItemDescriptors,
      edgeBehavior: edgeBehavior,
    )
    let renderer = ImageRenderer(content: renderView)
    renderer.proposedSize = ProposedViewSize(canvasSize)
    renderer.scale = options.resolvedScale(contentSize: canvasSize)
    renderer.isOpaque = options.isOpaque
    renderer.colorMode = options.colorMode
    let rasterizationScale = options.resolvedScale(contentSize: canvasSize)

    renderer.render(rasterizationScale: rasterizationScale) { size, render in
      context.beginPDFPage(nil)
      let offsetX = (renderSize.width - size.width) / 2
      let offsetY = (renderSize.height - size.height) / 2
      context.translateBy(x: offsetX, y: offsetY)
      render(context)
      context.endPDFPage()
      context.closePDF()
    }

    return destinationURL
  }

  private func resolvedOutputURL(directory: URL, fileName: String, fileExtension: String) -> URL {
    let baseName = (fileName as NSString).deletingPathExtension
    return directory
      .appending(path: baseName)
      .appendingPathExtension(fileExtension)
  }
}

private extension TesseraCanvas {
  struct ComputationKey: Hashable, Sendable {
    var canvasSize: CGSize
    var seed: UInt64
    var edgeBehavior: TesseraCanvasEdgeBehavior
    var minimumSpacing: Double
    var density: Double
    var baseScaleRangeLowerBound: Double
    var baseScaleRangeUpperBound: Double
    var patternOffset: CGSize
    var maximumItemCount: Int
    var itemKeys: [ItemKey]
    var fixedPlacementKeys: [FixedPlacementKey]

    struct ItemKey: Hashable, Sendable {
      var id: UUID
      var weight: Double
      var allowedRotationRangeDegrees: ClosedRange<Double>
      var resolvedScaleRange: ClosedRange<Double>
      var collisionShape: CollisionShape
    }

    struct FixedPlacementKey: Hashable, Sendable {
      var id: UUID
      var position: CGPoint
      var rotationRadians: Double
      var scale: CGFloat
      var collisionShape: CollisionShape
    }
  }

  struct ComputationSnapshot: Sendable {
    var key: ComputationKey
    var itemDescriptors: [ShapePlacementEngine.PlacementItemDescriptor]
    var fixedPlacementDescriptors: [ShapePlacementEngine.FixedPlacementDescriptor]
  }

  var currentComputationKey: ComputationKey {
    let itemKeys: [ComputationKey.ItemKey] = configuration.items.map { item in
      let scaleRange = item.scaleRange ?? configuration.baseScaleRange
      return ComputationKey.ItemKey(
        id: item.id,
        weight: item.weight,
        allowedRotationRangeDegrees: item.allowedRotationRange.lowerBound.degrees...item.allowedRotationRange.upperBound
          .degrees,
        resolvedScaleRange: scaleRange,
        collisionShape: item.collisionShape,
      )
    }

    let fixedPlacementKeys: [ComputationKey.FixedPlacementKey] = fixedPlacements.map { placement in
      ComputationKey.FixedPlacementKey(
        id: placement.id,
        position: placement.position,
        rotationRadians: placement.rotation.radians,
        scale: placement.scale,
        collisionShape: placement.collisionShape,
      )
    }

    return ComputationKey(
      canvasSize: canvasSize,
      seed: seed,
      edgeBehavior: edgeBehavior,
      minimumSpacing: configuration.minimumSpacing,
      density: configuration.density,
      baseScaleRangeLowerBound: configuration.baseScaleRange.lowerBound,
      baseScaleRangeUpperBound: configuration.baseScaleRange.upperBound,
      patternOffset: configuration.patternOffset,
      maximumItemCount: configuration.maximumItemCount,
      itemKeys: itemKeys,
      fixedPlacementKeys: fixedPlacementKeys,
    )
  }

  func makeComputationSnapshot() -> ComputationSnapshot {
    let itemDescriptors = makeItemDescriptors()
    let fixedPlacementDescriptors = makeFixedPlacementDescriptors()
    return ComputationSnapshot(
      key: currentComputationKey,
      itemDescriptors: itemDescriptors,
      fixedPlacementDescriptors: fixedPlacementDescriptors,
    )
  }

  func computePlacements(using snapshot: ComputationSnapshot) async {
    let computeTask = Task.detached(priority: .userInitiated) {
      var randomGenerator = SeededGenerator(seed: snapshot.key.seed)
      return ShapePlacementEngine.placeItemDescriptors(
        in: snapshot.key.canvasSize,
        itemDescriptors: snapshot.itemDescriptors,
        fixedPlacementDescriptors: snapshot.fixedPlacementDescriptors,
        edgeBehavior: snapshot.key.edgeBehavior,
        minimumSpacing: snapshot.key.minimumSpacing,
        density: snapshot.key.density,
        maximumItemCount: snapshot.key.maximumItemCount,
        randomGenerator: &randomGenerator,
      )
    }

    let placedItemDescriptors = await withTaskCancellationHandler {
      await computeTask.value
    } onCancel: {
      computeTask.cancel()
    }

    await MainActor.run {
      guard snapshot.key == currentComputationKey else { return }

      cachedPlacedItemDescriptors = placedItemDescriptors
    }
  }

  func makeSynchronousPlacedDescriptors() -> [ShapePlacementEngine.PlacedItemDescriptor] {
    let itemDescriptors = makeItemDescriptors()
    let fixedPlacementDescriptors = makeFixedPlacementDescriptors()
    var randomGenerator = SeededGenerator(seed: seed)
    return ShapePlacementEngine.placeItemDescriptors(
      in: canvasSize,
      itemDescriptors: itemDescriptors,
      fixedPlacementDescriptors: fixedPlacementDescriptors,
      edgeBehavior: edgeBehavior,
      minimumSpacing: configuration.minimumSpacing,
      density: configuration.density,
      maximumItemCount: configuration.maximumItemCount,
      randomGenerator: &randomGenerator,
    )
  }

  func makeItemDescriptors() -> [ShapePlacementEngine.PlacementItemDescriptor] {
    configuration.items.map { item in
      let scaleRange = item.scaleRange ?? configuration.baseScaleRange
      return ShapePlacementEngine.PlacementItemDescriptor(
        id: item.id,
        weight: item.weight,
        allowedRotationRangeDegrees: item.allowedRotationRange.lowerBound.degrees...item.allowedRotationRange.upperBound
          .degrees,
        resolvedScaleRange: scaleRange,
        collisionShape: item.collisionShape,
      )
    }
  }

  func makeFixedPlacementDescriptors() -> [ShapePlacementEngine.FixedPlacementDescriptor] {
    fixedPlacements.map { placement in
      ShapePlacementEngine.FixedPlacementDescriptor(
        id: placement.id,
        position: placement.position,
        rotationRadians: placement.rotation.radians,
        scale: placement.scale,
        collisionShape: placement.collisionShape,
      )
    }
  }
}

private struct TesseraCanvasStaticRenderView: View {
  var configuration: TesseraConfiguration
  var canvasSize: CGSize
  var fixedPlacements: [TesseraFixedPlacement]
  var placedItemDescriptors: [ShapePlacementEngine.PlacedItemDescriptor]
  var edgeBehavior: TesseraCanvasEdgeBehavior

  var body: some View {
    Canvas(opaque: false, colorMode: .nonLinear, rendersAsynchronously: false) { context, size in
      let wrappedOffset = CGSize(
        width: configuration.patternOffset.width.truncatingRemainder(dividingBy: size.width),
        height: configuration.patternOffset.height.truncatingRemainder(dividingBy: size.height),
      )

      let offsets: [CGSize] = switch edgeBehavior {
      case .finite:
        [.zero]
      case .seamlessWrapping:
        [
          .zero,
          CGSize(width: size.width, height: 0),
          CGSize(width: -size.width, height: 0),
          CGSize(width: 0, height: size.height),
          CGSize(width: 0, height: -size.height),
          CGSize(width: size.width, height: size.height),
          CGSize(width: size.width, height: -size.height),
          CGSize(width: -size.width, height: size.height),
          CGSize(width: -size.width, height: -size.height),
        ]
      }

      for fixedPlacement in fixedPlacements {
        guard let symbol = context.resolveSymbol(id: fixedPlacement.id) else { continue }

        for offset in offsets {
          var symbolContext = context
          symbolContext.translateBy(x: offset.width, y: offset.height)
          symbolContext.translateBy(x: fixedPlacement.position.x, y: fixedPlacement.position.y)
          symbolContext.rotate(by: fixedPlacement.rotation)
          symbolContext.scaleBy(x: fixedPlacement.scale, y: fixedPlacement.scale)
          symbolContext.draw(symbol, at: .zero, anchor: .center)
        }
      }

      for placedItem in placedItemDescriptors {
        guard let symbol = context.resolveSymbol(id: placedItem.itemId) else { continue }

        for offset in offsets {
          var symbolContext = context
          symbolContext.translateBy(x: offset.width + wrappedOffset.width, y: offset.height + wrappedOffset.height)
          symbolContext.translateBy(x: placedItem.position.x, y: placedItem.position.y)
          symbolContext.rotate(by: .radians(placedItem.rotationRadians))
          symbolContext.scaleBy(x: placedItem.scale, y: placedItem.scale)
          symbolContext.draw(symbol, at: .zero, anchor: .center)
        }
      }
    } symbols: {
      ForEach(configuration.items) { item in
        item.makeView().tag(item.id)
      }
      ForEach(fixedPlacements) { placement in
        placement.makeView().tag(placement.id)
      }
    }
    .frame(width: canvasSize.width, height: canvasSize.height)
    .clipped()
  }
}
