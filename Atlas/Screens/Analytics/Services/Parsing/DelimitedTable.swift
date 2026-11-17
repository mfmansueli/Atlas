//
//  DelimitedTable.swift
//  Atlas
//

import Foundation

/// A report file as rows read by column name: Apple asks to rely on names,
/// not positions, and its values aren't case sensitive. Tab-delimited
/// (Sales and Trends) or comma-separated with quotes (analytics reports);
/// the header line says which.
struct DelimitedTable: Sendable {
    /// Lowercased column names, in order.
    let columns: [String]
    let rows: [[String]]
    private let indexByName: [String: Int]

    init(text: String) {
        var lines = text.split(omittingEmptySubsequences: true) { $0 == "\n" || $0 == "\r\n" || $0 == "\r" }.map(String.init)
        let header = lines.isEmpty ? "" : lines.removeFirst()
        let delimiter: Character = header.contains("\t") ? "\t" : ","
        columns = Self.fields(of: header, delimiter: delimiter).map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
        rows = lines.map { Self.fields(of: $0, delimiter: delimiter) }
        indexByName = Dictionary(columns.enumerated().map { ($1, $0) }, uniquingKeysWith: { first, _ in first })
    }

    init?(data: Data) {
        guard let inflated = Gzip.inflate(data), let text = String(data: inflated, encoding: .utf8) else { return nil }
        self.init(text: text)
    }

    func has(_ column: String) -> Bool {
        indexByName[column.lowercased()] != nil
    }

    /// The trimmed value of `column` in `row`, "" when the column is missing.
    func value(_ column: String, in row: [String]) -> String {
        guard let index = indexByName[column.lowercased()], row.indices.contains(index) else { return "" }
        return row[index].trimmingCharacters(in: .whitespaces)
    }

    /// The first of `columns` this file has, e.g. "Date" or "Event Date".
    func value(anyOf columns: [String], in row: [String]) -> String {
        for column in columns where has(column) {
            return value(column, in: row)
        }
        return ""
    }

    func int(_ column: String, in row: [String]) -> Int {
        let text = value(column, in: row)
        return Int(text) ?? Double(text).map { Int($0.rounded()) } ?? 0
    }

    /// Splits one line; a quoted field may hold the delimiter and doubled quotes.
    static func fields(of line: String, delimiter: Character) -> [String] {
        guard line.contains("\"") else { return line.split(separator: delimiter, omittingEmptySubsequences: false).map(String.init) }
        var fields: [String] = []
        var current = ""
        var isQuoted = false
        var iterator = line.makeIterator()
        var pending = iterator.next()
        while let character = pending {
            pending = iterator.next()
            if isQuoted {
                if character == "\"" {
                    if pending == "\"" {
                        current.append("\"")
                        pending = iterator.next()
                    } else {
                        isQuoted = false
                    }
                } else {
                    current.append(character)
                }
            } else if character == "\"" {
                isQuoted = true
            } else if character == delimiter {
                fields.append(current)
                current = ""
            } else {
                current.append(character)
            }
        }
        fields.append(current)
        return fields
    }
}
