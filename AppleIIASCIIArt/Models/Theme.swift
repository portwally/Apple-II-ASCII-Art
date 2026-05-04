import SwiftUI

/// Apple II green-phosphor look — black background, bright green text.
/// Mirrors BitPast's `AppleIITheme` palette (BitPast/AppSettings.swift:108-142).
enum AppleIIThemeColors {
    static let background     = Color.black
    /// Slightly lifted green-tinged black for the sidebar so it reads as a
    /// distinct chrome zone without breaking the phosphor illusion.
    static let secondaryBg    = Color(red: 0.05, green: 0.10, blue: 0.05)
    /// #33FF33 — the canonical bright phosphor green.
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
    /// GS/OS title-bar gray.
    static let titleBarGray   = Color(red: 0.73, green: 0.73, blue: 0.73)
    static let text           = Color.black
    static let dimText        = Color(red: 0.30, green: 0.30, blue: 0.30)
    static let border         = Color.black
    static let dividerThickness: CGFloat = 3
}
