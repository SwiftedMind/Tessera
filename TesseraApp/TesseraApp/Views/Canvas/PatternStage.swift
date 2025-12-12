// By Dennis Müller

import SwiftUI
import Tessera

struct PatternStage: View {
  @Environment(TesseraEditorModel.self) private var editor

  var configuration: TesseraConfiguration
  var tileSize: CGSize
  var canvasSize: CGSize
  var fixedItems: [EditableFixedItem]
  var patternMode: PatternMode
  @Binding var isRepeatPreviewEnabled: Bool
  @State private var isRefreshOverlayVisible: Bool = false
  @State private var refreshDelayTask: Task<Void, Never>?

  var body: some View {
    ZStack {
      if let stageBackgroundColor = editor.stageBackgroundColor {
        stageBackgroundColor
          .ignoresSafeArea()
      }
      patternContent
      if isRefreshOverlayVisible {
        refreshingOverlay
          .transition(.opacity.combined(with: .scale(0.9)))
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .overlay(alignment: .topLeading) {
      controlBar
        .padding(.horizontal, .large)
        .padding(.top, .medium)
    }
    .animation(.smooth(duration: 0.28), value: isRepeatPreviewEnabled)
    .animation(.smooth(duration: 0.28), value: patternMode)
    .animation(.smooth(duration: 0.28), value: configuration.items.count)
    .animation(.smooth(duration: 0.2), value: isRefreshOverlayVisible)
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
    } else {
      switch patternMode {
      case .tile:
        if isRepeatPreviewEnabled {
          TesseraTiledCanvas(
            configuration,
            tileSize: tileSize,
            onComputationStateChange: handleComputationStateChange,
          )
          .transition(.opacity)
        } else {
          TesseraTile(
            configuration,
            tileSize: tileSize,
            onComputationStateChange: handleComputationStateChange,
          )
          .padding(.large)
          .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 22))
          .padding(.large)
          .transition(.opacity)
        }
      case .canvas:
        canvasPreview
          .transition(.opacity)
      }
    }
  }

  @ViewBuilder private var controlBar: some View {
    @Bindable var editor = editor

    HStack(spacing: .extraLarge) {
      if patternMode == .tile {
        Toggle(isOn: $isRepeatPreviewEnabled) {
          Label("Repeat Preview", systemImage: "square.grid.3x3.fill")
        }
        .toggleStyle(.switch)
        .help("Fill the stage by repeating the tile.")
      }

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
        Text(patternMode == .tile ? "Add items to start tiling" : "Add items to start filling the canvas")
          .font(.title3.weight(.semibold))
      } icon: {
        Image(systemName: "sparkles")
          .symbolRenderingMode(.hierarchical)
      }
    } description: {
      VStack(spacing: .medium) {
        Text(
          patternMode == .tile
            ? "Add shapes, text, emojis and more to see your tiled canvas come to life."
            : "Add shapes, text, emojis and more to see your canvas pattern come to life.",
        )
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

  private var canvasPreview: some View {
    let visibleFixedItems = fixedItems.filter(\.isVisible).map { $0.makeTesseraFixedItem() }
    let borderShape = RoundedRectangle(cornerRadius: 22, style: .continuous)

    return GeometryReader { proxy in
      let availableSize = proxy.size
      let horizontalScale = availableSize.width / max(canvasSize.width, 1)
      let verticalScale = availableSize.height / max(canvasSize.height, 1)
      let fittedScale = min(min(horizontalScale, verticalScale), 1)
      let scaledSize = CGSize(width: canvasSize.width * fittedScale, height: canvasSize.height * fittedScale)

      TesseraCanvas(
        configuration,
        fixedItems: visibleFixedItems,
        onComputationStateChange: handleComputationStateChange,
      )
      .frame(width: canvasSize.width, height: canvasSize.height)
      .background(.thinMaterial, in: borderShape)
      .overlay(borderShape.stroke(.white.opacity(0.25)))
      .scaleEffect(fittedScale)
      .frame(width: scaledSize.width, height: scaledSize.height)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
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

  private var refreshingOverlay: some View {
    HStack(spacing: .medium) {
      ProgressView()
        .progressViewStyle(.circular)
      Text("Refreshing...")
        .font(.headline)
    }
    .padding(.mediumRelaxed)
    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    .overlay(
      RoundedRectangle(cornerRadius: 14, style: .continuous)
        .strokeBorder(.white.opacity(0.2)),
    )
    .shadow(radius: 12)
  }

  private func handleComputationStateChange(_ isActive: Bool) {
    if isActive {
      refreshDelayTask?.cancel()
      refreshDelayTask = Task { @MainActor in
        do {
          try await Task.sleep(for: .seconds(1))
        } catch {
          return
        }
        guard Task.isCancelled == false else { return }

        isRefreshOverlayVisible = true
      }
    } else {
      refreshDelayTask?.cancel()
      refreshDelayTask = nil
      isRefreshOverlayVisible = false
    }
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
    canvasSize: CGSize(width: 1024, height: 1024),
    fixedItems: [],
    patternMode: .tile,
    isRepeatPreviewEnabled: .constant(true),
  )
  .frame(width: 360, height: 360)
}
