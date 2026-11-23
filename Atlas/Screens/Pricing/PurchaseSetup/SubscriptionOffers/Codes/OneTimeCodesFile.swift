//
//  OneTimeCodesFile.swift
//  Atlas
//

import SwiftUI
import UniformTypeIdentifiers

/// A batch of one-time offer codes as the CSV App Store Connect made, for
/// Save Codes…'s `.fileExporter`.
struct OneTimeCodesFile: FileDocument, Hashable {
    static let readableContentTypes: [UTType] = [.commaSeparatedText]

    let data: Data
    /// "Lumen Monthly Podcast — 500 codes.csv".
    let fileName: String

    init(data: Data, fileName: String) {
        self.data = data
        self.fileName = fileName
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
        fileName = configuration.file.filename ?? "Codes.csv"
    }

    func fileWrapper(configuration _: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
