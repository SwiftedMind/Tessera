// By Dennis Müller

import CoreGraphics
import Foundation
import SwiftUI

/// Lightweight, deterministic hasher used for snapshot fingerprints.
///
/// Unlike `Hasher`, this implementation is stable across process launches so persisted
/// snapshot fingerprints can be compared reliably.
struct DeterministicHasher {
  private var state: UInt64 = 0xCBF2_9CE4_8422_2325

  /// Mixes an unsigned 64-bit value into the hash state.
  mutating func combine(_ value: UInt64) {
    state ^= value
    state &*= 0x0000_0100_0000_01B3
  }

  /// Mixes an integer value into the hash state.
  mutating func combine(_ value: Int) {
    combine(UInt64(bitPattern: Int64(value)))
  }

  /// Mixes a boolean value into the hash state.
  mutating func combine(_ value: Bool) {
    combine(value ? 1 : 0)
  }

  /// Mixes a floating-point value into the hash state.
  mutating func combine(_ value: Double) {
    combine(value.bitPattern)
  }

  /// Mixes a Core Graphics floating-point value into the hash state.
  mutating func combine(_ value: CGFloat) {
    combine(Double(value))
  }

  /// Mixes a string into the hash state using UTF-8 bytes and an end marker.
  mutating func combine(_ value: String) {
    for byte in value.utf8 {
      combine(UInt64(byte))
    }
    combine(0xFF)
  }

  /// Mixes a UUID into the hash state.
  mutating func combine(_ value: UUID) {
    combine(value.uuidString)
  }

  /// Mixes a point value into the hash state.
  mutating func combine(_ value: CGPoint) {
    combine(value.x)
    combine(value.y)
  }

  /// Mixes a size value into the hash state.
  mutating func combine(_ value: CGSize) {
    combine(value.width)
    combine(value.height)
  }

  /// Mixes a unit-point value into the hash state.
  mutating func combine(_ value: UnitPoint) {
    combine(value.x)
    combine(value.y)
  }

  /// Mixes an ordered collection into the hash state.
  mutating func combineSequence<T>(_ values: [T], _ combineElement: (inout DeterministicHasher, T) -> Void) {
    combine(values.count)
    for value in values {
      combineElement(&self, value)
    }
  }

  /// Returns the finalized deterministic hash value.
  func finalize() -> UInt64 {
    state
  }
}
