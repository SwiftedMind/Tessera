// By Dennis Müller

import SwiftUI
import Tessera
import UniformTypeIdentifiers

/// Entry point view that hosts the tessera canvas and the editing inspector.
struct Root: View {
  @State private var editor = TesseraEditorModel()
  @State private var repeatPattern: Bool = true
  @State private var showInspector: Bool = true
  @State private var exportFormat: ExportFormat = .png
  @State private var isExportPresented: Bool = false
  @State private var exportDocument: TesseraExportDocument = .placeholder

  var body: some View {
    NavigationStack {
      PatternStage(tessera: editor.liveTessera, repeatPattern: $repeatPattern)
        .backgroundExtensionEffect()
        .toolbar { toolbarContent }
        .inspector(isPresented: $showInspector) {
          InspectorPanel()
        }
        .fileExporter(
          isPresented: $isExportPresented,
          document: exportDocument,
          contentType: exportFormat == .png ? .png : .pdf,
          defaultFilename: exportDocument.defaultFileName,
        ) { _ in }
    }
    .onAppear(perform: seedInitialExportDocument)
    .environment(editor)
  }

  @ToolbarContentBuilder
  private var toolbarContent: some ToolbarContent {
    ToolbarItem(placement: .primaryAction) {
      Menu {
        Button(role: .none) { beginExport(format: .png) } label: {
          Label("Export PNG", systemImage: "photo")
        }
        Button(role: .none) { beginExport(format: .pdf) } label: {
          Label("Export PDF", systemImage: "doc.richtext")
        }
      } label: {
        Label("Export", systemImage: "square.and.arrow.up")
          .labelStyle(.titleAndIcon)
      }
    }
    ToolbarItem(placement: .primaryAction) {
      Button {
        showInspector.toggle()
      } label: {
        Image(systemName: "sidebar.right")
      }
    }
  }

  private func seedInitialExportDocument() {
    editor.refreshLiveTessera()
    exportDocument = TesseraExportDocument(tessera: editor.liveTessera, format: exportFormat)
  }

  private func beginExport(format: ExportFormat) {
    exportFormat = format
    exportDocument = TesseraExportDocument(tessera: editor.liveTessera, format: format)
    isExportPresented = true
  }
}

#Preview {
  Root()
    .frame(width: 1000, height: 640)
}
