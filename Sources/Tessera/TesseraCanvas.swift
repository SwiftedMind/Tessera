// By Dennis Müller

import CoreGraphics
import Foundation
import ImageIO
import SwiftUI
import UniformTypeIdentifiers

/// Defines how a tessera canvas treats its edges.
public enum TesseraEdgeBehavior: Sendable {
  /// No wrapping. Symbols are clipped at the canvas bounds.
  case finite
  /// Toroidal wrapping like a tile, producing a seamlessly tileable canvas.
  case seamlessWrapping
}

/// A fixed view placed once into a finite tessera canvas.
///
/// Fixed symbols participate in collision checks so generated symbols fill around them.
public struct TesseraPinnedSymbol: Identifiable {
  public var id: UUID
  /// Center position inside the canvas.
  public var position: TesseraPlacementPosition
  /// Rotation applied to drawing and collision checks.
  public var rotation: Angle
  /// Uniform scale applied to drawing and collision checks.
  public var scale: CGFloat
  /// Collision geometry used as an obstacle for generated symbols.
  ///
  /// Complex polygons and multi-polygon shapes increase placement cost.
  public var collisionShape: CollisionShape
  private let builder: () -> AnyView

  /// Creates a fixed symbol.
  /// - Parameters:
  ///   - position: Center position inside the canvas.
  ///   - rotation: Rotation applied to drawing and collisions.
  ///   - scale: Uniform scale applied to drawing and collisions.
  ///   - collisionShape: Obstacle shape in local space. Complex polygons and multi-polygon shapes increase placement
  ///     cost.
  ///   - content: View builder for the fixed symbol.
  public init(
    id: UUID = UUID(),
    position: TesseraPlacementPosition,
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

  /// Convenience initializer for absolute positions.
  public init(
    id: UUID = UUID(),
    position: CGPoint,
    rotation: Angle = .degrees(0),
    scale: CGFloat = 1,
    collisionShape: CollisionShape,
    @ViewBuilder content: @escaping () -> some View,
  ) {
    self.init(
      id: id,
      position: .absolute(position),
      rotation: rotation,
      scale: scale,
      collisionShape: collisionShape,
      content: content,
    )
  }

  /// Convenience initializer that derives a circular collision shape from an approximate size.
  /// - Parameters:
  ///   - position: Center position inside the canvas.
  ///   - rotation: Rotation applied to drawing and collisions.
  ///   - scale: Uniform scale applied to drawing and collisions.
  ///   - approximateSize: Size used to build a conservative circular collider.
  ///   - content: View builder for the fixed symbol.
  public init(
    id: UUID = UUID(),
    position: TesseraPlacementPosition,
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
      collisionShape: .circle(center: .zero, radius: radius),
      content: content,
    )
  }

  /// Convenience initializer for absolute positions.
  public init(
    id: UUID = UUID(),
    position: CGPoint,
    rotation: Angle = .degrees(0),
    scale: CGFloat = 1,
    approximateSize: CGSize = CGSize(width: 30, height: 30),
    @ViewBuilder content: @escaping () -> some View,
  ) {
    self.init(
      id: id,
      position: .absolute(position),
      rotation: rotation,
      scale: scale,
      approximateSize: approximateSize,
      content: content,
    )
  }

  @ViewBuilder
  func makeView() -> some View {
    builder()
  }

  func resolvedPosition(in canvasSize: CGSize) -> CGPoint {
    position.resolvedPoint(in: canvasSize)
  }
}

/// Fills a finite canvas once using a tessera configuration, respecting fixed symbols.
public struct TesseraCanvas: View {
  public var configuration: TesseraConfiguration
  public var pinnedSymbols: [TesseraPinnedSymbol]
  public var seed: UInt64
  public var edgeBehavior: TesseraEdgeBehavior
  public var onComputationStateChange: ((Bool) -> Void)?

  @State private var cachedPlacedSymbolDescriptors: [ShapePlacementEngine.PlacedSymbolDescriptor] = []
  @State private var resolvedCanvasSize: CGSize = .zero

