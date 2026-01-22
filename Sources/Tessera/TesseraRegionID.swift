// By Dennis Müller

import Foundation

/// Type-erased, sendable cache key for region rendering.
public struct TesseraRegionID: Hashable, @unchecked Sendable {
  private var rawValue: AnyHashable

  public init(_ value: some Hashable & Sendable) {
    rawValue = AnyHashable(value)
  }
}

extension TesseraRegionID: ExpressibleByStringLiteral {
  public init(stringLiteral value: StringLiteralType) {
    self.init(value)
  }
}
