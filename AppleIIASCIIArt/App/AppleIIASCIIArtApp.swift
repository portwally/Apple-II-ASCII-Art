import SwiftUI
import CoreText

@main
struct AppleIIASCIIArtApp: App {

    init() {
        // Register every .ttf and .otf in the app bundle so SwiftUI's
        // .font(.custom()) can find them reliably.  INFOPLIST_KEY_ATSApplicationFontsPath
        // is set in the build settings but Xcode does not inject
        // ATSApplicationFontsPath into the generated Info.plist for macOS
        // targets, so we fall back to programmatic registration here — which
        // is guaranteed to work.
        for ext in ["ttf", "otf"] {
            if let urls = Bundle.main.urls(forResourcesWithExtension: ext, subdirectory: nil) {
                for url in urls {
                    CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
                }
            }
        }
    }

    var body: some Scene {
        // Singleton main window — Window (not WindowGroup) so closing it just
        // hides the window and leaves the app running, and openWindow(id: "main")
        // re-opens it.
        Window("1977", id: "main") {
            ContentView()
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .commands {
            // App menu (named "1977"): "Show 1977 Window" right after About.
            // Lets the user re-open the main window if they closed it — Apple
            // requires this for non-document apps.
            CommandGroup(after: .appInfo) {
                Divider()
                ShowMainWindowButton()
            }

            // Suppress File > New (no document concept here).
            CommandGroup(replacing: .newItem) { }

            // Help menu: "1977 Help" (Cmd+?) opens the help window.
            CommandGroup(replacing: .help) {
                OpenHelpButton()
            }
        }

        // Video converter window — separate from the image converter so its
        // long-running frame-extraction / disk-export workflow doesn't fight
        // with the image converter's UI.  Opened from the main toolbar's
        // "Movie…" button.
        Window("1977 Video", id: "video") {
            VideoConverterView()
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .defaultSize(width: 1000, height: 680)

        // Help window — also a singleton.
        Window("1977 Help", id: "help") {
            HelpView()
        }
        .windowResizability(.contentSize)

        // Settings scene — auto-installs "1977 → Settings…" with Cmd+,.
        Settings {
            SettingsView()
        }
    }
}

/// "Show 1977 Window" button in the 1977 application menu. Wrapped in its
/// own view so we can pull `openWindow` from the SwiftUI environment (env
/// values aren't accessible directly inside the .commands closure).
private struct ShowMainWindowButton: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("Show 1977 Window") {
            openWindow(id: "main")
        }
    }
}

/// "1977 Help" button in the Help menu.
private struct OpenHelpButton: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("1977 Help") {
            openWindow(id: "help")
        }
        .keyboardShortcut("?")  // Cmd+? — the standard macOS Help shortcut
    }
}
