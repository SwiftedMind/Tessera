// By Dennis Müller

import SwiftUI
import Tessera

extension DemoDestination {
  @ViewBuilder
  func organicSpacingGradientView() -> some View {
    DemoExampleScreen(title: "Organic Spacing Gradient", ignoresSafeArea: false) {
      steeringScene(
        title: "Minimum Spacing",
        startLabel: "top: tight",
        endLabel: "bottom: wide",
        axisSymbol: "arrow.down",
      ) {
        Tessera(DemoConfigurations.organicSpacingGradient)
          .mode(.canvas(edgeBehavior: .finite))
          .seed(.fixed(21))
      }
    }
  }

  @ViewBuilder
  func organicScaleGradientView() -> some View {
    DemoExampleScreen(title: "Organic Scale Gradient", ignoresSafeArea: false) {
      steeringScene(
        title: "Symbol Scale",
        startLabel: "left: small",
        endLabel: "right: large",
        axisSymbol: "arrow.right",
      ) {
        Tessera(DemoConfigurations.organicScaleGradient)
          .mode(.canvas(edgeBehavior: .finite))
          .seed(.fixed(34))
      }
    }
  }

  @ViewBuilder
  func gridScaleGradientView() -> some View {
    DemoExampleScreen(title: "Grid Scale Gradient", ignoresSafeArea: false) {
      steeringScene(
        title: "Grid Scale",
        startLabel: "top-left: small",
        endLabel: "bottom-right: large",
        axisSymbol: "arrow.down.right",
      ) {
        Tessera(DemoConfigurations.gridScaleGradient)
          .mode(.tiled(tileSize: CGSize(width: 260, height: 260)))
          .seed(.fixed(55))
      }
    }
  }

  @ViewBuilder
  func organicRadialScaleView() -> some View {
    DemoExampleScreen(title: "Organic Radial Scale", ignoresSafeArea: false) {
      steeringScene(
        title: "Radial Scale",
        startLabel: "center: small",
        endLabel: "edge: large",
        axisSymbol: "dot.radiowaves.left.and.right",
      ) {
        Tessera(DemoConfigurations.organicRadialScale)
          .mode(.canvas(edgeBehavior: .finite))
          .seed(.fixed(203))
      }
    }
  }

  @ViewBuilder
  func organicRotationGradientView() -> some View {
    DemoExampleScreen(title: "Organic Rotation Gradient", ignoresSafeArea: false) {
      steeringScene(
        title: "Rotation Offset",
        startLabel: "top: +0°",
        endLabel: "bottom: +140°",
        axisSymbol: "arrow.down.circle",
      ) {
        Tessera(DemoConfigurations.organicRotationGradient)
          .mode(.canvas(edgeBehavior: .finite))
          .seed(.fixed(89))
      }
    }
  }

  @ViewBuilder
  func gridRadialRotationView() -> some View {
    DemoExampleScreen(title: "Grid Radial Rotation", ignoresSafeArea: false) {
      steeringScene(
        title: "Radial Rotation",
        startLabel: "center: +0°",
        endLabel: "edge: +32°",
        axisSymbol: "scope",
      ) {
        Tessera(DemoConfigurations.gridRadialRotation)
          .mode(.canvas(edgeBehavior: .finite))
          .seed(.fixed(303))
      }
    }
  }

  @ViewBuilder
  func gridRotationGradientView() -> some View {
    DemoExampleScreen(title: "Grid Rotation Gradient", ignoresSafeArea: false) {
      steeringScene(
        title: "Rotation Multiplier",
        startLabel: "left: 0.7×",
        endLabel: "right: 1.3×",
        axisSymbol: "arrow.right.circle",
      ) {
        Tessera(DemoConfigurations.gridRotationGradient)
          .mode(.canvas(edgeBehavior: .finite))
          .seed(.fixed(121))
      }
    }
  }
}

private extension View {
  func steeringLegendInset(
    title: String,
    startLabel: String,
    endLabel: String,
    axisSymbol: String,
  ) -> some View {
    safeAreaInset(edge: .top, spacing: 0) {
      HStack {
        SteeringLegendOverlay(
          title: title,
          startLabel: startLabel,
          endLabel: endLabel,
          axisSymbol: axisSymbol,
        )
        .allowsHitTesting(false)

        Spacer(minLength: 0)
      }
    }
  }
}

private func steeringScene(
  title: String,
  startLabel: String,
  endLabel: String,
  axisSymbol: String,
  @ViewBuilder patternView: () -> some View,
) -> some View {
  ZStack {
    DemoPalette.canvasBackground
      .ignoresSafeArea()

    patternView()
      .background(.clear)
      .ignoresSafeArea()
  }
  .steeringLegendInset(
    title: title,
    startLabel: startLabel,
    endLabel: endLabel,
    axisSymbol: axisSymbol,
  )
}
