import SwiftUI

/// Semantic role of a piece of chrome text. Each role maps to a base point
/// size; the actual `Font` is resolved per-theme by `ChromeStyle`.
enum ChromeRole {
    case headline   // section titles
    case body       // standard labels
    case caption    // small hints
    case footnote   // status bar / tiny text

    var systemSize: CGFloat {
        switch self {
        case .headline: return 13
        case .body:     return 12
        case .caption:  return 11
        case .footnote: return 11
        }
    }
}

enum ChromeForegroundKind { case primary, secondary }
enum ChromeBackgroundKind { case main, sidebar }

/// Pure value type that translates a `UITheme` into the concrete `Font` and
/// `Color` values consumed by the chrome view modifiers.
///
/// For `.system`, color accessors return `nil` — the modifiers fall back to
/// SwiftUI's default colors so the modern macOS look is preserved exactly.
struct ChromeStyle {
    let theme: UITheme

    func font(_ role: ChromeRole) -> Font {
        let size = role.systemSize + theme.fontSizeBoost
        if let name = theme.fontName {
            return .custom(name, size: size)
        }
        return role == .headline
            ? .system(size: size, weight: .semibold)
            : .system(size: size)
    }

    var background: Color? {
        switch theme.family {
        case .system:    return nil
        case .appleII:   return AppleIIThemeColors.background
        case .appleIIgs: return AppleIIgsThemeColors.background
        }
    }

    var sidebarBackground: Color? {
        switch theme.family {
        case .system:    return nil
        case .appleII:   return AppleIIThemeColors.secondaryBg
        case .appleIIgs: return AppleIIgsThemeColors.secondaryBg
        }
    }

    var foreground: Color? {
        switch theme.family {
        case .system:    return nil
        case .appleII:   return AppleIIThemeColors.text
        case .appleIIgs: return AppleIIgsThemeColors.text
        }
    }

    var dimForeground: Color? {
        switch theme.family {
        case .system:    return nil
        case .appleII:   return AppleIIThemeColors.dimText
        case .appleIIgs: return AppleIIgsThemeColors.dimText
        }
    }

    var border: Color? {
        switch theme.family {
        case .system:    return nil
        case .appleII:   return AppleIIThemeColors.border
        case .appleIIgs: return AppleIIgsThemeColors.border
        }
    }
}

// MARK: - View modifiers

extension View {
    /// Apply the themed font for a given chrome role. Equivalent to
    /// `.font(.headline)` etc. but routes through the user's theme picker.
    func chromeFont(_ role: ChromeRole) -> some View {
        modifier(ChromeFontModifier(role: role))
    }

    /// Apply the themed text color (primary or dim/secondary). Falls back to
    /// SwiftUI's `.primary`/`.secondary` under the system theme.
    func chromeForeground(_ kind: ChromeForegroundKind = .primary) -> some View {
        modifier(ChromeForegroundModifier(kind: kind))
    }

    /// Apply the themed background. Under the system theme this is a no-op so
    /// SwiftUI's default `.windowBackgroundColor` etc. still wins.
    func chromeBackground(_ kind: ChromeBackgroundKind = .main) -> some View {
        modifier(ChromeBackgroundModifier(kind: kind))
    }
}

private struct ChromeFontModifier: ViewModifier {
    @ObservedObject var settings = AppSettings.shared
    let role: ChromeRole
    func body(content: Content) -> some View {
        content.font(ChromeStyle(theme: settings.theme).font(role))
    }
}

private struct ChromeForegroundModifier: ViewModifier {
    @ObservedObject var settings = AppSettings.shared
    let kind: ChromeForegroundKind
    func body(content: Content) -> some View {
        let style = ChromeStyle(theme: settings.theme)
        let themed = (kind == .primary) ? style.foreground : style.dimForeground
        if let themed {
            content.foregroundColor(themed)
        } else {
            content.foregroundColor(kind == .primary ? .primary : .secondary)
        }
    }
}

private struct ChromeBackgroundModifier: ViewModifier {
    @ObservedObject var settings = AppSettings.shared
    let kind: ChromeBackgroundKind
    @ViewBuilder
    func body(content: Content) -> some View {
        let style = ChromeStyle(theme: settings.theme)
        let themed = (kind == .main) ? style.background : style.sidebarBackground
        if let themed {
            content.background(themed)
        } else {
            content
        }
    }
}
