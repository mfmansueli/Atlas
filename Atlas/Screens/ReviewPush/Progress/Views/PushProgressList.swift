//
//  PushProgressList.swift
//  Atlas
//

import SwiftUI

/// Every row of the push in one list: the changes (event art with its
/// image or video), then the screenshots, then the header, search images
/// and App Previews. It follows the furthest row on its way; a click on a
/// thumbnail opens it large.
struct PushProgressList: View {
    let push: PushController
    let artwork: PushProgressArtworkCache
    /// The row to keep in view: the furthest one on its way.
    let followedID: String?
    /// The thumbnail column's width; nil when nothing in the push has one.
    let thumbnailWidth: CGFloat?
    let onOpen: (String) -> Void

    private var screenshots: ScreenshotPushController { push.screenshots }

    var body: some View {
        ScrollViewReader { proxy in
            List {
                if push.phase != .idle {
                    ForEach(push.items) { item in
                        let id = PushProgressEntry.changeID(item.id)
                        let art = artwork.artwork(for: item)
                        PushProgressRow(item: item, artwork: art, thumbnailWidth: thumbnailWidth, onOpen: art == nil ? nil : { onOpen(id) })
                            .listRowInsets(EdgeInsets())
                            .id(id)
                    }
                }
                if let run = screenshots.run {
                    ForEach(run.items) { item in
                        let id = PushProgressEntry.shotID(item.id)
                        ScreenshotPushProgressRow(
                            item: item, image: screenshots.newImage(for: item.plan), thumbnailWidth: thumbnailWidth, onOpen: { onOpen(id) }
                        )
                        .listRowInsets(EdgeInsets())
                        .id(id)
                    }
                }
                if let run = screenshots.extras.run {
                    ForEach(run.items) { item in
                        let id = PushProgressEntry.extraID(item.id)
                        ExtrasPushProgressRow(run: run, item: item, thumbnailWidth: thumbnailWidth, onOpen: { onOpen(id) })
                            .listRowInsets(EdgeInsets())
                            .id(id)
                    }
                }
            }
            .listStyle(.plain)
            .accessibilityIdentifier("push.list")
            .onChange(of: followedID) { _, id in
                guard let id else { return }
                withAnimation { proxy.scrollTo(id, anchor: .center) }
            }
        }
    }
}
