// By Dennis Müller

import SwiftUI
import Tessera

struct EditableItemTemplate: Identifiable {
  var id: String
  var title: LocalizedStringKey
  var iconName: String
  var description: LocalizedStringKey
  var configuration: TemplateConfiguration
  var makeItems: () -> [EditableItem]

  func items() -> [EditableItem] {
    makeItems()
  }

  struct TemplateConfiguration {
    var minimumSpacing: CGFloat?
    var density: Double?
    var baseScaleRange: ClosedRange<Double>?
    var patternOffset: CGSize?
    var seed: UInt64?
  }
}

extension EditableItemTemplate {
  static var allTemplates: [EditableItemTemplate] {
    [
      .random,
      .emojiPicnic,
      .geometricGlow,
      .typeSpecimen,
    ]
  }

  static var random: EditableItemTemplate {
    let builder = RandomTemplateBuilder()

    return EditableItemTemplate(
      id: "random",
      title: "Random",
      iconName: "die.face.5.fill",
      description: "Creates a fresh mix of shapes, symbols, and emoji every time.",
      configuration: builder.makeConfiguration(),
      makeItems: {
        builder.makeItems()
      },
    )
  }

  static var emojiPicnic: EditableItemTemplate {
    EditableItemTemplate(
      id: "emojiPicnic",
      title: "Emoji Picnic",
      iconName: "face.smiling",
      description: "Citrus, berries, and leaves for a sunny blanket vibe.",
      configuration: TemplateConfiguration(
        minimumSpacing: 12,
        density: 0.72,
        baseScaleRange: 0.88...1.22,
        patternOffset: .zero,
        seed: 42,
      ),
      makeItems: {
        [
          EditableItem(
            customName: "Lemon Slice",
            preset: .text,
            weight: 1.2,
            minimumRotation: -10,
            maximumRotation: 10,
            usesCustomScaleRange: true,
            minimumScale: 0.9,
            maximumScale: 1.25,
            style: ItemStyle(
              size: CGSize(width: 38, height: 38),
              color: .primary,
              lineWidth: 1,
              fontSize: 36,
            ),
            specificOptions: .text(content: "🍋"),
          ),
          EditableItem(
            customName: "Strawberry",
            preset: .text,
            weight: 1,
            minimumRotation: -12,
            maximumRotation: 12,
            usesCustomScaleRange: true,
            minimumScale: 0.92,
            maximumScale: 1.18,
            style: ItemStyle(
              size: CGSize(width: 36, height: 36),
              color: .primary,
              lineWidth: 1,
              fontSize: 34,
            ),
            specificOptions: .text(content: "🍓"),
          ),
          EditableItem(
            customName: "Blueberry",
            preset: .text,
            weight: 0.9,
            minimumRotation: -8,
            maximumRotation: 8,
            usesCustomScaleRange: true,
            minimumScale: 0.85,
            maximumScale: 1.15,
            style: ItemStyle(
              size: CGSize(width: 34, height: 34),
              color: .primary,
              lineWidth: 1,
              fontSize: 32,
            ),
            specificOptions: .text(content: "🫐"),
          ),
          EditableItem(
            customName: "Leaf",
            preset: .text,
            weight: 0.8,
            minimumRotation: -14,
            maximumRotation: 14,
            usesCustomScaleRange: true,
            minimumScale: 0.9,
            maximumScale: 1.2,
            style: ItemStyle(
              size: CGSize(width: 32, height: 32),
              color: .primary,
              lineWidth: 1,
              fontSize: 30,
            ),
            specificOptions: .text(content: "🌿"),
          ),
          EditableItem(
            customName: "Sparkle",
            preset: .text,
            weight: 0.6,
            minimumRotation: -6,
            maximumRotation: 6,
            usesCustomScaleRange: true,
            minimumScale: 0.85,
            maximumScale: 1.1,
            style: ItemStyle(
              size: CGSize(width: 30, height: 30),
              color: .primary,
              lineWidth: 1,
              fontSize: 28,
            ),
            specificOptions: .text(content: "✨"),
          ),
        ]
      },
    )
  }

