//
//  ScreenshotHandPlace.swift
//  Atlas
//

import Foundation

/// One screenshot of a language's set on a device, named so it's found
/// again after the set changed: what its place started as (a template
/// slot, a live screenshot, nothing for one added by hand) and the file in
/// it. An assistant's removal or new order (`ScreenshotHandArrangement`)
/// names the screenshots it means this way, so accepting it acts on the
/// same ones even when the person moved them meanwhile.
struct ScreenshotHandPlace: Codable, Hashable, Sendable {
    /// Its number among the screenshots that stay, from 0, when it was
    /// named.
    var position: Int
    var base: ScreenshotHandBase?
    var fileID: String?
    /// The file's name, for the card.
    var fileName: String?

    init(position: Int, base: ScreenshotHandBase?, fileID: String?, fileName: String?) {
        self.position = position
        self.base = base
        self.fileID = fileID
        self.fileName = fileName
    }

    /// The slot at `position` among a set's kept ones.
    init(_ slot: ScreenshotHandSlot, position: Int) {
        self.init(position: position, base: slot.base, fileID: slot.file?.id, fileName: slot.file?.fileName)
    }

    /// Whether `slot` is this screenshot.
    func matches(_ slot: ScreenshotHandSlot) -> Bool {
        slot.base == base && slot.file?.id == fileID
    }

    /// The ID MCP lists it by: `file:<id>` for a file given by hand or
    /// an assistant, `template:<n>` for a slot the template renders (from
    /// 1), `live:<id>` for a screenshot on the App Store.
    var mcpID: String {
        if let fileID { return "file:\(fileID)" }
        switch base {
        case let .template(slot): return "template:\(slot + 1)"
        case let .live(id, _, _): return "live:\(id)"
        case nil: return "place:\(position + 1)"
        }
    }

    /// What it is, for MCP: `template`, `file` or `live`.
    var madeBy: String {
        if fileID != nil { return "file" }
        return base?.templateSlot != nil ? "template" : "live"
    }

    /// The kept places of `set`, in order.
    static func kept(in set: ScreenshotHandSet) -> [ScreenshotHandPlace] {
        set.kept.enumerated().map { ScreenshotHandPlace($1, position: $0) }
    }
}
