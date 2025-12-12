// By Dennis Müller

import CoreText
import ImageIO
import SwiftUI
#if os(macOS)
import AppKit
#else
import UIKit
#endif

enum EditableItemPresetHelpers {
  /// Expands a rectangle's collision shape to account for stroke width.
  ///
  /// - Parameter style: Style providing the base size and stroke width.
  /// - Returns: A size adjusted for the stroke radius.
  static func rectangleCollisionSize(for style: ItemStyle) -> CGSize {
    CGSize(
      width: style.size.width + style.lineWidth,
      height: style.size.height + style.lineWidth,
    )
  }

  /// Calculates a circular collision radius that includes stroke width.
  ///
  /// - Parameter style: Style providing the base diameter and stroke width.
  /// - Returns: The radius used for collision detection.
  static func circleRadius(for style: ItemStyle) -> CGFloat {
    max(style.size.width, style.size.height) / 2 + style.lineWidth / 2
  }

  /// Extracts a corner radius from preset options, falling back when missing.
  ///
  /// - Parameters:
  ///   - options: Preset options that may include a corner radius.
  ///   - fallback: Default radius to use when no value is provided.
  /// - Returns: The corner radius applied to rounded shapes.
  static func cornerRadius(from options: PresetSpecificOptions, fallback: CGFloat) -> CGFloat {
    options.cornerRadius ?? fallback
  }

  /// Selects the system symbol name from preset options or a default.
  ///
  /// - Parameters:
  ///   - options: Preset options that may include a system symbol name.
  ///   - defaultSymbolName: Fallback symbol when none is provided.
  /// - Returns: The symbol name to render.
  static func symbolName(from options: PresetSpecificOptions, defaultSymbolName: String) -> String {
    options.systemSymbolName ?? defaultSymbolName
  }

  /// Selects the text content from preset options or a default placeholder.
  ///
  /// - Parameter options: Preset options that may include custom text content.
  /// - Returns: The text string to render.
  static func textContent(from options: PresetSpecificOptions) -> String {
    options.textContent ?? "Text"
  }

  /// Measures the rendered size of text content for a preset.
  ///
  /// - Parameters:
  ///   - style: Style providing font size and weight.
  ///   - options: Preset options that may include custom text content.
  /// - Returns: The measured size including a small padding buffer.
  static func measuredTextSize(for style: ItemStyle, options: PresetSpecificOptions) -> CGSize {
    let content = textContent(from: options)
    let font = NSFont.systemFont(ofSize: style.fontSize, weight: .semibold)

    let attributes: [NSAttributedString.Key: Any] = [.font: font]
    let attributedString = NSAttributedString(string: content, attributes: attributes)
    let line = CTLineCreateWithAttributedString(attributedString)

    let width = ceil(CTLineGetTypographicBounds(line, nil, nil, nil))

    let coreTextFont = CTFontCreateWithName(font.fontName as CFString, font.pointSize, nil)
    let ascent = CTFontGetAscent(coreTextFont)
    let descent = CTFontGetDescent(coreTextFont)
    let leading = CTFontGetLeading(coreTextFont)

    let height = ceil(ascent + descent + leading)
    let padding: CGFloat = 2

    return CGSize(width: width + padding, height: height + padding)
  }

  /// Loads an embedded image playground asset and wraps it in a SwiftUI Image.
  ///
  /// - Parameter options: Preset options that may include embedded image data.
  /// - Returns: A SwiftUI image when embedded data is available, otherwise `nil`.
  static func playgroundImage(from options: PresetSpecificOptions) -> Image? {
    guard let data = options.imagePlaygroundImageData else { return nil }

    #if os(macOS)
    guard let nsImage = NSImage(data: data) else { return nil }

    return Image(nsImage: nsImage)
    #else
    guard let uiImage = UIImage(data: data) else { return nil }

    return Image(uiImage: uiImage)
    #endif
  }

  /// Loads an embedded uploaded image asset and wraps it in a SwiftUI Image.
  ///
  /// - Parameter options: Preset options that may include embedded image data.
  /// - Returns: A SwiftUI image when embedded data is available, otherwise `nil`.
  static func uploadedImage(from options: PresetSpecificOptions) -> Image? {
    guard let data = options.uploadedImageData else { return nil }

    #if os(macOS)
    guard let nsImage = NSImage(data: data) else { return nil }

    return Image(nsImage: nsImage)
    #else
    guard let uiImage = UIImage(data: data) else { return nil }

    return Image(uiImage: uiImage)
    #endif
  }

  /// Calculates a rectangle collision size that matches the visible bounds of an aspect-fitted image.
  ///
  /// The image presets render their image into `style.size` using `aspectRatio(contentMode: .fit)`.
  /// When the image's aspect ratio does not match the container, SwiftUI letterboxes the image by
  /// leaving empty space on either the horizontal or vertical axis. Using the full container size
  /// for collision checks makes the item appear to reserve too much space.
  ///
  /// - Parameters:
  ///   - style: Style containing the image container size.
  ///   - options: Preset options that may carry embedded image data.
  /// - Returns: A collision size that follows the rendered image bounds when possible.
  static func aspectFittedImageCollisionSize(for style: ItemStyle, options: PresetSpecificOptions) -> CGSize {
    guard style.size.width > 0, style.size.height > 0 else { return style.size }

    let imageData = options.imagePlaygroundImageData ?? options.uploadedImageData
    guard let imageData, let imageAspectRatio = imageAspectRatio(from: imageData) else {
      return style.size
    }

    return aspectFitSize(containerSize: style.size, contentAspectRatio: imageAspectRatio)
  }

  private static func aspectFitSize(containerSize: CGSize, contentAspectRatio: CGFloat) -> CGSize {
    guard containerSize.width > 0, containerSize.height > 0 else { return .zero }
    guard contentAspectRatio.isFinite, contentAspectRatio > 0 else { return containerSize }

    let containerAspectRatio = containerSize.width / containerSize.height

    if contentAspectRatio > containerAspectRatio {
      let fittedHeight = containerSize.width / contentAspectRatio
      return CGSize(width: containerSize.width, height: fittedHeight)
    } else {
      let fittedWidth = containerSize.height * contentAspectRatio
      return CGSize(width: fittedWidth, height: containerSize.height)
    }
  }

  private static func imageAspectRatio(from imageData: Data) -> CGFloat? {
    let imageSourceOptions: [CFString: Any] = [
      kCGImageSourceShouldCache: false,
      kCGImageSourceShouldCacheImmediately: false,
    ]

    guard let imageSource = CGImageSourceCreateWithData(imageData as CFData, imageSourceOptions as CFDictionary) else {
      return nil
    }
    guard let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, imageSourceOptions as CFDictionary) as?
      [CFString: Any]
    else {
      return nil
    }
    guard let pixelWidthNumber = properties[kCGImagePropertyPixelWidth] as? NSNumber,
          let pixelHeightNumber = properties[kCGImagePropertyPixelHeight] as? NSNumber
    else {
      return nil
    }

    let pixelWidth = pixelWidthNumber.doubleValue
    let pixelHeight = pixelHeightNumber.doubleValue

    guard pixelWidth > 0, pixelHeight > 0 else { return nil }

    let orientation = (properties[kCGImagePropertyOrientation] as? NSNumber)?.intValue ?? 1
    let isRotatedByNinetyDegrees = [5, 6, 7, 8].contains(orientation)

    if isRotatedByNinetyDegrees {
      return CGFloat(pixelHeight / pixelWidth)
    }

    return CGFloat(pixelWidth / pixelHeight)
  }
}
