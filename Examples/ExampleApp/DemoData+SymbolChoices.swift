// By Dennis Müller

import SwiftUI
import Tessera

extension DemoConfigurations {
  static var choiceSymbolsGrid: Pattern {
    Pattern(
      symbols: [.choiceRoot],
      placement: .grid(
        columns: ChoiceSymbolsConstants.columns,
        rows: ChoiceSymbolsConstants.rows,
        symbolOrder: .sequence,
        seed: ChoiceSymbolsConstants.seed,
        showsGridOverlay: true,
      ),
    )
  }

  static var choiceSymbolsIndexSequenceGrid: Pattern {
    Pattern(
      symbols: [.choiceIndexSequenceRoot],
      placement: .grid(
        columns: ChoiceSymbolsConstants.columns,
        rows: ChoiceSymbolsConstants.rows,
        symbolOrder: .sequence,
        seed: ChoiceSymbolsConstants.indexSequenceSeed,
        showsGridOverlay: true,
      ),
    )
  }
}

extension Symbol {
  static var choiceRoot: Symbol {
    Symbol(
      id: ChoiceSymbolIDs.root,
      choiceStrategy: .weightedRandom,
      choiceSeed: 302,
      choices: [.choiceSpark, .choiceSlashedCircle, .choiceDiamond],
    )
  }

  static var choiceIndexSequenceRoot: Symbol {
    Symbol(
      id: ChoiceSymbolIDs.indexSequenceRoot,
      choiceStrategy: .indexSequence([0, 2, 1, 2]),
      choices: [.choiceSpark, .choiceSlashedCircle, .choiceDiamond],
    )
  }

  static var choiceSpark: Symbol {
    Symbol(
      id: ChoiceSymbolIDs.spark,
      weight: 1,
      rotation: .degrees(0)...(.degrees(0)),
      collider: .shape(.rectangle(center: .zero, size: .zero)),
    ) {
      Image(systemName: "sparkles")
        .resizable()
        .aspectRatio(contentMode: .fit)
        .frame(width: 26, height: 26)
        .foregroundStyle(Color(red: 0.95, green: 0.72, blue: 0.30))
    }
  }

  static var choiceSlashedCircle: Symbol {
    Symbol(
      id: ChoiceSymbolIDs.slashedCircle,
      weight: 1,
      rotation: .degrees(0)...(.degrees(0)),
      collider: .shape(.rectangle(center: .zero, size: .zero)),
    ) {
      Image(systemName: "circle.slash")
        .resizable()
        .aspectRatio(contentMode: .fit)
        .frame(width: 26, height: 26)
        .foregroundStyle(Color(red: 0.56, green: 0.78, blue: 0.96))
    }
  }

  static var choiceDiamond: Symbol {
    Symbol(
      id: ChoiceSymbolIDs.diamond,
      weight: 1,
      rotation: .degrees(0)...(.degrees(0)),
      collider: .shape(.rectangle(center: .zero, size: .zero)),
    ) {
      Image(systemName: "diamond.fill")
        .resizable()
        .aspectRatio(contentMode: .fit)
        .frame(width: 20, height: 20)
        .foregroundStyle(Color(red: 0.94, green: 0.44, blue: 0.50))
    }
  }
}

struct ChoiceSymbolsExampleView: View {
  var body: some View {
    Tessera(DemoConfigurations.choiceSymbolsGrid)
      .mode(.tiled(tileSize: ChoiceSymbolsConstants.tileSize))
      .seed(.fixed(ChoiceSymbolsConstants.seed))
      .background(Color(red: 0.09, green: 0.10, blue: 0.14))
      .ignoresSafeArea()
      .overlay(alignment: .topLeading) {
        SteeringLegendOverlay(
          title: "Choice Symbol",
          startLabel: "weighted variants per cell",
          endLabel: "slashed-circle phase: +0.5 / +0.5",
          axisSymbol: "dice",
        )
      }
      .navigationTitle("Choice Symbols")
      .navigationBarTitleDisplayMode(.inline)
  }
}

struct ChoiceIndexSequenceExampleView: View {
  var body: some View {
    Tessera(DemoConfigurations.choiceSymbolsIndexSequenceGrid)
      .mode(.tiled(tileSize: ChoiceSymbolsConstants.tileSize))
      .seed(.fixed(ChoiceSymbolsConstants.indexSequenceSeed))
      .background(Color(red: 0.09, green: 0.10, blue: 0.14))
      .ignoresSafeArea()
      .overlay(alignment: .topLeading) {
        SteeringLegendOverlay(
          title: "Choice Index Sequence",
          startLabel: "indices: [0, 2, 1, 2] repeats",
          endLabel: "explicit, deterministic child order",
          axisSymbol: "list.number",
        )
      }
      .navigationTitle("Choice Index Sequence")
      .navigationBarTitleDisplayMode(.inline)
  }
}

private enum ChoiceSymbolsConstants {
  static let columns = 9
  static let rows = 9
  static let tileSize = CGSize(width: 320, height: 320)
  static let seed: UInt64 = 302
  static let indexSequenceSeed: UInt64 = 904
}

private enum ChoiceSymbolIDs {
  static let root = UUID(uuidString: "F9514DB4-50B4-4F17-8BE3-26E2A48D6C38")!
  static let indexSequenceRoot = UUID(uuidString: "34D834A5-4C6E-45D0-8F80-71E81E88FB03")!
  static let spark = UUID(uuidString: "80A33AD9-7BC5-4C69-A0A0-511DD6CBEE71")!
  static let slashedCircle = UUID(uuidString: "4D51AD6A-0B07-478C-B053-95B380EC2EA4")!
  static let diamond = UUID(uuidString: "A2C8FC7B-CE54-41B0-A909-26FAFF3512E4")!
}
