// By Dennis Müller

import SwiftUI
import Tessera

struct PatternStage: View {
  @Environment(TesseraEditorModel.self) private var editor

  var configuration: TesseraConfiguration
  var tileSize: CGSize
  @Binding var isTiledCanvasEnabled: Bool

  var body: some View {
    ZStack {
      if let stageBackgroundColor = editor.stageBackgroundColor {
        stageBackgroundColor
          .ignoresSafeArea()
      }
      patternContent
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .overlay(alignment: .topLeading) {
      controlBar
        .padding(.horizontal, .large)
        .padding(.top, .medium)
    }
    .animation(.smooth(duration: 0.28), value: isTiledCanvasEnabled)
    .animation(.smooth(duration: 0.28), value: configuration.items.count)
  }

  @ViewBuilder
  private var patternContent: some View {
    if configuration.items.isEmpty {
      if editor.stageBackgroundColor != nil {
        emptyState
          .padding(.large)
          .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
          .padding(.horizontal, .large)
          .transition(.opacity.combined(with: .scale(1.2)))
      } else {
        emptyState
          .padding(.horizontal, .large)
          .transition(.opacity.combined(with: .scale(1.2)))
      }
    } else if isTiledCanvasEnabled {
      TesseraTiledCanvas(configuration, tileSize: tileSize)
        .transition(.opacity)
    } else {
      TesseraTile(configuration, tileSize: tileSize)
        .padding(.large)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 22))
        .padding(.large)
        .transition(.opacity)
    }
  }

  @ViewBuilder private var controlBar: some View {
    @Bindable var editor = editor

    HStack(spacing: .extraLarge) {
      Toggle(isOn: $isTiledCanvasEnabled) {
        Label("Tiled Canvas", systemImage: "square.grid.3x3.fill")
      }
      .toggleStyle(.switch)
      .help("Fill the stage by tiling the tile.")

      HStack(spacing: .medium) {
        Toggle(isOn: stageBackgroundEnabled) {
          Label("Background", systemImage: "paintpalette.fill")
        }
        .toggleStyle(.switch)

        if editor.stageBackgroundColor != nil {
          ColorPicker(
            "",
            selection: $editor.stageBackgroundColor.withDefault(.white),
            supportsOpacity: true,
          )
          .labelsHidden()
          .frame(width: 44)
        }
      }
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
      VStack(spacing: .medium) {
        Text("Add shapes, text, emojis and more to see your tiled canvas come to life.")
        Menu {
          ForEach(EditableItemTemplate.allTemplates) { template in
            Button {
              applyTemplate(template)
            } label: {
              Label(template.title, systemImage: template.iconName)
            }
            .help(template.description)
          }
        } label: {
          Label("Choose Template", systemImage: "square.grid.2x2")
        }
      }
      .multilineTextAlignment(.center)
    }
    .frame(maxWidth: 360)
  }

  private func applyTemplate(_ template: EditableItemTemplate) {
    editor.tesseraItems = template.items()
    let configuration = template.configuration

    if let minimumSpacing = configuration.minimumSpacing {
      editor.minimumSpacing = minimumSpacing
    }

    if let density = configuration.density {
      editor.density = density
    }

    if let baseScaleRange = configuration.baseScaleRange {
      editor.baseScaleRange = baseScaleRange
    }

    if let patternOffset = configuration.patternOffset {
      editor.patternOffset = patternOffset
    }

    if let seed = configuration.seed {
      editor.tesseraSeed = seed
    }

    editor.refreshLiveConfiguration()
  }

  private var stageBackgroundEnabled: Binding<Bool> {
    Binding(
      get: { editor.stageBackgroundColor != nil },
      set: { isEnabled in
        if isEnabled {
          if editor.stageBackgroundColor == nil {
            editor.stageBackgroundColor = .white
          }
        } else {
          editor.stageBackgroundColor = nil
        }
      },
    )
  }
}

private extension Binding where Value == Color? {
  func withDefault(_ defaultColor: Color) -> Binding<Color> {
    Binding<Color>(
      get: { wrappedValue ?? defaultColor },
      set: { newColor in
        wrappedValue = newColor
      },
    )
  }
}

#Preview {
  PatternStage(
    configuration: TesseraConfiguration(
      items: EditableItem.demoItems.map { $0.makeTesseraItem() },
      seed: 0,
      minimumSpacing: 10,
      density: 0.8,
      baseScaleRange: 0.5...1.2,
    ),
    tileSize: CGSize(width: 256, height: 256),
    isTiledCanvasEnabled: .constant(true),
  )
  .frame(width: 360, height: 360)
}
