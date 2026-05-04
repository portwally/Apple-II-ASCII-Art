import SwiftUI
import Combine
import AppKit

/// User-selectable chrome theme. Drives both the font and the color palette of
/// the app's UI shell — sidebar, status bar, dialogs, help window.
///
/// The 40/80 variants share the Apple II family (black bg, green text) and
/// only differ by font. The Shaston 640/320 variants share the Apple IIgs
/// family (white bg, black text) and only differ by font size.
enum UITheme: String, CaseIterable, Identifiable {
    case system        = "System"
    case appleII40     = "Apple II (40-col)"
    case appleII80     = "Apple II (80-col)"
    case appleIIgs640  = "Apple IIgs (Shaston 640)"
    case appleIIgs320  = "Apple IIgs (Shaston 320)"

    var id: String { rawValue }

    /// Visual family — drives colors, divider thickness, NSAppearance.
    var family: ThemeFamily {
        switch self {
        case .system: return .system
        case .appleII40, .appleII80: return .appleII
        case .appleIIgs640, .appleIIgs320: return .appleIIgs
        }
    }

    /// Family name registered with the font manager (or nil = system font).
    /// Verified via mdls/TTF name-table inspection of the bundled TTFs.
    var fontName: String? {
        switch self {
        case .system:        return nil
        case .appleII40:     return "PrintChar21"
        case .appleII80:     return "PRNumber3"
        case .appleIIgs640:  return "Shaston 640"
        case .appleIIgs320:  return "Shaston 320"
        }
    }

    /// Bitmap fonts read smaller at the same point size than modern outline
    /// fonts. Bumping the point size by a couple of points keeps chrome text
    /// roughly comparable in visual weight to the system theme.
    var fontSizeBoost: CGFloat {
        self == .system ? 0 : 2
    }
}

/// The look family. Multiple `UITheme` cases can share a family (e.g. the
/// Apple II 40 and 80 variants share `.appleII`).
enum ThemeFamily {
    case system, appleII, appleIIgs

    /// macOS appearance to apply for this family. Affects window chrome
    /// (titlebar, scrollbars, tooltips) so it matches the in-window theme.
    var nsAppearance: NSAppearance? {
        switch self {
        case .system:    return nil   // follow user's macOS Light/Dark setting
        case .appleII:   return NSAppearance(named: .darkAqua)
        case .appleIIgs: return NSAppearance(named: .aqua)
        }
    }
}

/// Singleton observable settings store. Persists the chosen theme to
/// UserDefaults and applies the matching NSApp.appearance whenever the
/// theme changes.
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    @Published var theme: UITheme {
        didSet {
            UserDefaults.standard.set(theme.rawValue, forKey: "uiTheme")
            applyAppearance()
        }
    }

    private init() {
        let saved = UserDefaults.standard.string(forKey: "uiTheme") ?? UITheme.system.rawValue
        self.theme = UITheme(rawValue: saved) ?? .system
        applyAppearance()
    }

    private func applyAppearance() {
        // Mutate AppKit state on the main thread.
        DispatchQueue.main.async {
            NSApp.appearance = self.theme.family.nsAppearance
        }
    }
}