  /// Creates a finite tessera canvas.
  /// - Parameters:
  ///   - configuration: Base configuration (symbols and placement).
  ///   - pinnedSymbols: Views placed once; treated as obstacles.
  ///   - seed: Optional seed override for organic placement.
  ///   - edgeBehavior: Whether to wrap edges toroidally or not.
  ///
  /// The canvas fills the space provided by layout. Set an explicit `.frame(...)` on this view when you need a fixed
  /// on-screen size.
  public init(
    _ configuration: TesseraConfiguration,
    pinnedSymbols: [TesseraPinnedSymbol] = [],
    seed: UInt64? = nil,
    edgeBehavior: TesseraEdgeBehavior = .finite,
    onComputationStateChange: ((Bool) -> Void)? = nil,
  ) {
    self.configuration = configuration
    self.pinnedSymbols = pinnedSymbols
    self.seed = seed ?? configuration.organicPlacement?.seed ?? TesseraConfiguration.randomSeed()
    self.edgeBehavior = edgeBehavior
    self.onComputationStateChange = onComputationStateChange
  }

  public var body: some View {
    let configuration = configuration
    let pinnedSymbols = pinnedSymbols
    let edgeBehavior = edgeBehavior
    let placedSymbolDescriptors = cachedPlacedSymbolDescriptors
    let onComputationStateChange = onComputationStateChange
    let isCollisionOverlayEnabled = configuration.showsCollisionOverlay
    let overlayShapesBySymbolId: [UUID: CollisionOverlayShape] = isCollisionOverlayEnabled
      ? configuration.symbols.reduce(into: [:]) { cache, symbol in
        cache[symbol.id] = CollisionOverlayShape(collisionShape: symbol.collisionShape)
      }
      : [:]
    let overlayShapesByPinnedSymbolId: [UUID: CollisionOverlayShape] = isCollisionOverlayEnabled
      ? pinnedSymbols.reduce(into: [:]) { cache, symbol in
        cache[symbol.id] = CollisionOverlayShape(collisionShape: symbol.collisionShape)
      }
      : [:]

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

      for pinnedSymbol in pinnedSymbols {
        guard let symbol = context.resolveSymbol(id: pinnedSymbol.id) else { continue }

        let resolvedPosition = pinnedSymbol.resolvedPosition(in: size)

        for offset in offsets {
          var symbolContext = context
          symbolContext.translateBy(x: offset.width, y: offset.height)
          symbolContext.translateBy(x: resolvedPosition.x, y: resolvedPosition.y)
          symbolContext.rotate(by: pinnedSymbol.rotation)
          symbolContext.scaleBy(x: pinnedSymbol.scale, y: pinnedSymbol.scale)
          symbolContext.draw(symbol, at: .zero, anchor: .center)

          if isCollisionOverlayEnabled,
             let overlayShape = overlayShapesByPinnedSymbolId[pinnedSymbol.id] {
            CollisionOverlayRenderer.draw(overlayShape: overlayShape, in: &symbolContext)
          }
        }
      }

      for placedSymbol in placedSymbolDescriptors {
        guard let symbol = context.resolveSymbol(id: placedSymbol.symbolId) else { continue }

        for offset in offsets {
          var symbolContext = context
          symbolContext.translateBy(x: offset.width + wrappedOffset.width, y: offset.height + wrappedOffset.height)
          symbolContext.translateBy(x: placedSymbol.position.x, y: placedSymbol.position.y)
          symbolContext.rotate(by: .radians(placedSymbol.rotationRadians))
          symbolContext.scaleBy(x: placedSymbol.scale, y: placedSymbol.scale)
          symbolContext.draw(symbol, at: .zero, anchor: .center)

          if isCollisionOverlayEnabled,
             let overlayShape = overlayShapesBySymbolId[placedSymbol.symbolId] {
            CollisionOverlayRenderer.draw(overlayShape: overlayShape, in: &symbolContext)
          }
        }
      }
    } symbols: {
      ForEach(configuration.symbols) { symbol in
        symbol.makeView().tag(symbol.id)
      }
      ForEach(pinnedSymbols) { pinnedSymbol in
        pinnedSymbol.makeView().tag(pinnedSymbol.id)
      }
    }
    .clipped()
    .background(
      GeometryReader { proxy in
        Color.clear
          .preference(key: TesseraCanvasSizePreferenceKey.self, value: proxy.size)
      },
    )
    .onPreferenceChange(TesseraCanvasSizePreferenceKey.self) { newSize in
      if resolvedCanvasSize != newSize {
        resolvedCanvasSize = newSize
      }
    }
    .task(id: currentComputationKey) {
      await MainActor.run {
        onComputationStateChange?(true)
      }
      defer {
        if Task.isCancelled == false {
          Task { @MainActor in
            onComputationStateChange?(false)
          }
        }
      }

      let canvasSize = resolvedCanvasSize
      guard canvasSize.width > 0, canvasSize.height > 0 else {
        cachedPlacedSymbolDescriptors = []
        return
      }

      let snapshot = makeComputationSnapshot(for: canvasSize)
      await computePlacements(using: snapshot)
    }
  }

  /// Renders the tessera canvas to a PNG file.
  /// - Parameters:
  ///   - directory: Target directory where the file will be created.
  ///   - fileName: Base file name without extension; `.png` is appended automatically.
  ///   - canvasSize: The size of the canvas to export.
  ///   - backgroundColor: Optional background fill rendered behind the canvas. Defaults to no background
  /// (transparent).
  ///   - colorScheme: Optional SwiftUI color scheme override applied while rendering. Useful when symbols use semantic
  /// colors such as `Color.primary`.
  ///   - options: Rendering configuration such as output pixel size and scale.
  /// - Returns: The resolved file URL that was written.
  @discardableResult public func renderPNG(
    to directory: URL,
    fileName: String = "tessera-canvas",
    canvasSize: CGSize,
    backgroundColor: Color? = nil,
    colorScheme: ColorScheme? = nil,
    options: TesseraRenderOptions = TesseraRenderOptions(),
  ) throws -> URL {
    var renderConfiguration = configuration
    if case var .organic(organicPlacement) = renderConfiguration.placement {
      organicPlacement.showsCollisionOverlay = options.showsCollisionOverlay
      renderConfiguration.placement = .organic(organicPlacement)
    }
    let destinationURL = resolvedOutputURL(directory: directory, fileName: fileName, fileExtension: "png")
    let placedSymbolDescriptors = makeSynchronousPlacedDescriptors(for: canvasSize)
    let renderView = TesseraCanvasStaticRenderView(
      configuration: renderConfiguration,
      canvasSize: canvasSize,
      pinnedSymbols: pinnedSymbols,
      placedSymbolDescriptors: placedSymbolDescriptors,
      edgeBehavior: edgeBehavior,
    )
    let exportView = TesseraCanvasExportRenderView(
      pageSize: canvasSize,
      backgroundColor: backgroundColor,
      content: renderView,
    )
    let rendererContent = if let colorScheme {
      AnyView(exportView.environment(\.colorScheme, colorScheme))
    } else {
      AnyView(exportView)
    }
    let renderer = ImageRenderer(content: rendererContent)
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
  ///   - canvasSize: The size of the canvas to export.
  ///   - backgroundColor: Optional background fill rendered behind the canvas. Defaults to no background
  /// (transparent).
  ///   - colorScheme: Optional SwiftUI color scheme override applied while rendering. Useful when symbols use semantic
  /// colors such as `Color.primary`.
  ///   - pageSize: Optional PDF page size in points; defaults to the canvas size.
  ///   - options: Rendering configuration such as output pixel size and scale, applied while drawing into the PDF
  /// context.
  /// - Returns: The resolved file URL that was written.
  @discardableResult public func renderPDF(
    to directory: URL,
    fileName: String = "tessera-canvas",
    canvasSize: CGSize,
    backgroundColor: Color? = nil,
    colorScheme: ColorScheme? = nil,
    pageSize: CGSize? = nil,
    options: TesseraRenderOptions = TesseraRenderOptions(scale: 1),
  ) throws -> URL {
    var renderConfiguration = configuration
    if case var .organic(organicPlacement) = renderConfiguration.placement {
      organicPlacement.showsCollisionOverlay = options.showsCollisionOverlay
      renderConfiguration.placement = .organic(organicPlacement)
    }
    let destinationURL = resolvedOutputURL(directory: directory, fileName: fileName, fileExtension: "pdf")
    let renderSize = pageSize ?? canvasSize
    var mediaBox = CGRect(origin: .zero, size: renderSize)

    guard
      let consumer = CGDataConsumer(url: destinationURL as CFURL),
      let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil)
    else {
      throw TesseraRenderError.failedToCreateDestination
    }

    let placedSymbolDescriptors = makeSynchronousPlacedDescriptors(for: canvasSize)
    let renderView = TesseraCanvasStaticRenderView(
      configuration: renderConfiguration,
      canvasSize: canvasSize,
      pinnedSymbols: pinnedSymbols,
      placedSymbolDescriptors: placedSymbolDescriptors,
      edgeBehavior: edgeBehavior,
    )
    let exportView = TesseraCanvasExportRenderView(
      pageSize: renderSize,
      backgroundColor: backgroundColor,
      content: renderView,
    )
    let rendererContent = if let colorScheme {
      AnyView(exportView.environment(\.colorScheme, colorScheme))
    } else {
      AnyView(exportView)
    }
    let renderer = ImageRenderer(content: rendererContent)
    renderer.proposedSize = ProposedViewSize(renderSize)
    renderer.scale = options.resolvedScale(contentSize: canvasSize)
    renderer.isOpaque = options.isOpaque
    renderer.colorMode = options.colorMode
    let rasterizationScale = options.resolvedScale(contentSize: canvasSize)

    renderer.render(rasterizationScale: rasterizationScale) { _, render in
      context.beginPDFPage(nil)
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

private struct TesseraCanvasExportRenderView<Content: View>: View {
  var pageSize: CGSize
  var backgroundColor: Color?
  var content: Content

  var body: some View {
    ZStack {
      if let backgroundColor {
        backgroundColor
      }
      content
    }
    .frame(width: pageSize.width, height: pageSize.height)
    .clipped()
  }
}

private struct TesseraCanvasSizePreferenceKey: PreferenceKey {
  static let defaultValue: CGSize = .zero

  static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
    value = nextValue()
  }
}

private extension TesseraCanvas {
  struct ComputationKey: Hashable, Sendable {
    var canvasSize: CGSize
    var edgeBehavior: TesseraEdgeBehavior
    var placement: TesseraPlacement
    var patternOffset: CGSize
    var symbolKeys: [SymbolKey]
    var pinnedSymbolKeys: [PinnedSymbolKey]

    struct SymbolKey: Hashable, Sendable {
      var id: UUID
      var weight: Double
      var allowedRotationRangeDegrees: ClosedRange<Double>
      var resolvedScaleRange: ClosedRange<Double>
      var collisionShape: CollisionShape
    }

    struct PinnedSymbolKey: Hashable, Sendable {
      enum PositionKind: Hashable, Sendable {
        case absolute
        case relative
      }

      var id: UUID
      var positionKind: PositionKind
      var absoluteX: Double
      var absoluteY: Double
      var unitPointX: Double
      var unitPointY: Double
      var offsetWidth: Double
      var offsetHeight: Double
      var rotationRadians: Double
      var scale: CGFloat
      var collisionShape: CollisionShape
    }
  }

  struct ComputationSnapshot: Sendable {
    var key: ComputationKey
    var symbolDescriptors: [ShapePlacementEngine.PlacementSymbolDescriptor]
    var pinnedSymbolDescriptors: [ShapePlacementEngine.PinnedSymbolDescriptor]
  }

  var resolvedPlacement: TesseraPlacement {
    switch configuration.placement {
    case var .organic(organicPlacement):
      organicPlacement.seed = seed
      return .organic(organicPlacement)
    case .grid:
      return configuration.placement
    }
  }

  var currentComputationKey: ComputationKey {
    makeComputationKey(for: resolvedCanvasSize)
  }

  func makeComputationSnapshot(for canvasSize: CGSize) -> ComputationSnapshot {
    let key = makeComputationKey(for: canvasSize)
    return ComputationSnapshot(
      key: key,
      symbolDescriptors: makeSymbolDescriptors(using: key.placement),
      pinnedSymbolDescriptors: makePinnedSymbolDescriptors(for: canvasSize),
    )
  }

  func computePlacements(using snapshot: ComputationSnapshot) async {
    let placementSeed = seed(for: snapshot.key.placement)
    let computeTask = Task.detached(priority: .userInitiated) {
      var randomGenerator = SeededGenerator(seed: placementSeed)
      return ShapePlacementEngine.placeSymbolDescriptors(
        in: snapshot.key.canvasSize,
        symbolDescriptors: snapshot.symbolDescriptors,
        pinnedSymbolDescriptors: snapshot.pinnedSymbolDescriptors,
        edgeBehavior: snapshot.key.edgeBehavior,
        placement: snapshot.key.placement,
        randomGenerator: &randomGenerator,
      )
    }

    let placedSymbolDescriptors = await withTaskCancellationHandler {
      await computeTask.value
    } onCancel: {
      computeTask.cancel()
    }

    await MainActor.run {
      guard snapshot.key == currentComputationKey else { return }

      cachedPlacedSymbolDescriptors = placedSymbolDescriptors
    }
  }

  func makeSynchronousPlacedDescriptors(for canvasSize: CGSize) -> [ShapePlacementEngine.PlacedSymbolDescriptor] {
    let placement = resolvedPlacement
    let symbolDescriptors = makeSymbolDescriptors(using: placement)
    let pinnedSymbolDescriptors = makePinnedSymbolDescriptors(for: canvasSize)
    var randomGenerator = SeededGenerator(seed: seed(for: placement))
    return ShapePlacementEngine.placeSymbolDescriptors(
      in: canvasSize,
      symbolDescriptors: symbolDescriptors,
      pinnedSymbolDescriptors: pinnedSymbolDescriptors,
      edgeBehavior: edgeBehavior,
      placement: placement,
      randomGenerator: &randomGenerator,
    )
  }

  func makeSymbolDescriptors(using placement: TesseraPlacement) -> [ShapePlacementEngine.PlacementSymbolDescriptor] {
    configuration.symbols.map { symbol in
      let scaleRange = resolvedScaleRange(for: symbol, placement: placement)
      return ShapePlacementEngine.PlacementSymbolDescriptor(
        id: symbol.id,
        weight: symbol.weight,
        allowedRotationRangeDegrees: symbol.allowedRotationRange.lowerBound.degrees...symbol.allowedRotationRange
          .upperBound
          .degrees,
        resolvedScaleRange: scaleRange,
        collisionShape: symbol.collisionShape,
      )
    }
  }

  func makePinnedSymbolDescriptors(for canvasSize: CGSize) -> [ShapePlacementEngine.PinnedSymbolDescriptor] {
    pinnedSymbols.map { pinnedSymbol in
      ShapePlacementEngine.PinnedSymbolDescriptor(
        id: pinnedSymbol.id,
        position: pinnedSymbol.resolvedPosition(in: canvasSize),
        rotationRadians: pinnedSymbol.rotation.radians,
        scale: pinnedSymbol.scale,
        collisionShape: pinnedSymbol.collisionShape,
      )
    }
  }

  func resolvedScaleRange(
    for symbol: TesseraSymbol,
    placement: TesseraPlacement,
  ) -> ClosedRange<Double> {
    switch placement {
    case let .organic(organicPlacement):
      symbol.scaleRange ?? organicPlacement.baseScaleRange
    case .grid:
      symbol.scaleRange ?? 1...1
    }
  }

  func seed(for placement: TesseraPlacement) -> UInt64 {
    switch placement {
    case let .organic(organicPlacement):
      organicPlacement.seed
    case .grid:
      0
    }
  }

  func makeComputationKey(for canvasSize: CGSize) -> ComputationKey {
    let placement = resolvedPlacement
    let symbolKeys: [ComputationKey.SymbolKey] = configuration.symbols.map { symbol in
      let scaleRange = resolvedScaleRange(for: symbol, placement: placement)
      return ComputationKey.SymbolKey(
        id: symbol.id,
        weight: symbol.weight,
        allowedRotationRangeDegrees: symbol.allowedRotationRange.lowerBound.degrees...symbol.allowedRotationRange
          .upperBound
          .degrees,
        resolvedScaleRange: scaleRange,
        collisionShape: symbol.collisionShape,
      )
    }

    let pinnedSymbolKeys: [ComputationKey.PinnedSymbolKey] = pinnedSymbols.map { pinnedSymbol in
      let positionKey = makePinnedSymbolPositionKey(from: pinnedSymbol.position)
      return ComputationKey.PinnedSymbolKey(
        id: pinnedSymbol.id,
        positionKind: positionKey.positionKind,
        absoluteX: positionKey.absoluteX,
        absoluteY: positionKey.absoluteY,
        unitPointX: positionKey.unitPointX,
        unitPointY: positionKey.unitPointY,
        offsetWidth: positionKey.offsetWidth,
        offsetHeight: positionKey.offsetHeight,
        rotationRadians: pinnedSymbol.rotation.radians,
        scale: pinnedSymbol.scale,
        collisionShape: pinnedSymbol.collisionShape,
      )
    }

    return ComputationKey(
      canvasSize: canvasSize,
      edgeBehavior: edgeBehavior,
      placement: placement,
      patternOffset: configuration.patternOffset,
      symbolKeys: symbolKeys,
      pinnedSymbolKeys: pinnedSymbolKeys,
    )
  }

  private func makePinnedSymbolPositionKey(from position: TesseraPlacementPosition) -> (
    positionKind: ComputationKey.PinnedSymbolKey.PositionKind,
    absoluteX: Double,
    absoluteY: Double,
    unitPointX: Double,
    unitPointY: Double,
    offsetWidth: Double,
    offsetHeight: Double,
  ) {
    switch position {
    case let .absolute(point):
      (
        positionKind: .absolute,
        absoluteX: Double(point.x),
        absoluteY: Double(point.y),
        unitPointX: 0,
        unitPointY: 0,
        offsetWidth: 0,
        offsetHeight: 0,
      )
    case let .relative(unitPoint, offset):
      (
        positionKind: .relative,
        absoluteX: 0,
        absoluteY: 0,
        unitPointX: Double(unitPoint.x),
        unitPointY: Double(unitPoint.y),
        offsetWidth: Double(offset.width),
        offsetHeight: Double(offset.height),
      )
    }
  }
}

private struct TesseraCanvasStaticRenderView: View {
  var configuration: TesseraConfiguration
  var canvasSize: CGSize
  var pinnedSymbols: [TesseraPinnedSymbol]
  var placedSymbolDescriptors: [ShapePlacementEngine.PlacedSymbolDescriptor]
  var edgeBehavior: TesseraEdgeBehavior

  var body: some View {
    let isCollisionOverlayEnabled = configuration.showsCollisionOverlay
    let overlayShapesBySymbolId: [UUID: CollisionOverlayShape] = isCollisionOverlayEnabled
      ? configuration.symbols.reduce(into: [:]) { cache, symbol in
        cache[symbol.id] = CollisionOverlayShape(collisionShape: symbol.collisionShape)
      }
      : [:]
    let overlayShapesByPinnedSymbolId: [UUID: CollisionOverlayShape] = isCollisionOverlayEnabled
      ? pinnedSymbols.reduce(into: [:]) { cache, symbol in
        cache[symbol.id] = CollisionOverlayShape(collisionShape: symbol.collisionShape)
      }
      : [:]

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

      for pinnedSymbol in pinnedSymbols {
        guard let symbol = context.resolveSymbol(id: pinnedSymbol.id) else { continue }

        let resolvedPosition = pinnedSymbol.resolvedPosition(in: size)

        for offset in offsets {
          var symbolContext = context
          symbolContext.translateBy(x: offset.width, y: offset.height)
          symbolContext.translateBy(x: resolvedPosition.x, y: resolvedPosition.y)
          symbolContext.rotate(by: pinnedSymbol.rotation)
          symbolContext.scaleBy(x: pinnedSymbol.scale, y: pinnedSymbol.scale)
          symbolContext.draw(symbol, at: .zero, anchor: .center)

          if isCollisionOverlayEnabled,
             let overlayShape = overlayShapesByPinnedSymbolId[pinnedSymbol.id] {
            CollisionOverlayRenderer.draw(overlayShape: overlayShape, in: &symbolContext)
          }
        }
      }

      for placedSymbol in placedSymbolDescriptors {
        guard let symbol = context.resolveSymbol(id: placedSymbol.symbolId) else { continue }

        for offset in offsets {
          var symbolContext = context
          symbolContext.translateBy(x: offset.width + wrappedOffset.width, y: offset.height + wrappedOffset.height)
          symbolContext.translateBy(x: placedSymbol.position.x, y: placedSymbol.position.y)
          symbolContext.rotate(by: .radians(placedSymbol.rotationRadians))
          symbolContext.scaleBy(x: placedSymbol.scale, y: placedSymbol.scale)
          symbolContext.draw(symbol, at: .zero, anchor: .center)

          if isCollisionOverlayEnabled,
             let overlayShape = overlayShapesBySymbolId[placedSymbol.symbolId] {
            CollisionOverlayRenderer.draw(overlayShape: overlayShape, in: &symbolContext)
          }
        }
      }
    } symbols: {
      ForEach(configuration.symbols) { symbol in
        symbol.makeView().tag(symbol.id)
      }
      ForEach(pinnedSymbols) { pinnedSymbol in
        pinnedSymbol.makeView().tag(pinnedSymbol.id)
      }
    }
    .frame(width: canvasSize.width, height: canvasSize.height)
    .clipped()
  }
}
