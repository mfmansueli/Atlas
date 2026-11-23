//
//  AddAppTests.swift
//  AtlasTests
//

import Testing
@testable import Atlas

/// Add App and Accounts and keys, from the app menu.
@MainActor
@Suite("Add App and Accounts and keys")
struct AddAppTests {
    private let bruma = StoreApp(id: "1", name: "Bruma", bundleID: "com.lima.bruma")
    private let focus = StoreApp(id: "2", name: "Focus Timer", bundleID: "com.lima.focustimer")
    private let wander = StoreApp(id: "3", name: "Wanderlog", bundleID: "com.lima.wanderlog")

    @Test func listsTheTeamsAppsTheMenuDoesntShowYet() async throws {
        let services = FakeAppListServices(apps: [bruma, wander])
        let vm = AppListViewModel(services: services)
        await vm.load()
        services.apps = [bruma, focus, wander]
        #expect(try await vm.appsNotShown() == [focus])
    }

    @Test func addPutsTheAppInNameOrderAndOpensIt() async {
        let vm = AppListViewModel(services: FakeAppListServices(apps: [bruma, wander]))
        await vm.load()
        vm.add(focus)
        #expect(vm.apps == [bruma, focus, wander])
        #expect(vm.selectedAppID == focus.id)
        // Twice adds it once.
        vm.add(focus)
        #expect(vm.apps.count == 3)
    }

    @Test func aFailedReadThrows() async {
        let services = FakeAppListServices(apps: [bruma])
        let vm = AppListViewModel(services: services)
        await vm.load()
        services.error = AppStoreConnectError.unauthorized
        await #expect(throws: (any Error).self) { try await vm.appsNotShown() }
    }

    @Test func aKeysLineHasItsRoleKeyAndApps() {
        let account = TeamAccount(id: "2X9R4HXF34", name: "Northpier Studio", role: "Admin")
        #expect(AccountsSheetText.detail(for: account, appCount: 6) == "Admin · key 2X9R4HXF34 · 6 apps")
        #expect(AccountsSheetText.detail(for: account, appCount: 1) == "Admin · key 2X9R4HXF34 · 1 app")
        #expect(AccountsSheetText.detail(for: account, appCount: nil) == "Admin · key 2X9R4HXF34")
    }

    @Test func addAppNamesTheTeam() {
        #expect(AccountsSheetText.addAppSubtitle(team: "Northpier Studio") == "Apps in Northpier Studio that Atlas doesn’t show yet.")
        #expect(AccountsSheetText.addAppEmpty(team: nil) == "Every app in this team is already in Atlas.")
    }
}
