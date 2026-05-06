import SwiftUI
import Combine
import AppKit

/// User-selectable chrome theme. Drives both the font and the color palette of
/// the app's UI shell — sidebar, status bar, dialogs, help window.
enum UITheme: String, CaseIterable, Identifiable {
    case system        = "System"
    case appleII40     = "Apple II (40-col)"
    case appleII80     = "Apple II (80-col)"
    case appleIIgs640  = "Apple IIgs (Shaston 640)"
    case appleIIgs320  = "Apple IIgs (Shaston 320)"
    case commodore64   = "Commodore 64"
    case vic20         = "VIC-20"
    case msDOS         = "MS-DOS"

    var id: String { rawValue }

    /// Visual family — drives colors, divider thickness, NSAppearance.
    var family: ThemeFamily {
        switch self {
        case .system:                       return .system
        case .appleII40, .appleII80:        return .appleII
        case .appleIIgs640, .appleIIgs320:  return .appleIIgs
        case .commodore64, .vic20:          return .commodore
        case .msDOS:                        return .msDOS
        }
    }

    /// Font family name registered with the font manager (nil = system font).
    var fontName: String? {
        switch self {
        case .system:        return nil
        case .appleII40:     return "PrintChar21"
        case .appleII80:     return "PRNumber3"
        case .appleIIgs640:  return "Shaston 640"
        case .appleIIgs320:  return "Shaston 320"
        case .commodore64, .vic20: return "Pet Me 64"
        case .msDOS:         return "Perfect DOS VGA 437"
        }
    }

    /// Bitmap fonts read smaller at the same point size than modern outline
    /// fonts — bump by 2pt so chrome text stays comparable in visual weight.
    var fontSizeBoost: CGFloat {
        self == .system ? 0 : 2
    }
}

/// The color/appearance family shared by one or more UITheme variants.
enum ThemeFamily {
    case system, appleII, appleIIgs, commodore, msDOS

    /// macOS appearance to apply. Affects window chrome (titlebar, scrollbars,
    /// tooltips) so it matches the in-window palette.
    var nsAppearance: NSAppearance? {
        switch self {
        case .system:    return nil
        case .appleII:   return NSAppearance(named: .darkAqua)
        case .appleIIgs: return NSAppearance(named: .aqua)
        case .commodore: return NSAppearance(named: .darkAqua)
        case .msDOS:     return NSAppearance(named: .darkAqua)
        }
    }
}

/// Singleton observable settings store. Persists the chosen theme to
/// UserDefaults and applies the matching NSApp.appearance whenever it changes.
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
        DispatchQueue.main.async {
            NSApp.appearance = self.theme.family.nsAppearance
        }
    }
}
