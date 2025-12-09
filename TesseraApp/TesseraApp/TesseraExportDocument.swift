// By Dennis Müller

import SwiftUI
import Tessera
import UniformTypeIdentifiers

enum ExportFormat: Hashable {
  case png
  case pdf
}

struct TesseraExportDocument: FileDocument {
  static var readableContentTypes: [UTType] { [.png, .pdf] }

  var tessera: Tessera
  var format: ExportFormat

  var defaultFileName: String {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd'_'HHmm"
    let timestamp = formatter.string(from: Date())
    return "Tessera_\(timestamp)"
  }

  static var placeholder: TesseraExportDocument {
    TesseraExportDocument(
      tessera: Tessera(
        size: CGSize(width: 256, height: 256),
        items: EditableItem.demoItems.map { $0.makeTesseraItem() },
        seed: 0,
        minimumSpacing: 10,
        density: 0.8,
        baseScaleRange: 0.5...1.2,
      ),
      format: .png,
    )
  }

  init(tessera: Tessera, format: ExportFormat) {
    self.tessera = tessera
    self.format = format
  }

  init(configuration: ReadConfiguration) throws {
    throw CocoaError(.fileReadUnknown)
  }

  func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
    let temporaryDirectory = FileManager.default.temporaryDirectory
    let name = UUID().uuidString

    let exportedURL: URL = try performOnMain {
      switch format {
      case .png:
        try tessera.renderPNG(
          to: temporaryDirectory,
          fileName: name,
          options: TesseraRenderOptions(targetPixelSize: CGSize(width: 2048, height: 2048)),
        )
      case .pdf:
        try tessera.renderPDF(to: temporaryDirectory, fileName: name)
      }
    }

    let data = try Data(contentsOf: exportedURL)
    return .init(regularFileWithContents: data)
  }

  private func performOnMain<T>(_ work: @escaping () throws -> T) rethrows -> T {
    if Thread.isMainThread {
      return try work()
    }
    return try DispatchQueue.main.sync {
      try work()
    }
  }
}
