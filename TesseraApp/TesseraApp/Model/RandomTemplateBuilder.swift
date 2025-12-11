// By Dennis Müller

import SwiftUI
import Tessera

struct RandomTemplateBuilder {
  private let seed: UInt64

  init(seed: UInt64 = Tessera.randomSeed()) {
    self.seed = seed
  }

  func makeConfiguration() -> EditableItemTemplate.TemplateConfiguration {
    var randomGenerator = SeededLinearGenerator(state: seed)

    return EditableItemTemplate.TemplateConfiguration(
      minimumSpacing: randomSpacing(using: &randomGenerator),
      density: randomDensity(using: &randomGenerator),
      baseScaleRange: randomScaleRange(using: &randomGenerator),
      patternOffset: randomPatternOffset(using: &randomGenerator),
      seed: seed,
    )
  }

  func makeItems() -> [EditableItem] {
    var randomGenerator = SeededLinearGenerator(state: seed)
    let palette = randomPalette(using: &randomGenerator)

    let itemFactories: [(inout SeededLinearGenerator, ColorPalette) -> EditableItem] = [
      makeSymbolItem(randomGenerator:palette:),
      makeEmojiItem(randomGenerator:palette:),
      makeWaveItem(randomGenerator:palette:),
      makeDotItem(randomGenerator:palette:),
      makeRoundedFrameItem(randomGenerator:palette:),
      makeHexagonItem(randomGenerator:palette:),
      makeTextTagItem(randomGenerator:palette:),
    ]

    let shuffledFactories = shuffled(itemFactories, using: &randomGenerator)
    let itemCount = randomInteger(in: 5...7, using: &randomGenerator)

    return Array(shuffledFactories.prefix(itemCount)).map { factory in
      factory(&randomGenerator, palette)
    }
  }

  private func makeSymbolItem(
    randomGenerator: inout SeededLinearGenerator,
    palette: ColorPalette,
  ) -> EditableItem {
    let symbolPreset = EditableItem.Preset.symbol
    let symbolName = randomElement(symbolPreset.availableSymbols, using: &randomGenerator)

    let sizeValue = randomCGFloat(in: 32.0...52.0, using: &randomGenerator)
    let weightValue = randomDouble(in: 0.9...1.25, using: &randomGenerator)
    let rotationLimit = randomDouble(in: 10.0...40.0, using: &randomGenerator)

    return EditableItem(
      customName: "Symbol",
      preset: symbolPreset,
      weight: weightValue,
      minimumRotation: -rotationLimit,
      maximumRotation: rotationLimit,
      usesCustomScaleRange: true,
      minimumScale: randomCGFloat(in: 0.85...1.0, using: &randomGenerator),
      maximumScale: randomCGFloat(in: 1.05...1.3, using: &randomGenerator),
      style: ItemStyle(
        size: CGSize(width: sizeValue, height: sizeValue),
        color: palette.accent.opacity(randomDouble(in: 0.65...1.0, using: &randomGenerator)),
        lineWidth: 2,
        fontSize: sizeValue,
      ),
      specificOptions: .systemSymbol(name: symbolName),
    )
  }

  private func makeEmojiItem(
    randomGenerator: inout SeededLinearGenerator,
    palette: ColorPalette,
  ) -> EditableItem {
    let emojiOptions = ["😀", "🌀", "🌟", "🌿", "🍉", "💠", "⚡️", "✨", "🌈", "🍒"]
    let emojiContent = randomElement(emojiOptions, using: &randomGenerator)
    let sizeValue = randomCGFloat(in: 36.0...52.0, using: &randomGenerator)
    let weightValue = randomDouble(in: 0.7...1.05, using: &randomGenerator)
    let rotationLimit = randomDouble(in: 6.0...18.0, using: &randomGenerator)

    return EditableItem(
      customName: "Emoji",
      preset: .emoji,
      weight: weightValue,
      minimumRotation: -rotationLimit,
      maximumRotation: rotationLimit,
      usesCustomScaleRange: true,
      minimumScale: randomCGFloat(in: 0.92...1.0, using: &randomGenerator),
      maximumScale: randomCGFloat(in: 1.05...1.2, using: &randomGenerator),
      style: ItemStyle(
        size: CGSize(width: sizeValue, height: sizeValue),
        color: palette.primary,
        lineWidth: 0,
        fontSize: sizeValue,
      ),
      specificOptions: .text(content: emojiContent),
    )
  }

