// By Dennis Müller

import SwiftUI
import Tessera

struct OrganicRadialScaleSteeringExampleView: View {
  var body: some View {
    Tessera(DemoConfigurations.organicRadialScale)
      .mode(.canvas(edgeBehavior: .finite))
      .seed(.fixed(203))
      .background(.black)
      .ignoresSafeArea()
      .overlay(alignment: .topLeading) {
        SteeringLegendOverlay(
          title: "Radial Scale",
          startLabel: "center: small",
          endLabel: "edge: large",
          axisSymbol: "dot.radiowaves.left.and.right",
        )
      }
      .navigationTitle("Organic Radial Scale")
      .navigationBarTitleDisplayMode(.inline)
  }
}

struct GridRadialRotationSteeringExampleView: View {
  var body: some View {
    Tessera(DemoConfigurations.gridRadialRotation)
      .mode(.canvas(edgeBehavior: .finite))
      .seed(.fixed(303))
      .background(.black)
      .ignoresSafeArea()
      .overlay(alignment: .topLeading) {
        SteeringLegendOverlay(
          title: "Radial Rotation",
          startLabel: "center: +0°",
          endLabel: "edge: +42°",
          axisSymbol: "scope",
        )
      }
      .navigationTitle("Grid Radial Rotation")
      .navigationBarTitleDisplayMode(.inline)
  }
}
