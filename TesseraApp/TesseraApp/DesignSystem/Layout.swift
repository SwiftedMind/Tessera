// By Dennis Müller

import SwiftUI

enum Layout {
  enum Spacing: CGFloat, CaseIterable {
    case extraSmall = 4
    case tight = 6
    case small = 8
    case mediumTight = 10
    case medium = 12
    case mediumRelaxed = 14
    case large = 16
    case extraLarge = 20

    var value: CGFloat { rawValue }
  }

  enum Padding: CGFloat, CaseIterable {
    case extraSmall = 4
    case tight = 6
    case small = 8
    case mediumTight = 10
    case medium = 12
    case mediumRelaxed = 14
    case large = 16
    case extraLarge = 20

    static var compact: Padding { .small }
    static var standard: Padding { .medium }
    static var roomy: Padding { .large }

    var value: CGFloat { rawValue }
  }
}

extension HStack {
  init(
    alignment: VerticalAlignment = .center,
    spacing layoutSpacing: Layout.Spacing,
    @ViewBuilder content: () -> Content,
  ) {
    self.init(alignment: alignment, spacing: layoutSpacing.value, content: content)
  }
}

extension VStack {
  init(
    alignment: HorizontalAlignment = .center,
    spacing layoutSpacing: Layout.Spacing,
    @ViewBuilder content: () -> Content,
  ) {
    self.init(alignment: alignment, spacing: layoutSpacing.value, content: content)
  }
}

extension View {
  func padding(_ layoutPadding: Layout.Padding) -> some View {
    padding(layoutPadding.value)
  }

  func padding(_ edges: Edge.Set = .all, _ layoutPadding: Layout.Padding) -> some View {
    padding(edges, layoutPadding.value)
  }
}
