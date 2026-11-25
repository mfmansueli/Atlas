//
//  PriceLadderDiskStore.swift
//  Atlas
//

import Foundation

/// Apple's price point ladders on this Mac: one file per product,
/// `Application Support/Atlas/Pricing/ladders-<productID>.json`, so a new
/// launch suggests prices without reading ~21 pages from App Store
/// Connect again. Plain file reads and writes, called off the main actor
/// by `LivePricingCache`; a missing or unreadable file reads as nothing.
struct PriceLadderDiskStore: Sendable {
    let directory: URL

    static var defaultDirectory: URL {
        URL.applicationSupportDirectory.appending(path: "Atlas/Pricing", directoryHint: .isDirectory)
    }

    /// `ladders-6450000001.json`; anything but letters, digits and "-" in
    /// the ID becomes "_".
    func url(for productID: String) -> URL {
        let safe = String(productID.unicodeScalars.map { scalar in
            CharacterSet.alphanumerics.contains(scalar) || scalar == "-" ? Character(scalar) : "_"
        })
        return directory.appending(path: "ladders-\(safe).json")
    }

    func read(productID: String) -> StoredPriceLadders? {
        guard let data = try? Data(contentsOf: url(for: productID)),
              let stored = try? JSONDecoder().decode(StoredPriceLadders.self, from: data),
              stored.version == StoredPriceLadders.currentVersion, stored.productID == productID
        else { return nil }
        return stored
    }

    /// Writes the product's file, or removes it when nothing is left.
    func write(_ stored: StoredPriceLadders) {
        guard !stored.isEmpty else {
            remove(productID: stored.productID)
            return
        }
        guard let data = try? JSONEncoder().encode(stored) else { return }
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? data.write(to: url(for: stored.productID), options: .atomic)
    }

    func remove(productID: String) {
        try? FileManager.default.removeItem(at: url(for: productID))
    }
}