  static var geometricGlow: EditableItemTemplate {
    EditableItemTemplate(
      id: "geometricGlow",
      title: "Geometric Glow",
      iconName: "hexagon",
      description: "Pastel shapes with a soft neon accent line.",
      configuration: TemplateConfiguration(
        minimumSpacing: 10,
        density: 0.78,
        baseScaleRange: 0.9...1.18,
        patternOffset: CGSize(width: 6, height: -4),
        seed: 88,
      ),
      makeItems: {
        [
          EditableItem(
            customName: "Glow Hexagon",
            preset: .hexagonFill,
            weight: 1.1,
            minimumRotation: -10,
            maximumRotation: 10,
            usesCustomScaleRange: true,
            minimumScale: 0.85,
            maximumScale: 1.15,
            style: ItemStyle(
              size: CGSize(width: 48, height: 48),
              color: .teal.opacity(0.7),
              lineWidth: 1,
              fontSize: 24,
            ),
          ),
          EditableItem(
            customName: "Rounded Frame",
            preset: .roundedOutline,
            weight: 0.95,
            minimumRotation: -18,
            maximumRotation: 18,
            usesCustomScaleRange: true,
            minimumScale: 0.9,
            maximumScale: 1.1,
            style: ItemStyle(
              size: CGSize(width: 46, height: 46),
              color: .mint.opacity(0.75),
              lineWidth: 3,
              fontSize: 26,
            ),
            specificOptions: .roundedRectangle(cornerRadius: 10),
          ),
          EditableItem(
            customName: "Neon Wave",
            preset: .wavyLine,
            weight: 0.9,
            minimumRotation: -36,
            maximumRotation: 36,
            usesCustomScaleRange: true,
            minimumScale: 0.9,
            maximumScale: 1.2,
            style: ItemStyle(
              size: CGSize(width: 64, height: 24),
              color: .pink.opacity(0.65),
              lineWidth: 3,
              fontSize: 22,
            ),
          ),
          EditableItem(
            customName: "Accent Dot",
            preset: .dotFill,
            weight: 0.7,
            minimumRotation: 0,
            maximumRotation: 0,
            usesCustomScaleRange: true,
            minimumScale: 0.8,
            maximumScale: 1.2,
            style: ItemStyle(
              size: CGSize(width: 12, height: 12),
              color: .orange.opacity(0.85),
              lineWidth: 1,
              fontSize: 14,
            ),
          ),
          EditableItem(
            customName: "Arc Highlight",
            preset: .arcStroke,
            weight: 0.75,
            minimumRotation: -28,
            maximumRotation: 28,
            usesCustomScaleRange: true,
            minimumScale: 0.85,
            maximumScale: 1.1,
            style: ItemStyle(
              size: CGSize(width: 54, height: 20),
              color: .yellow.opacity(0.8),
              lineWidth: 3,
              fontSize: 20,
            ),
          ),
        ]
      },
    )
  }

  static var typeSpecimen: EditableItemTemplate {
    EditableItemTemplate(
      id: "typeSpecimen",
      title: "Type Specimen",
      iconName: "textformat.alt",
      description: "Bold, condensed words with a few rhythmic marks.",
      configuration: TemplateConfiguration(
        minimumSpacing: 16,
        density: 0.6,
        baseScaleRange: 0.95...1.08,
        patternOffset: CGSize(width: -4, height: 6),
        seed: 104,
      ),
      makeItems: {
        [
          EditableItem(
            customName: "Play Word",
            preset: .text,
            weight: 1.1,
            minimumRotation: -6,
            maximumRotation: 6,
            usesCustomScaleRange: true,
            minimumScale: 0.95,
            maximumScale: 1.15,
            style: ItemStyle(
              size: CGSize(width: 60, height: 30),
              color: .primary,
              lineWidth: 1,
              fontSize: 34,
            ),
            specificOptions: .text(content: "PLAY"),
          ),
          EditableItem(
            customName: "Move Word",
            preset: .text,
            weight: 1,
            minimumRotation: -8,
            maximumRotation: 8,
            usesCustomScaleRange: true,
            minimumScale: 0.95,
            maximumScale: 1.12,
            style: ItemStyle(
              size: CGSize(width: 58, height: 30),
              color: .orange.opacity(0.85),
              lineWidth: 1,
              fontSize: 32,
            ),
            specificOptions: .text(content: "MOVE"),
          ),
          EditableItem(
            customName: "Echo Word",
            preset: .text,
            weight: 0.95,
            minimumRotation: -10,
            maximumRotation: 10,
            usesCustomScaleRange: true,
            minimumScale: 0.92,
            maximumScale: 1.1,
            style: ItemStyle(
              size: CGSize(width: 62, height: 30),
              color: .indigo.opacity(0.9),
              lineWidth: 1,
              fontSize: 34,
            ),
            specificOptions: .text(content: "ECHO"),
          ),
          EditableItem(
            customName: "Dash Mark",
            preset: .text,
            weight: 0.7,
            minimumRotation: -6,
            maximumRotation: 6,
            usesCustomScaleRange: true,
            minimumScale: 0.9,
            maximumScale: 1.05,
            style: ItemStyle(
              size: CGSize(width: 44, height: 6),
              color: .gray.opacity(0.65),
              lineWidth: 1,
              fontSize: 30,
            ),
            specificOptions: PresetSpecificOptions.text(content: "-"),
          ),
          EditableItem(
            customName: "Equals Mark",
            preset: .text,
            weight: 0.65,
            minimumRotation: -6,
            maximumRotation: 6,
            usesCustomScaleRange: true,
            minimumScale: 0.9,
            maximumScale: 1.05,
            style: ItemStyle(
              size: CGSize(width: 44, height: 12),
              color: .gray.opacity(0.75),
              lineWidth: 1,
              fontSize: 30,
            ),
            specificOptions: PresetSpecificOptions.text(content: "="),
          ),
        ]
      },
    )
  }
}
