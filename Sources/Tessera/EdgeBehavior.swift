// By Dennis Müller

/// Defines how Tessera treats pattern edges during placement and rendering.
public enum TesseraEdgeBehavior: Sendable {
  /// No wrapping. Symbols are clipped at the canvas bounds.
  case finite
  /// Toroidal wrapping like a tile, producing a seamlessly tileable result.
  case seamlessWrapping
}

/// Defines how Tessera renders constrained regions.
public enum TesseraRegionRendering: Sendable, Hashable {
  /// Clips drawing to the region.
  case clipped
  /// Draws symbols without clipping, while still constraining placement to the region.
  case unclipped
}
