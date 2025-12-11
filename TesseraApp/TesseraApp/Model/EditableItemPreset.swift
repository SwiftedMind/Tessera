// By Dennis Müller

import SwiftUI
import Tessera

extension EditableItem {
  /// Built-in editable item preset that carries display metadata and rendering logic.
  struct Preset: Identifiable, Equatable {
    var id: String
    var title: LocalizedStringKey
    var iconName: String
    var defaultStyle: ItemStyle
    var defaultSpecificOptions: PresetSpecificOptions
    var capabilities: PresetCapabilities
    var availableSymbols: [String]
    var defaultSymbolName: String
    var render: (ItemStyle, PresetSpecificOptions) -> AnyView
    var collisionShape: (ItemStyle, PresetSpecificOptions) -> CollisionShape
    var measuredSize: (ItemStyle, PresetSpecificOptions) -> CGSize
    
    static func == (lhs: Preset, rhs: Preset) -> Bool {
      lhs.id == rhs.id
    }

    /// Label used for the primary color control depending on stroke or fill usage.
    var colorLabel: LocalizedStringKey {
      switch capabilities.usesStrokeStyle {
      case true:
        "Stroke Color"
      case false:
        "Fill Color"
      }
    }

    /// Builds a preview using the preset's default style and options.
    @ViewBuilder
    func preview() -> some View {
      render(defaultStyle, defaultSpecificOptions)
    }

    /// Creates a tessera item using the preset's rendering and collision configuration.
    ///
    /// - Parameters:
    ///   - id: Unique identifier for the tessera item.
    ///   - weight: Weight applied when selecting items during generation.
    ///   - rotationRange: Allowed rotation range used when rotating the item.
    ///   - scaleRange: Optional scale range applied during placement.
    ///   - style: Style values to use when rendering the item.
    ///   - options: Preset-specific options such as symbol name or text content.
    /// - Returns: A tessera item ready for use in the generator.
    func makeItem(
      id: UUID,
      weight: Double,
      rotationRange: ClosedRange<Angle>,
      scaleRange: ClosedRange<Double>?,
      style: ItemStyle,
      options: PresetSpecificOptions,
    ) -> TesseraItem {
      TesseraItem(
        id: id,
        weight: weight,
        allowedRotationRange: rotationRange,
        scaleRange: scaleRange,
        collisionShape: collisionShape(style, options),
      ) {
        render(style, options)
      }
    }

    /// Measures the rendered size for the provided style and preset options.
    ///
    /// - Parameters:
    ///   - style: Style applied when rendering.
    ///   - options: Preset-specific options that can affect sizing.
    /// - Returns: The expected rendered size.
    func measuredSize(for style: ItemStyle, options: PresetSpecificOptions) -> CGSize {
      measuredSize(style, options)
    }
  }

  /// A logical grouping of presets used for menu organization.
  struct PresetGroup: Identifiable, Equatable {
    var id: String
    var title: LocalizedStringKey
    var iconName: String
    var presets: [Preset]

    static func == (lhs: PresetGroup, rhs: PresetGroup) -> Bool {
      lhs.id == rhs.id
    }
  }
}

// MARK: - Preset Definitions

extension EditableItem.Preset {
  /// All built-in preset groups available in the editor.
  static let allPresetGroups: [EditableItem.PresetGroup] = [
    .shapes,
    .symbols,
    .textual,
  ]

  /// All built-in presets available in the editor, flattened from groups.
  static let allPresets: [EditableItem.Preset] = allPresetGroups.flatMap(\.presets)

  /// Looks up a preset by its identifier.
  ///
  /// - Parameter id: Identifier of the preset to retrieve.
  /// - Returns: The matching preset or `nil` when none exists.
  static func preset(withID id: String) -> EditableItem.Preset? {
    allPresets.first(where: { $0.id == id })
  }

  /// Looks up the preset group that contains this preset.
  var group: EditableItem.PresetGroup? {
    Self.allPresetGroups.first(where: { group in
      group.presets.contains(where: { $0.id == id })
    })
  }

  /// Convenience accessor for the group's icon name.
  var groupIconName: String? {
    group?.iconName
  }
}

extension EditableItem {
  /// Flags indicating which styling controls a preset supports.
  struct PresetCapabilities: Equatable {
    var usesStrokeStyle: Bool
    var usesFillStyle: Bool
    var supportsLineWidth: Bool
    var supportsFontSize: Bool
    var supportsCornerRadius: Bool
    var supportsSymbolSelection: Bool
    var supportsTextContent: Bool
  }
}
