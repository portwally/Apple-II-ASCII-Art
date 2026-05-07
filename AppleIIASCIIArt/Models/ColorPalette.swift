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
/// presets (green/amber/white).  Used by PET.
///
/// `palette` — a fixed hardware palette where the user picks foreground and
/// background indices independently (C64, VIC-20, MS-DOS, etc.).
///
/// `phosphorOrPalette` — both available; the user toggles between phosphor
/// presets and the named palette.  Used by Apple II 40/80-col so the iconic
/// green/amber/white phosphor radio is preserved while still offering the
/// IIgs 16-colour text palette for FG/BG selection.
enum ColorMode: Equatable {
    case phosphor
    case palette(name: String, colors: [PaletteColor])
    case phosphorOrPalette(name: String, colors: [PaletteColor])
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

    /// Amstrad CPC — the full firmware palette of 27 colors (3×3×3 RGB cube).
    /// Mode 1 used 4 of these, Mode 0 used 16; we expose all 27.
    static let amstradCPC: [PaletteColor] = [
        .init( 0, "Black",            0x000000),
        .init( 1, "Blue",             0x000080),
        .init( 2, "Bright Blue",      0x0000FF),
        .init( 3, "Red",              0x800000),
        .init( 4, "Magenta",          0x800080),
        .init( 5, "Mauve",            0x8000FF),
        .init( 6, "Bright Red",       0xFF0000),
        .init( 7, "Purple",           0xFF0080),
        .init( 8, "Bright Magenta",   0xFF00FF),
        .init( 9, "Green",            0x008000),
        .init(10, "Cyan",             0x008080),
        .init(11, "Sky Blue",         0x0080FF),
        .init(12, "Yellow",           0x808000),
        .init(13, "White",            0x808080),
        .init(14, "Pastel Blue",      0x8080FF),
        .init(15, "Orange",           0xFF8000),
        .init(16, "Pink",             0xFF8080),
        .init(17, "Pastel Magenta",   0xFF80FF),
        .init(18, "Bright Green",     0x00FF00),
        .init(19, "Sea Green",        0x00FF80),
        .init(20, "Bright Cyan",      0x00FFFF),
        .init(21, "Lime",             0x80FF00),
        .init(22, "Pastel Green",     0x80FF80),
        .init(23, "Pastel Cyan",      0x80FFFF),
        .init(24, "Bright Yellow",    0xFFFF00),
        .init(25, "Pastel Yellow",    0xFFFF80),
        .init(26, "Bright White",     0xFFFFFF),
    ]

    /// TRS-80 CoCo — Color Set 1 (8 colors) plus Black at index 0 so users
    /// can pick a black background.  Indices roughly match the CoCo BASIC
    /// SET command numbering shifted by 1.
    static let coco: [PaletteColor] = [
        .init( 0, "Black",      0x000000),
        .init( 1, "Green",      0x07FF00),
        .init( 2, "Yellow",     0xFFFF00),
        .init( 3, "Blue",       0x3F00FF),
        .init( 4, "Red",        0xFF0000),
        .init( 5, "Buff",       0xFFFFC8),
        .init( 6, "Cyan",       0x00FFCB),
        .init( 7, "Magenta",    0xFF00FF),
        .init( 8, "Orange",     0xFF8800),
    ]

    /// MSX — TMS9918A 16-color palette.  Index 0 (Transparent) is shown as
    /// black so the swatch is pickable.
    static let msx: [PaletteColor] = [
        .init( 0, "Transparent",   0x000000),
        .init( 1, "Black",         0x000000),
        .init( 2, "Medium Green",  0x21C842),
        .init( 3, "Light Green",   0x5EDC78),
        .init( 4, "Dark Blue",     0x5455ED),
        .init( 5, "Light Blue",    0x7D76FC),
        .init( 6, "Dark Red",      0xD4524D),
        .init( 7, "Cyan",          0x42EBF5),
        .init( 8, "Medium Red",    0xFC5554),
        .init( 9, "Light Red",     0xFF7978),
        .init(10, "Dark Yellow",   0xD4C154),
        .init(11, "Light Yellow",  0xE6CE80),
        .init(12, "Dark Green",    0x21B03B),
        .init(13, "Magenta",       0xC95BBA),
        .init(14, "Grey",          0xCCCCCC),
        .init(15, "White",         0xFFFFFF),
    ]

    /// Apple IIgs — the canonical 16 colors of the IIgs default text/SHR
    /// palette (palette 0 in the IIgs ROM). 12-bit $0RGB values expanded to
    /// 8-bit per channel.
    static let appleIIgs: [PaletteColor] = [
        .init( 0, "Black",        0x000000),
        .init( 1, "Deep Red",     0xDD0033),
        .init( 2, "Brown",        0x885500),
        .init( 3, "Orange",       0xFF6600),
        .init( 4, "Dark Green",   0x00AA00),
        .init( 5, "Dark Grey",    0x555555),
        .init( 6, "Green",        0x00DD00),
        .init( 7, "Yellow",       0xFFFF00),
        .init( 8, "Dark Blue",    0x000077),
        .init( 9, "Magenta",      0xDD22DD),
        .init(10, "Light Grey",   0xAAAAAA),
        .init(11, "Pink",         0xFF99BB),
        .init(12, "Blue",         0x2222FF),
        .init(13, "Light Blue",   0x77AAFF),
        .init(14, "Cyan",         0x66FFFF),
        .init(15, "White",        0xFFFFFF),
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
