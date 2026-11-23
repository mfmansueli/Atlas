//
//  InAppEventPageHeader.swift
//  Atlas
//

import SwiftUI

/// The top of an event's page (board 40): ‹ Events back to the gallery,
/// the event's name as a menu of the others, its status, Ask Claude
/// Code…, and the event's one action: Submit Event…, Open Submission or
/// Duplicate Event.
struct InAppEventPageHeader: View {
    @Bindable var viewModel: InAppEventsViewModel
    let event: InAppEvent
    let onAction: () -> Void

    @State private var isNameHovered = false
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        HStack(spacing: Spacing.medium) {
            Button {
                viewModel.showGallery()
            } label: {
                HStack(spacing: 2) {
                    Image(systemName: "chevron.left")
                        .font(.body.weight(.semibold))
                    Text("Events")
                        .font(.body)
                }
                .foregroundStyle(Palette.accentText)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("Back to all events"))
            .accessibilityIdentifier("events.page.back")
            nameButton
            let status = viewModel.status(of: event)
            Pill(text: status.title, style: status.pillStyle)
                .fixedSize()
                .accessibilityIdentifier("events.status")
            Spacer(minLength: Spacing.small)
            HStack(spacing: Spacing.small) {
                if viewModel.isSubmitting {
                    ProgressView()
                        .controlSize(.small)
                }
                if let button = viewModel.footerButton {
                    Button(button.title, action: onAction)
                        .buttonStyle(.borderedProminent)
                        .buttonBorderShape(.capsule)
                        .disabled(!button.isEnabled)
                        .accessibilityIdentifier("events.footer.button")
                }
            }
            .fixedSize()
        }
        .frame(minHeight: 40)
    }

    private var nameButton: some View {
        Button {
            viewModel.isSwitchMenuShown.toggle()
        } label: {
            HStack(spacing: Spacing.xxSmall) {
                Text(event.referenceName)
                    .font(.title2.weight(.semibold))
                    .lineLimit(1)
                    .accessibilityIdentifier("events.title")
                Image(systemName: "chevron.down")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(Palette.label2)
            }
            .padding(.leading, Spacing.small)
            .padding(.trailing, Spacing.xSmall)
            .frame(height: 30)
            .background(
                isNameHovered || viewModel.isSwitchMenuShown ? Palette.fill2 : .clear,
                in: RoundedRectangle(cornerRadius: Radius.field, style: .continuous)
            )
            .overlay {
                if contrast == .increased {
                    RoundedRectangle(cornerRadius: Radius.field, style: .continuous).strokeBorder(Palette.label, lineWidth: 1)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.leading, -4)
        .onHover { isNameHovered = $0 }
        .help("Switch to another event")
        .accessibilityLabel(Text("Event: \(event.referenceName). Switch to another event"))
        .accessibilityIdentifier("events.page.name")
        .popover(isPresented: $viewModel.isSwitchMenuShown, arrowEdge: .bottom) {
            InAppEventSwitchMenu(viewModel: viewModel, currentID: event.id)
        }
    }
}
