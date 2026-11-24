//
//  NominationAppsField.swift
//  Atlas
//

import SwiftUI

/// Apps: every app of the account, ticked when the nomination covers it.
/// The open app is always ticked; the nomination shows under each app it
/// covers.
struct NominationAppsField: View {
    let apps: [StoreApp]
    let selected: [StoreApp.ID]
    let openAppID: StoreApp.ID
    let onChange: ([StoreApp.ID]) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xSmall) {
            ForEach(apps) { app in
                let isOpen = app.id == openAppID
                Toggle(isOn: Binding { isOpen || selected.contains(app.id) } set: { isOn in
                    onChange(isOn ? selected + [app.id] : selected.filter { $0 != app.id })
                }) {
                    HStack(spacing: Spacing.small) {
                        AppIconTile(name: app.name, icon: app.icon, size: 22)
                        VStack(alignment: .leading, spacing: 0) {
                            Text(app.name)
                            Text(app.bundleID).font(.subheadline).foregroundStyle(Palette.label2)
                        }
                        if isOpen {
                            Text("This app").font(.subheadline).foregroundStyle(Palette.label2)
                        }
                    }
                }
                .toggleStyle(.checkbox)
                .disabled(isOpen)
                .accessibilityIdentifier("nominations.apps.\(app.id)")
            }
            Text("One nomination can cover several of the account’s apps. It shows in Nominations for each of them.")
                .font(.subheadline)
                .foregroundStyle(Palette.label2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
