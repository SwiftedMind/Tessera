// By Dennis Müller

import Foundation

enum PatternMode: String, Codable, CaseIterable, Identifiable, Sendable {
  case tile
  case canvas

  var id: String { rawValue }
}
