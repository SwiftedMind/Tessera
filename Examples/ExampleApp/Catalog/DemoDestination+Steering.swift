// By Dennis Müller

import SwiftUI
import Tessera

extension DemoDestination {
  @ViewBuilder
  func organicSpacingGradientView() -> some View {
    DemoExampleScreen(title: "Organic Spacing Gradient") {
      Tessera(DemoConfigurations.organicSpacingGradient)
        .mode(.canvas(edgeBehavior: .finite))
        .seed(.fixed(21))
        .background(.black)
        .overlay(alignment: .topLeading) {
          SteeringLegendOverlay(
            title: "Minimum Spacing",
            startLabel: "top: tight",
            endLabel: "bottom: wide",
            axisSymbol: "arrow.down",
          )
        }
    }
  }

  @ViewBuilder
  func organicScaleGradientView() -> some View {
    DemoExampleScreen(title: "Organic Scale Gradient") {
      Tessera(DemoConfigurations.organicScaleGradient)
        .mode(.canvas(edgeBehavior: .finite))
        .seed(.fixed(34))
        .background(.black)
        .overlay(alignment: .topLeading) {
          SteeringLegendOverlay(
            title: "Symbol Scale",
            startLabel: "left: small",
            endLabel: "right: large",
            axisSymbol: "arrow.right",
          )
        }
    }
  }

  @ViewBuilder
  func gridScaleGradientView() -> some View {
    DemoExampleScreen(title: "Grid Scale Gradient") {
      Tessera(DemoConfigurations.gridScaleGradient)
        .mode(.tiled(tileSize: CGSize(width: 260, height: 260)))
        .seed(.fixed(55))
        .background(.black)
        .overlay(alignment: .topLeading) {
          SteeringLegendOverlay(
            title: "Grid Scale",
            startLabel: "top-left: small",
            endLabel: "bottom-right: large",
            axisSymbol: "arrow.down.right",
          )
        }
    }
  }

  @ViewBuilder
  func organicRadialScaleView() -> some View {
    DemoExampleScreen(title: "Organic Radial Scale") {
      Tessera(DemoConfigurations.organicRadialScale)
        .mode(.canvas(edgeBehavior: .finite))
        .seed(.fixed(203))
        .background(.black)
        .overlay(alignment: .topLeading) {
          SteeringLegendOverlay(
            title: "Radial Scale",
            startLabel: "center: small",
            endLabel: "edge: large",
            axisSymbol: "dot.radiowaves.left.and.right",
          )
        }
    }
  }

  @ViewBuilder
  func organicRotationGradientView() -> some View {
    DemoExampleScreen(title: "Organic Rotation Gradient") {
      Tessera(DemoConfigurations.organicRotationGradient)
        .mode(.canvas(edgeBehavior: .finite))
        .seed(.fixed(89))
        .background(.black)
        .overlay(alignment: .topLeading) {
          SteeringLegendOverlay(
            title: "Rotation Offset",
            startLabel: "top: +0°",
            endLabel: "bottom: +180°",
            axisSymbol: "arrow.down.circle",
          )
        }
    }
  }

  @ViewBuilder
  func gridRadialRotationView() -> some View {
    DemoExampleScreen(title: "Grid Radial Rotation") {
      Tessera(DemoConfigurations.gridRadialRotation)
        .mode(.canvas(edgeBehavior: .finite))
        .seed(.fixed(303))
        .background(.black)
        .overlay(alignment: .topLeading) {
          SteeringLegendOverlay(
            title: "Radial Rotation",
            startLabel: "center: +0°",
            endLabel: "edge: +42°",
            axisSymbol: "scope",
          )
        }
    }
  }

  @ViewBuilder
  func gridRotationGradientView() -> some View {
    DemoExampleScreen(title: "Grid Rotation Gradient") {
      Tessera(DemoConfigurations.gridRotationGradient)
        .mode(.canvas(edgeBehavior: .finite))
        .seed(.fixed(121))
        .background(.black)
        .overlay(alignment: .topLeading) {
          SteeringLegendOverlay(
            title: "Rotation Multiplier",
            startLabel: "left: 0.5×",
            endLabel: "right: 1.5×",
            axisSymbol: "arrow.right.circle",
          )
        }
    }
  }
}
