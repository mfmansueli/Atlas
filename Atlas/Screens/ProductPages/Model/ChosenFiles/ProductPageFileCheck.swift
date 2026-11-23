//
//  ProductPageFileCheck.swift
//  Atlas
//

import Foundation

/// Choose Files…' size check (board 52, “and its size check”): a set takes
/// 1 to 10 PNG or JPEG screenshots in a size App Store Connect accepts for
/// the device. Every problem is said at once, each with its fix, so
/// nothing reaches Review & Push that Apple would refuse.
enum ProductPageFileCheck {
    /// What's wrong with `files` for `device`; empty when they can go.
    static func problems(_ files: [ProductPageChosenFile], device: ProductPageDevice) -> [String] {
        var problems: [String] = []
        if files.count > ProductPageScreenshotsPush.maxScreenshots {
            problems.append(String(localized: "\(files.count) screenshots chosen. A set takes up to 10."))
        }
        let sizes = sizesText(device)
        for file in files {
            guard let size = file.pixelSize else {
                problems.append(String(localized: "“\(file.fileName)” isn’t a PNG or JPEG image Atlas can read."))
                continue
            }
            if !device.accepts(size) {
                // Pixels are never grouped ("1170", not "1.170").
                let shown = "\(size.width) × \(size.height)"
                problems.append(String(
                    localized: "“\(file.fileName)” is \(shown). \(device.displayType.title) takes \(sizes), upright or turned."
                ))
            }
        }
        return problems
    }

    /// "1320 × 2868, 1290 × 2796 or 1260 × 2736".
    static func sizesText(_ device: ProductPageDevice) -> String {
        let all = device.acceptedSizes.map { "\($0.width) × \($0.height)" }
        guard let last = all.last, all.count > 1 else { return all.first ?? "" }
        return String(localized: "\(all.dropLast().joined(separator: ", ")) or \(last)")
    }
}
