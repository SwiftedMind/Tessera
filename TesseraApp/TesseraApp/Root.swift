// By Dennis Müller

import SwiftUI
import Tessera
import UniformTypeIdentifiers

/// Entry point view that hosts the tessera canvas and the editing inspector.
struct Root: View {
  @Binding var document: TesseraDocument
  @State private var editor: TesseraEditorModel
  @State private var isTiledCanvasEnabled: Bool = true
  @State private var showInspector: Bool = true
  @State private var exportFormat: ExportFormat = .png
  @State private var isExportPresented: Bool = false
  @State private var exportDocument: TesseraExportDocument = .placeholder

  init(document: Binding<TesseraDocument>) {
    _document = document
    _editor = State(initialValue: TesseraEditorModel(document: document))
  }

  var body: some View {
    NavigationStack {
      PatternStage(
        configuration: editor.liveConfiguration,
        tileSize: editor.tesseraSize,
        isTiledCanvasEnabled: $isTiledCanvasEnabled,
      )
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
        Menu {
          Button(role: .none) { beginExport(format: .png) } label: {
            Label("Export as png", systemImage: "photo")
          }
          Button(role: .none) { beginExport(format: .pdf) } label: {
            Label("Export as pdf", systemImage: "doc.richtext")
          }
        } label: {
          Label("Tile", systemImage: "square")
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
    editor.refreshLiveConfiguration()
    exportDocument = TesseraExportDocument(
      configuration: editor.liveConfiguration,
      tileSize: editor.tesseraSize,
      format: exportFormat,
    )
  }

  private func beginExport(format: ExportFormat) {
    exportFormat = format
    exportDocument = TesseraExportDocument(
      configuration: editor.liveConfiguration,
      tileSize: editor.tesseraSize,
      format: format,
    )
    isExportPresented = true
  }
}

#Preview {
  Root(document: .constant(TesseraDocument()))
    .frame(width: 1000, height: 640)
}
