import SwiftUI

// MARK: - Palette types

/// One named color in a platform's authentic hardware palette.
struct PaletteColor: Identifiable, Equatable, Hashable {
    let id: Int          // index into the platform palette (matches the hardware color register)
    let name: String     // "Light Blue", "Yellow", …
    let color: Color

    init(_ id: Int, _ name: String, _ hex: UInt32) {
        self.id = id
        self.name = name
        self.color = Color(
            red:   Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >>  8) & 0xFF) / 255.0,
            blue:  Double( hex        & 0xFF) / 255.0
        )
    }
}

/// How a platform models its display colors.
///
/// `phosphor` — monochrome (black background) with a small set of named phosphor
/// presets (green/amber/white).  Used by Apple II and PET.
///
/// `palette` — a fixed hardware palette where the user picks foreground and
/// background indices independently (C64, VIC-20, MS-DOS, etc.).
enum ColorMode: Equatable {
    case phosphor
    case palette(name: String, colors: [PaletteColor])
}

/// User's current selection within a `.palette` color mode.
struct PaletteSelection: Equatable, Hashable {
    var fgIndex: Int
    var bgIndex: Int
}

// MARK: - Authentic palettes

/// Authoritative hardware palettes used across the app.  Hex values are
/// commonly cited in retro-computing references; keeping them as plain data
/// means we can swap the source palette later without touching the renderer.
enum Palettes {

    /// Commodore 64 — 16 colors.  Indices match VIC-II color register order.
    /// Background and foreground can each be any of the 16.
    static let c64: [PaletteColor] = [
        .init( 0, "Black",        0x000000),
        .init( 1, "White",        0xFFFFFF),
        .init( 2, "Red",          0x813338),
        .init( 3, "Cyan",         0x75CEC8),
        .init( 4, "Purple",       0x8E3C97),
        .init( 5, "Green",        0x56AC4D),
        .init( 6, "Blue",         0x2E30A1),
        .init( 7, "Yellow",       0xEDF171),
        .init( 8, "Orange",       0x8E5029),
        .init( 9, "Brown",        0x553800),
        .init(10, "Light Red",    0xC46C71),
        .init(11, "Dark Grey",    0x4A4A4A),
        .init(12, "Medium Grey",  0x7B7B7B),
        .init(13, "Light Green",  0xA9FF9F),
        .init(14, "Light Blue",   0x6769DA),
        .init(15, "Light Grey",   0xB2B2B2),
    ]

    /// VIC-20 — 16 colors.  Foreground was free; background was limited to the
    /// first 8 in classic mode.  We expose all 16 to both pickers — the renderer
    /// doesn't care.
    static let vic20: [PaletteColor] = [
        .init( 0, "Black",        0x000000),
        .init( 1, "White",        0xFFFFFF),
        .init( 2, "Red",          0xB61E1E),
        .init( 3, "Cyan",         0xB5E2EC),
        .init( 4, "Magenta",      0xB5174A),
        .init( 5, "Green",        0x4DC74A),
        .init( 6, "Blue",         0x2A06C1),
        .init( 7, "Yellow",       0xDAEB66),
        .init( 8, "Orange",       0xC66E3D),
        .init( 9, "Light Orange", 0xBB8E5A),
        .init(10, "Pink",         0xEDA0A0),
        .init(11, "Light Cyan",   0xC2EBF1),
        .init(12, "Light Purple", 0xD593CA),
        .init(13, "Light Green",  0x92E2A6),
        .init(14, "Light Blue",   0x76A6F7),
        .init(15, "Light Yellow", 0xF8F39C),
    ]

    /// IBM PC CGA — 16 colors.  Standard 16-color "high intensity" palette.
    static let cga: [PaletteColor] = [
        .init( 0, "Black",         0x000000),
        .init( 1, "Blue",          0x0000AA),
        .init( 2, "Green",         0x00AA00),
        .init( 3, "Cyan",          0x00AAAA),
        .init( 4, "Red",           0xAA0000),
        .init( 5, "Magenta",       0xAA00AA),
        .init( 6, "Brown",         0xAA5500),
        .init( 7, "Light Grey",    0xAAAAAA),
        .init( 8, "Dark Grey",     0x555555),
        .init( 9, "Light Blue",    0x5555FF),
        .init(10, "Light Green",   0x55FF55),
        .init(11, "Light Cyan",    0x55FFFF),
        .init(12, "Light Red",     0xFF5555),
        .init(13, "Light Magenta", 0xFF55FF),
        .init(14, "Yellow",        0xFFFF55),
        .init(15, "White",         0xFFFFFF),
    ]

