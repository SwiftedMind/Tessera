// By Dennis Müller

import SwiftUI

struct SteeringLegendOverlay: View {
  var title: String
  var startLabel: String
  var endLabel: String
  var axisSymbol: String

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(title)
        .font(.caption.weight(.semibold))
      HStack(spacing: 6) {
        Image(systemName: axisSymbol)
          .font(.caption2.weight(.semibold))
        Text(startLabel)
          .font(.caption2)
      }
      Text(endLabel)
        .font(.caption2)
        .foregroundStyle(.secondary)
    }
    .padding(10)
    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    .padding(16)
  }
}
