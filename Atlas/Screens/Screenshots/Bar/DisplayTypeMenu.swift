//
//  DisplayTypeMenu.swift
//  Atlas
//

import SwiftUI

/// The display type the Sets matrix shows: the sizes Apple requires
/// (iPhone Duo's from April 2027), then the ones this app has no template
/// for, with why. In Free, the devices past iPhone and iPad say they're
/// part of Pro, and picking one opens the paywall.
struct DisplayTypeMenu: View {
    @Bindable var viewModel: ScreenshotsViewModel
    @Environment(ProGate.self) private var pro: ProGate?

    var body: some View {
        Menu {
            Section(String(localized: "Required by Apple")) {
                ForEach(viewModel.renderedDisplays) { type in
                    Toggle(isOn: selection(type)) {
                        Text(type.title)
                        Text(verbatim: subtitle(type))
                    }
                    .accessibilityIdentifier("screenshots.display.\(type.shortTitle)")
                }
            }
            let notes = viewModel.otherDisplayTypeNotes
            if !notes.isEmpty {
                Section(String(localized: "Not in this app")) {
                    ForEach(notes, id: \.0) { type, note in
                        Button {} label: {
                            Text(type.title)
                            Text(note)
                        }
                        .disabled(true)
                    }
                }
            }
        } label: {
            Label(viewModel.displayType.title, systemImage: viewModel.displayType.symbolName)
        }
        .menuStyle(.button)
        .buttonStyle(.bordered)
        .buttonBorderShape(.capsule)
        .fixedSize()
        .accessibilityLabel(Text("Display type, \(viewModel.displayType.title)"))
        .accessibilityIdentifier("screenshots.displayType")
    }

    /// The size, and "Part of Pro" for a device Free's templates don't lay out.
    private func subtitle(_ type: ScreenshotDisplayType) -> String {
        let size = Self.subtitle(type, size: viewModel.pixelSize(for: type))
        return pro.mayShow(type) ? size : size + " · " + Self.proNote
    }

    static let proNote = String(localized: "Part of Pro", comment: "kind:menu-item")

    /// "1320 × 2868 px"; iPhone Duo's "2007 × 2853 px · from April 2027".
    static func subtitle(_ type: ScreenshotDisplayType, size: PixelSize) -> String {
        guard type.upcomingRequirement != nil else { return "\(size.title) px" }
        return "\(size.title) px · " + String(localized: "from April 2027")
    }

    private func selection(_ type: ScreenshotDisplayType) -> Binding<Bool> {
        Binding {
            viewModel.displayType == type
        } set: { isOn in
            guard isOn else { return }
            if pro.mayShow(type) {
                viewModel.displayType = type
            } else {
                pro.require(.templateDevice(type.title)) { viewModel.displayType = type }
            }
        }
    }
}