    // MARK: - Future platforms (data ready, used once their ComputerPlatform
    // case is added in a follow-up pass)

    /// Atari 8-bit — 16 popular text-mode colors selected from the full 256.
    static let atari8: [PaletteColor] = [
        .init( 0, "Black",         0x000000),
        .init( 1, "Dark Blue",     0x0000A0),
        .init( 2, "Blue",          0x0046C0),
        .init( 3, "Light Blue",    0x4080F0),
        .init( 4, "Cyan",          0x40C0C0),
        .init( 5, "Green",         0x008000),
        .init( 6, "Light Green",   0x40C040),
        .init( 7, "Yellow Green",  0xC0C040),
        .init( 8, "Yellow",        0xF0F040),
        .init( 9, "Orange",        0xE08040),
        .init(10, "Red",           0xC04040),
        .init(11, "Light Red",     0xF08080),
        .init(12, "Magenta",       0xC040C0),
        .init(13, "Brown",         0x804020),
        .init(14, "Light Grey",    0xC0C0C0),
        .init(15, "White",         0xFFFFFF),
    ]

    /// ZX Spectrum — 8 normal + 8 bright (index 0–7 normal, 8–15 bright).
    /// Black is identical in both halves on real hardware; we keep the
    /// duplicated entry so users can see the canonical 16-cell layout.
    static let zxSpectrum: [PaletteColor] = [
        .init( 0, "Black",          0x000000),
        .init( 1, "Blue",           0x0000C8),
        .init( 2, "Red",            0xC80000),
        .init( 3, "Magenta",        0xC800C8),
        .init( 4, "Green",          0x00C800),
        .init( 5, "Cyan",           0x00C8C8),
        .init( 6, "Yellow",         0xC8C800),
        .init( 7, "White",          0xC8C8C8),
        .init( 8, "Bright Black",   0x000000),
        .init( 9, "Bright Blue",    0x0000FF),
        .init(10, "Bright Red",     0xFF0000),
        .init(11, "Bright Magenta", 0xFF00FF),
        .init(12, "Bright Green",   0x00FF00),
        .init(13, "Bright Cyan",    0x00FFFF),
        .init(14, "Bright Yellow",  0xFFFF00),
        .init(15, "Bright White",   0xFFFFFF),
    ]

    /// Amiga — Workbench 1.x default 4-color palette extended with Workbench 2.x
    /// system grey scheme (8 entries total).
    static let amiga: [PaletteColor] = [
        .init( 0, "Workbench Blue", 0x0055AA),
        .init( 1, "Black",          0x000000),
        .init( 2, "White",          0xFFFFFF),
        .init( 3, "Orange",         0xFF8800),
        .init( 4, "Light Grey",     0xAAAAAA),
        .init( 5, "Dark Grey",      0x555555),
        .init( 6, "Steel Blue",     0x6688AA),
        .init( 7, "Sand",           0xFFAA77),
    ]

    /// Atari ST — TOS low-res 16 with hi-res monochrome (black/white) at the
    /// natural ends so they're easy to pick.
    static let atariST: [PaletteColor] = [
        .init( 0, "Black",          0x000000),
        .init( 1, "Red",            0xFF0000),
        .init( 2, "Green",          0x00FF00),
        .init( 3, "Yellow",         0xFFFF00),
        .init( 4, "Blue",           0x0000FF),
        .init( 5, "Magenta",        0xFF00FF),
        .init( 6, "Cyan",           0x00FFFF),
        .init( 7, "Light Grey",     0xAAAAAA),
        .init( 8, "Dark Grey",      0x555555),
        .init( 9, "Light Red",      0xFF5555),
        .init(10, "Light Green",    0x55FF55),
        .init(11, "Light Yellow",   0xFFFF55),
        .init(12, "Light Blue",     0x5555FF),
        .init(13, "Light Magenta",  0xFF55FF),
        .init(14, "Light Cyan",     0x55FFFF),
        .init(15, "White",          0xFFFFFF),
    ]
}
