import SwiftUI

/// Apple II green-phosphor look — black background, bright green text.
/// Mirrors BitPast's `AppleIITheme` palette (BitPast/AppSettings.swift:108-142).
enum AppleIIThemeColors {
    static let background     = Color.black
    /// Slightly lifted green-tinged black for the sidebar.
    static let secondaryBg    = Color(red: 0.05, green: 0.10, blue: 0.05)
    /// #33FF33 — canonical bright phosphor green.
    static let text           = Color(red: 0.20, green: 1.00, blue: 0.20)
    static let dimText        = Color(red: 0.10, green: 0.60, blue: 0.10)
    static let border         = Color(red: 0.20, green: 1.00, blue: 0.20)
    static let dividerThickness: CGFloat = 2
}

/// Apple IIgs GS/OS look — white background, black text, light-gray chrome.
/// Mirrors BitPast's `RetroTheme` palette (BitPast/AppSettings.swift:61-105).
enum AppleIIgsThemeColors {
    static let background     = Color.white
    static let secondaryBg    = Color(red: 0.93, green: 0.93, blue: 0.93)
    static let titleBarGray   = Color(red: 0.73, green: 0.73, blue: 0.73)
    static let text           = Color.black
    static let dimText        = Color(red: 0.30, green: 0.30, blue: 0.30)
    static let border         = Color.black
    static let dividerThickness: CGFloat = 3
}

/// Commodore 64 / VIC-20 look — classic blue background, light-blue text.
/// Colors from BitPast's `C64Theme` (BitPast/AppSettings.swift:144-173).
enum C64ThemeColors {
    /// #2E30A1 — classic C64 blue screen background.
    static let background     = Color(red: 0x2E/255.0, green: 0x30/255.0, blue: 0xA1/255.0)
    /// Slightly deeper blue for the sidebar chrome area.
    static let secondaryBg    = Color(red: 0x22/255.0, green: 0x24/255.0, blue: 0x7A/255.0)
    /// #6769DA — light blue foreground text.
    static let text           = Color(red: 0x67/255.0, green: 0x69/255.0, blue: 0xDA/255.0)
    static let dimText        = Color(red: 0x40/255.0, green: 0x42/255.0, blue: 0xB0/255.0)
    static let border         = Color(red: 0x67/255.0, green: 0x69/255.0, blue: 0xDA/255.0)
    static let dividerThickness: CGFloat = 2
}

/// MS-DOS / CP437 look — black background, white text (classic DOS prompt).
enum DOSThemeColors {
    static let background     = Color.black
    static let secondaryBg    = Color(red: 0.07, green: 0.07, blue: 0.07)
    static let text           = Color.white
    static let dimText        = Color(red: 0.65, green: 0.65, blue: 0.65)
    static let border         = Color.white
    static let dividerThickness: CGFloat = 2
}
