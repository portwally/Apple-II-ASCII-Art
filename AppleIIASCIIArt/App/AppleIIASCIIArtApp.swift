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
            CommandGroup(replacing: .help) {
                OpenHelpButton()
            }
        }

        Window("1977 Help", id: "help") {
            HelpView()
        }
        .windowResizability(.contentSize)
    }
}

/// Small wrapper view so we can pull `openWindow` from the SwiftUI environment
/// inside a CommandGroup. (Environment values aren't accessible directly inside
/// the .commands closure.)
private struct OpenHelpButton: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("1977 Help") {
            openWindow(id: "help")
        }
        .keyboardShortcut("?")  // Cmd+? — the standard macOS Help shortcut
    }
}
