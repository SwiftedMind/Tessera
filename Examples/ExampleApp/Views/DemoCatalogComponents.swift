// By Dennis Müller

import SwiftUI

struct CatalogIntroCard: View {
  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Demo Catalog")
        .font(.headline)
      Text("Browse examples by topic, then open any screen to inspect configuration behavior in isolation.")
        .font(.subheadline)
        .foregroundStyle(.secondary)
    }
  }
}

struct ExampleRow: View {
  let example: DemoCatalogExample

  var body: some View {
    HStack(alignment: .top, spacing: 12) {
      Image(systemName: example.systemImage)
        .font(.system(size: 16, weight: .semibold))
        .foregroundStyle(.primary)
        .frame(width: 34, height: 34)
        .background(
          RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(.primary.opacity(0.08)),
        )

      VStack(alignment: .leading, spacing: 4) {
        Text(example.title)
          .font(.headline)
        Text(example.summary)
          .font(.subheadline)
          .foregroundStyle(.secondary)
      }
    }
    .padding(.vertical, 4)
  }
}