  private func makeWaveItem(
    randomGenerator: inout SeededLinearGenerator,
    palette: ColorPalette,
  ) -> EditableItem {
    let widthValue = randomCGFloat(in: 58.0...96.0, using: &randomGenerator)
    let heightValue = randomCGFloat(in: 18.0...28.0, using: &randomGenerator)
    let weightValue = randomDouble(in: 0.8...1.1, using: &randomGenerator)
    let rotationLimit = randomDouble(in: 24.0...48.0, using: &randomGenerator)

    return EditableItem(
      customName: "Wave Line",
      preset: .wavyLine,
      weight: weightValue,
      minimumRotation: -rotationLimit,
      maximumRotation: rotationLimit,
      usesCustomScaleRange: true,
      minimumScale: randomCGFloat(in: 0.9...1.0, using: &randomGenerator),
      maximumScale: randomCGFloat(in: 1.05...1.25, using: &randomGenerator),
      style: ItemStyle(
        size: CGSize(width: widthValue, height: heightValue),
        color: palette.secondary.opacity(0.75),
        lineWidth: randomCGFloat(in: 2...4, using: &randomGenerator),
        fontSize: 22,
      ),
    )
  }

  private func makeDotItem(
    randomGenerator: inout SeededLinearGenerator,
    palette: ColorPalette,
  ) -> EditableItem {
    let diameter = randomCGFloat(in: 10.0...22.0, using: &randomGenerator)

    return EditableItem(
      customName: "Accent Dot",
      preset: .dotFill,
      weight: randomDouble(in: 0.65...0.95, using: &randomGenerator),
      minimumRotation: 0,
      maximumRotation: 0,
      usesCustomScaleRange: true,
      minimumScale: randomCGFloat(in: 0.8...1.0, using: &randomGenerator),
      maximumScale: randomCGFloat(in: 1.0...1.4, using: &randomGenerator),
      style: ItemStyle(
        size: CGSize(width: diameter, height: diameter),
        color: palette.accent.opacity(randomDouble(in: 0.7...1.0, using: &randomGenerator)),
        lineWidth: 1,
        fontSize: 16,
      ),
    )
  }

  private func makeRoundedFrameItem(
    randomGenerator: inout SeededLinearGenerator,
    palette: ColorPalette,
  ) -> EditableItem {
    let sideLength = randomCGFloat(in: 32.0...58.0, using: &randomGenerator)
    let rotationLimit = randomDouble(in: 10.0...28.0, using: &randomGenerator)

    return EditableItem(
      customName: "Rounded Frame",
      preset: .roundedOutline,
      weight: randomDouble(in: 0.85...1.1, using: &randomGenerator),
      minimumRotation: -rotationLimit,
      maximumRotation: rotationLimit,
      usesCustomScaleRange: true,
      minimumScale: randomCGFloat(in: 0.88...1.0, using: &randomGenerator),
      maximumScale: randomCGFloat(in: 1.05...1.2, using: &randomGenerator),
      style: ItemStyle(
        size: CGSize(width: sideLength, height: sideLength),
        color: palette.neutral.opacity(randomDouble(in: 0.55...0.9, using: &randomGenerator)),
        lineWidth: randomCGFloat(in: 2...4, using: &randomGenerator),
        fontSize: 24,
      ),
      specificOptions: .roundedRectangle(cornerRadius: randomCGFloat(in: 8...16, using: &randomGenerator)),
    )
  }

  private func makeHexagonItem(
    randomGenerator: inout SeededLinearGenerator,
    palette: ColorPalette,
  ) -> EditableItem {
    let sizeValue = randomCGFloat(in: 30.0...52.0, using: &randomGenerator)
    let rotationLimit = randomDouble(in: 6.0...22.0, using: &randomGenerator)

    return EditableItem(
      customName: "Hexagon",
      preset: .hexagonFill,
      weight: randomDouble(in: 0.8...1.1, using: &randomGenerator),
      minimumRotation: -rotationLimit,
      maximumRotation: rotationLimit,
      usesCustomScaleRange: true,
      minimumScale: randomCGFloat(in: 0.85...1.0, using: &randomGenerator),
      maximumScale: randomCGFloat(in: 1.05...1.25, using: &randomGenerator),
      style: ItemStyle(
        size: CGSize(width: sizeValue, height: sizeValue),
        color: palette.primary.opacity(randomDouble(in: 0.65...1.0, using: &randomGenerator)),
        lineWidth: 1,
        fontSize: 24,
      ),
    )
  }

