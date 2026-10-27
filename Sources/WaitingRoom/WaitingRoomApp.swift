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
            Image(systemName: manager.activeCount > 0 ? "hourglass" : "hourglass.bottomhalf.filled")
        }
        .menuBarExtraStyle(.window)
    }
}
