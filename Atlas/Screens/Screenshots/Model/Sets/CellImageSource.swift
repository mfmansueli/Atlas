//
//  CellImageSource.swift
//  Atlas
//

import Foundation

/// What a cell shows: a render from the template, the screenshot that's
/// live in App Store Connect (uploaded by hand, or restored and pinned), or
/// a file given to Atlas by hand.
enum CellImageSource: Hashable, Sendable {
    case render(RenderJob)
    case live(LiveScreenshot)
    case hand(ScreenshotHandFile)
    case none

    var renderJob: RenderJob? {
        if case let .render(job) = self { return job }
        return nil
    }

    var handFile: ScreenshotHandFile? {
        if case let .hand(file) = self { return file }
        return nil
    }
}
