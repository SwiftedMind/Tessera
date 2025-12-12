// By Dennis Müller

import SwiftUI

struct InspectorExpandableCard<Header: View, ExpandedContent: View>: View {
  var isExpanded: Bool
  var isDimmed: Bool
  var dimmedOpacity: Double
  @ViewBuilder var header: () -> Header
  @ViewBuilder var expandedContent: () -> ExpandedContent

  init(
    isExpanded: Bool,
    isDimmed: Bool = false,
    dimmedOpacity: Double = 0.5,
    @ViewBuilder header: @escaping () -> Header,
    @ViewBuilder expandedContent: @escaping () -> ExpandedContent,
  ) {
    self.isExpanded = isExpanded
    self.isDimmed = isDimmed
    self.dimmedOpacity = dimmedOpacity
    self.header = header
    self.expandedContent = expandedContent
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      header()
      if isExpanded {
        expandedContent()
          .padding([.horizontal, .bottom], .mediumRelaxed)
          .transition(.opacity)
      }
    }
    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    .overlay(
      RoundedRectangle(cornerRadius: 14)
        .strokeBorder(.white.opacity(0.2)),
    )
    .clipShape(RoundedRectangle(cornerRadius: 14))
    .geometryGroup()
    .opacity(isDimmed ? dimmedOpacity : 1)
    .animation(.default, value: isExpanded)
  }
}
