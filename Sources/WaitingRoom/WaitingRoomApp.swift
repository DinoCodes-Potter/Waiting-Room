import SwiftUI

@main
struct WaitingRoomApp: App {
    @StateObject private var manager = WatchManager()

    init() {
        NSApplication.shared.setActivationPolicy(.accessory)
    }

    var body: some Scene {
        MenuBarExtra {
            MenuView().environmentObject(manager)
        } label: {
            Image(systemName: manager.menuSymbol)
        }
        .menuBarExtraStyle(.window)
    }
}
