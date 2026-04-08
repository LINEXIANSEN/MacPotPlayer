import SwiftUI

@main
struct MacPotPlayerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var playerManager = PlayerManager.shared
    @StateObject private var preferences = PreferencesManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(playerManager)
                .environmentObject(preferences)
                .onOpenURL { url in
                    playerManager.open(url: url)
                }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .commands {
            MacPotPlayerCommands()
        }

        Settings {
            PreferencesView()
                .environmentObject(preferences)
        }
    }
}
