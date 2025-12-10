// By Dennis Müller

import SwiftUI
import Tessera

struct EditableItem: Identifiable, Equatable {
  var id: UUID
  var preset: Preset
  var weight: Double
  var minimumRotation: Double
  var maximumRotation: Double
  var usesCustomScaleRange: Bool
  var minimumScale: CGFloat
  var maximumScale: CGFloat

  init(
    id: UUID = UUID(),
    preset: Preset,
    weight: Double = 1,
    minimumRotation: Double = 0,
    maximumRotation: Double = 360,
    usesCustomScaleRange: Bool = false,
    minimumScale: CGFloat = 0.6,
    maximumScale: CGFloat = 1.2,
  ) {
    self.id = id
    self.preset = preset
    self.weight = weight
    self.minimumRotation = minimumRotation
    self.maximumRotation = maximumRotation
    self.usesCustomScaleRange = usesCustomScaleRange
    self.minimumScale = minimumScale
    self.maximumScale = maximumScale
  }

  var rotationRange: ClosedRange<Angle> {
    Angle.degrees(minimumRotation)...Angle.degrees(maximumRotation)
  }

  var scaleRange: ClosedRange<Double>? {
    guard usesCustomScaleRange else { return nil }

    return minimumScale...maximumScale
  }

  func makeTesseraItem() -> TesseraItem {
    preset.makeItem(
      id: id,
      weight: weight,
      rotationRange: rotationRange,
      scaleRange: scaleRange,
    )
  }
}

extension EditableItem {
  static var demoItems: [EditableItem] {
    [
      EditableItem(preset: .squareOutline),
      EditableItem(preset: .roundedOutline, weight: 0.9),
      EditableItem(preset: .partyPopper, weight: 1.2, minimumRotation: -40, maximumRotation: 40),
      EditableItem(preset: .minus, weight: 0.8, minimumRotation: -20, maximumRotation: 20),
      EditableItem(preset: .equals, weight: 0.8, minimumRotation: -15, maximumRotation: 15),
      EditableItem(preset: .circleOutline, weight: 0.7),
    ]
  }
}

extension EditableItem {
  enum Preset: String, CaseIterable, Identifiable {
    case squareOutline
    case roundedOutline
    case partyPopper
    case minus
    case equals
    case circleOutline

    var id: String { rawValue }

    var title: String {
      switch self {
      case .squareOutline: "Square Outline"
      case .roundedOutline: "Rounded Outline"
      case .partyPopper: "Party Popper"
      case .minus: "Minus"
      case .equals: "Equals"
      case .circleOutline: "Circle Outline"
      }
    }

    var iconName: String {
      switch self {
      case .squareOutline: "square.dashed"
      case .roundedOutline: "app"
      case .partyPopper: "party.popper.fill"
      case .minus: "minus"
      case .equals: "equal"
      case .circleOutline: "circle"
      }
    }

    @ViewBuilder var preview: some View {
      switch self {
      case .squareOutline:
        Rectangle()
          .stroke(lineWidth: 4)
          .foregroundStyle(.gray.opacity(0.8))
      case .roundedOutline:
        RoundedRectangle(cornerRadius: 6)
          .stroke(lineWidth: 4)
      case .partyPopper:
        Image(systemName: "party.popper.fill")
          .foregroundStyle(.red.opacity(0.5))
          .font(.largeTitle)
      case .minus:
        Text("-")
          .foregroundStyle(.gray)
          .font(.largeTitle)
      case .equals:
        Text("=")
          .foregroundStyle(.gray)
          .font(.largeTitle)
      case .circleOutline:
        Circle()
          .stroke(lineWidth: 4)
          .foregroundStyle(.gray.opacity(0.2))
      }
    }

    func makeItem(
      id: UUID,
      weight: Double,
      rotationRange: ClosedRange<Angle>,
      scaleRange: ClosedRange<Double>?,
    ) -> TesseraItem {
      switch self {
      case .squareOutline:
        TesseraItem(
          id: id,
          weight: weight,
          allowedRotationRange: rotationRange,
          scaleRange: scaleRange,
          collisionShape: .rectangle(size: CGSize(width: 34, height: 34)),
        ) {
          Rectangle()
            .stroke(lineWidth: 4)
            .foregroundStyle(.gray.opacity(0.8))
            .frame(width: 30, height: 30)
        }
      case .roundedOutline:
        TesseraItem(
          id: id,
          weight: weight,
          allowedRotationRange: rotationRange,
          scaleRange: scaleRange,
          collisionShape: .rectangle(size: CGSize(width: 34, height: 34)),
        ) {
          RoundedRectangle(cornerRadius: 6)
            .stroke(lineWidth: 4)
            .frame(width: 30, height: 30)
        }
      case .partyPopper:
        TesseraItem(
          id: id,
          weight: weight,
          allowedRotationRange: rotationRange,
          scaleRange: scaleRange,
          collisionShape: .circle(radius: 20),
        ) {
          Image(systemName: "party.popper.fill")
            .foregroundStyle(.red.opacity(0.5))
            .font(.largeTitle)
        }
      case .minus:
        TesseraItem(
          id: id,
          weight: weight,
          allowedRotationRange: rotationRange,
          scaleRange: scaleRange,
          collisionShape: .rectangle(size: CGSize(width: 36, height: 4)),
        ) {
          Text("-")
            .foregroundStyle(.gray)
            .font(.largeTitle)
        }
      case .equals:
        TesseraItem(
          id: id,
          weight: weight,
          allowedRotationRange: rotationRange,
          scaleRange: scaleRange,
          collisionShape: .rectangle(size: CGSize(width: 36, height: 12)),
        ) {
          Text("=")
            .foregroundStyle(.gray)
            .font(.largeTitle)
        }
      case .circleOutline:
        TesseraItem(
          id: id,
          weight: weight,
          allowedRotationRange: rotationRange,
          scaleRange: scaleRange,
          collisionShape: .circle(radius: 15),
        ) {
          Circle()
            .stroke(lineWidth: 4)
            .foregroundStyle(.gray.opacity(0.2))
            .frame(width: 30, height: 30)
        }
      }
    }
  }
}
