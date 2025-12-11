// By Dennis Müller

import SwiftUI
import Tessera

struct PatternStage: View {
  var tessera: Tessera
  @Binding var repeatPattern: Bool

  var body: some View {
    ZStack {
      patternContent
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .overlay(alignment: .topLeading) {
      controlBar
        .padding(.horizontal, .large)
        .padding(.top, .medium)
    }
    .animation(.smooth(duration: 0.28), value: repeatPattern)
    .animation(.smooth(duration: 0.28), value: tessera.items.count)
  }

  @ViewBuilder
  private var patternContent: some View {
    if tessera.items.isEmpty {
      emptyState
        .padding(.horizontal, .large)
        .transition(.opacity.combined(with: .scale(1.2)))
    } else if repeatPattern {
      TesseraPattern(tessera, seed: tessera.seed)
        .transition(.opacity)
    } else {
      tessera
        .padding(.large)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 22))
        .padding(.large)
        .transition(.opacity)
    }
  }

  private var controlBar: some View {
    HStack(spacing: .medium) {
      Toggle(isOn: $repeatPattern) {
        Label("Repeat", systemImage: "square.grid.3x3.fill")
      }
      .toggleStyle(.switch)
    }
    .padding(.horizontal, .mediumRelaxed)
    .padding(.vertical, .mediumTight)
    .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 15))
  }

  private var emptyState: some View {
    ContentUnavailableView {
      Label {
        Text("Add items to start tiling")
          .font(.title3.weight(.semibold))
      } icon: {
        Image(systemName: "sparkles")
          .symbolRenderingMode(.hierarchical)
      }
    } description: {
      Text("Add shapes, text, emojis and more to see your pattern come to life.")
        .multilineTextAlignment(.center)
    }
    .frame(maxWidth: 360)
  }
}

#Preview {
  PatternStage(
    tessera: Tessera(
      size: CGSize(width: 256, height: 256),
      items: EditableItem.demoItems.map { $0.makeTesseraItem() },
      seed: 0,
      minimumSpacing: 10,
      density: 0.8,
      baseScaleRange: 0.5...1.2,
    ),
    repeatPattern: .constant(true),
  )
  .frame(width: 360, height: 360)
}
