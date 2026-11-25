//
//  ChatRoomPlacementTests.swift
//  AtlasTests
//

import SwiftUI
import Testing
@testable import Atlas

/// Every page's last content ends above the chat's pill (board 69): a
/// page's vertical scroll view takes the room as a bottom content margin, a
/// page pinned to the bottom edge as padding, and nothing gets room where
/// there's no pill.
@Suite("Chat · room each page leaves")
struct ChatRoomPlacementTests {
    private let room = AssistantChatRoom.pageRoom

    @Test func aScrollViewScrollsItsContentPastThePill() {
        #expect(ChatRoomPlacement.scrollContent.contentMargin(room: room) == room)
        #expect(ChatRoomPlacement.scrollContent.padding(room: room) == 0)
    }

    @Test func aPagePinnedToTheEdgeEndsAboveThePill() {
        #expect(ChatRoomPlacement.bottomEdge.padding(room: room) == room)
        #expect(ChatRoomPlacement.bottomEdge.contentMargin(room: room) == 0)
    }

    @Test(arguments: ChatRoomPlacement.allCases)
    func eachPlacementTakesTheRoomOnce(_ placement: ChatRoomPlacement) {
        #expect(placement.contentMargin(room: room) + placement.padding(room: room) == room)
    }

    @Test(arguments: ChatRoomPlacement.allCases)
    func withoutThePillNoRoomIsLeft(_ placement: ChatRoomPlacement) {
        // Sheets, previews and DEBUG hosts read the environment's default.
        let none = EnvironmentValues().chatCornerRoom
        #expect(placement.contentMargin(room: none) == 0)
        #expect(placement.padding(room: none) == 0)
    }

    @Test(arguments: ChatRoomPlacement.allCases)
    func aNegativeRoomIsNone(_ placement: ChatRoomPlacement) {
        #expect(placement.contentMargin(room: -8) == 0)
        #expect(placement.padding(room: -8) == 0)
    }

    @MainActor
    @Test func aPageInTheWorkspaceReadsTheRoom() {
        #expect(read { AnyView($0) } == room)
    }

    @MainActor
    @Test(arguments: ChatRoomPlacement.allCases)
    func whatsInsideLeavesNoRoomTwice(_ placement: ChatRoomPlacement) {
        #expect(read { AnyView($0.leavesChatRoom(placement)) } == 0)
    }

    /// The room a view reads inside `wrap`'s page, in the workspace.
    @MainActor
    private func read(_ wrap: (RoomReader) -> AnyView) -> CGFloat? {
        let seen = SeenRoom()
        let host = NSHostingView(rootView: wrap(RoomReader(seen: seen)).environment(\.chatCornerRoom, room))
        host.frame = CGRect(x: 0, y: 0, width: 200, height: 200)
        host.layoutSubtreeIfNeeded()
        return seen.value
    }

    @Test func theLastContentEndsAboveThePillsTop() {
        let pillTop = AssistantChatRoom.bottomPadding(isToastShown: false) + Metrics.chatPillHeight
        #expect(ChatRoomPlacement.scrollContent.contentMargin(room: room) > pillTop)
        #expect(ChatRoomPlacement.bottomEdge.padding(room: room) > pillTop)
    }

    /// What a view inside the page read.
    @MainActor
    private final class SeenRoom {
        var value: CGFloat?
    }

    private struct RoomReader: View {
        let seen: SeenRoom
        @Environment(\.chatCornerRoom) private var room

        var body: some View {
            seen.value = room
            return Color.clear
        }
    }
}
