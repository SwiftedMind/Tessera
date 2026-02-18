// By Dennis Müller

import SwiftUI

struct TesseraDemoView: View {
  @State private var searchText = ""

  var body: some View {
    NavigationStack {
      List {
        Section {
          CatalogIntroCard()
        }

        ForEach(filteredSections) { section in
          Section {
            ForEach(section.examples) { example in
              NavigationLink {
                example.destination.makeView()
              } label: {
                ExampleRow(example: example)
              }
            }
          } header: {
            Text(section.title)
          } footer: {
            Text(section.summary)
          }
        }
      }
      .listStyle(.insetGrouped)
      .navigationTitle("Tessera Examples")
      .searchable(text: $searchText, prompt: "Find an example")
    }
  }

  private var filteredSections: [DemoCatalogSection] {
    let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !query.isEmpty else { return DemoCatalog.sections }

    return DemoCatalog.sections.compactMap { section in
      if section.title.localizedCaseInsensitiveContains(query)
        || section.summary.localizedCaseInsensitiveContains(query) {
        return section
      }

      let filteredExamples = section.examples.filter { $0.matches(query: query) }
      guard !filteredExamples.isEmpty else { return nil }

      return section.replacingExamples(filteredExamples)
    }
  }
}

#Preview { TesseraDemoView().preferredColorScheme(.dark) }
