// By Dennis Müller

import Foundation

/// Type-erased, sendable cache key for region rendering.
public struct TesseraRegionID: Hashable, @unchecked Sendable {
  private var rawValue: AnyHashable

  /// Creates a region cache key from any hashable, sendable value.
  public init(_ value: some Hashable & Sendable) {
    rawValue = AnyHashable(value)
  }
}

extension TesseraRegionID: ExpressibleByStringLiteral {
  /// Creates a region cache key from a string literal.
  public init(stringLiteral value: StringLiteralType) {
    self.init(value)
  }
}
