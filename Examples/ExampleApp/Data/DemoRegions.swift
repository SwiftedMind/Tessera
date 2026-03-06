// By Dennis Müller

import CoreGraphics
import Tessera

enum DemoRegions {
  static var mosaic: Region {
    Region.polygon([
      CGPoint(x: 24, y: 6), CGPoint(x: 120, y: 0), CGPoint(x: 188, y: 42), CGPoint(x: 200, y: 130),
      CGPoint(x: 150, y: 204), CGPoint(x: 70, y: 196), CGPoint(x: 0, y: 120),
    ])
  }
}