  private func makeTextTagItem(
    randomGenerator: inout SeededLinearGenerator,
    palette: ColorPalette,
  ) -> EditableItem {
    let words = ["LOOP", "FLOW", "MOVE", "PLAY", "SHIFT", "WAVE"]
    let content = randomElement(words, using: &randomGenerator)
    let widthValue = randomCGFloat(in: 48.0...72.0, using: &randomGenerator)
    let heightValue = randomCGFloat(in: 20.0...30.0, using: &randomGenerator)
    let rotationLimit = randomDouble(in: 6.0...16.0, using: &randomGenerator)

    return EditableItem(
      customName: "Text Tag",
      preset: .text,
      weight: randomDouble(in: 0.7...1.0, using: &randomGenerator),
      minimumRotation: -rotationLimit,
      maximumRotation: rotationLimit,
      usesCustomScaleRange: true,
      minimumScale: randomCGFloat(in: 0.9...1.0, using: &randomGenerator),
      maximumScale: randomCGFloat(in: 1.05...1.15, using: &randomGenerator),
      style: ItemStyle(
        size: CGSize(width: widthValue, height: heightValue),
        color: palette.neutral.opacity(randomDouble(in: 0.7...1.0, using: &randomGenerator)),
        lineWidth: 1,
        fontSize: randomCGFloat(in: 26...34, using: &randomGenerator),
      ),
      specificOptions: .text(content: content),
    )
  }

  // MARK: - Random Helpers

  private func randomSpacing(using randomGenerator: inout SeededLinearGenerator) -> CGFloat {
    randomCGFloat(in: 10.0...16.0, using: &randomGenerator)
  }

  private func randomDensity(using randomGenerator: inout SeededLinearGenerator) -> Double {
    randomDouble(in: 0.62...0.88, using: &randomGenerator)
  }

  private func randomScaleRange(using randomGenerator: inout SeededLinearGenerator) -> ClosedRange<Double> {
    let minimum = randomDouble(in: 0.78...0.95, using: &randomGenerator)
    let upperCandidate = randomDouble(in: 1.1...1.32, using: &randomGenerator)
    return minimum...max(minimum + 0.12, upperCandidate)
  }

  private func randomPatternOffset(using randomGenerator: inout SeededLinearGenerator) -> CGSize {
    let horizontal = randomDouble(in: -12.0...12.0, using: &randomGenerator)
    let vertical = randomDouble(in: -12.0...12.0, using: &randomGenerator)
    return CGSize(width: horizontal, height: vertical)
  }

  private func randomPalette(using randomGenerator: inout SeededLinearGenerator) -> ColorPalette {
    let palettes = ColorPalette.library
    return randomElement(palettes, using: &randomGenerator)
  }

  private func randomDouble(in range: ClosedRange<Double>,
                            using randomGenerator: inout SeededLinearGenerator) -> Double {
    let nextValue = Double(randomGenerator.next()) / Double(UInt64.max)
    return range.lowerBound + (range.upperBound - range.lowerBound) * nextValue
  }

  private func randomCGFloat(in range: ClosedRange<Double>,
                             using randomGenerator: inout SeededLinearGenerator) -> CGFloat {
    CGFloat(randomDouble(in: range, using: &randomGenerator))
  }

  private func randomInteger(in range: ClosedRange<Int>, using randomGenerator: inout SeededLinearGenerator) -> Int {
    let distance = range.upperBound - range.lowerBound + 1
    let next = Int(randomGenerator.next() % UInt64(distance))
    return range.lowerBound + next
  }

  private func randomElement<T>(_ collection: [T], using randomGenerator: inout SeededLinearGenerator) -> T {
    let index = randomInteger(in: 0...(collection.count - 1), using: &randomGenerator)
    return collection[index]
  }

  private func shuffled<T>(_ collection: [T], using randomGenerator: inout SeededLinearGenerator) -> [T] {
    var result = collection
    for index in result.indices.reversed() {
      let targetIndex = randomInteger(in: 0...index, using: &randomGenerator)
      result.swapAt(index, targetIndex)
    }
    return result
  }
}

private struct ColorPalette {
  var primary: Color
  var secondary: Color
  var accent: Color
  var neutral: Color

  static let library: [ColorPalette] = [
    ColorPalette(
      primary: .pink,
      secondary: .orange,
      accent: .yellow,
      neutral: .gray,
    ),
    ColorPalette(
      primary: .mint,
      secondary: .teal,
      accent: .cyan,
      neutral: .gray.opacity(0.7),
    ),
    ColorPalette(
      primary: .indigo,
      secondary: .blue,
      accent: .purple,
      neutral: .primary,
    ),
    ColorPalette(
      primary: .green,
      secondary: .yellow,
      accent: .orange,
      neutral: .brown.opacity(0.8),
    ),
  ]
}

private struct SeededLinearGenerator: RandomNumberGenerator {
  private var state: UInt64

  init(state: UInt64) {
    self.state = state
  }

  mutating func next() -> UInt64 {
    state = 6_364_136_223_846_793_005 &* state &+ 1
    return state
  }
}
