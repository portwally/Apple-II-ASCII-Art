import SwiftUI

@main
struct AppleIIASCIIArtApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(replacing: .newItem) {
                // Suppress Cmd+N (no new document concept here)
            }
        }
    }
}
