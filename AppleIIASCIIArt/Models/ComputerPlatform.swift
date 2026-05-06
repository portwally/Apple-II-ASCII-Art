import Foundation

/// Represents a classic computer's text-mode display.
/// Each case encapsulates the grid dimensions, screen pixel size (for aspect
/// ratio), font, and default character ramp for that platform.
///
/// Adding a new platform requires only a new case here — the rest of the app
/// (canvas, converter, settings panel) adapts automatically.
enum ComputerPlatform: String, CaseIterable, Identifiable, Equatable {
    case appleII40  = "Apple II (40-col)"
    case appleII80  = "Apple II (80-col)"
    case c64        = "Commodore 64"
    case vic20      = "VIC-20"
    case msDOS      = "MS-DOS"

    var id: String { rawValue }

    // MARK: - Grid dimensions

    var columns: Int {
        switch self {
        case .appleII40, .c64:        return 40
        case .appleII80, .msDOS:      return 80
        case .vic20:                  return 22
        }
    }

    /// Native row count for this platform's text screen.
    var rows: Int {
        switch self {
        case .appleII40, .appleII80:  return 24
        case .c64, .msDOS:            return 25
        case .vic20:                  return 23
        }
    }

    // MARK: - Display

    /// Physical pixel dimensions of the original text screen.
    /// Used only to derive the correct aspect ratio for the on-screen preview.
    var screenSize: CGSize {
        switch self {
        case .appleII40, .appleII80:  return CGSize(width: 280, height: 192)
        case .c64:                    return CGSize(width: 320, height: 200)
        case .vic20:                  return CGSize(width: 176, height: 184)
        case .msDOS:                  return CGSize(width: 640, height: 400)
        }
    }

    var aspectRatio: Double {
        screenSize.width / screenSize.height
    }

    // MARK: - Font

    /// Registered font family name bundled in the app.
    var fontName: String {
        switch self {
        case .appleII40:  return "PrintChar21"
        case .appleII80:  return "PRNumber3"
        case .c64, .vic20: return "Pet Me 64"
        case .msDOS:      return "Perfect DOS VGA 437"
        }
    }

    // MARK: - Defaults

    /// Default character ramp ID for this platform.
    var defaultRampID: String {
        switch self {
        case .appleII40, .appleII80:  return CharacterRamp.appleIIClassic.id
        case .c64, .vic20:            return CharacterRamp.petsciiBlocks.id
        case .msDOS:                  return CharacterRamp.cp437Blocks.id
        }
    }

    /// Default screen color for this platform.
    var defaultScreenColor: ConversionSettings.ScreenColor {
        switch self {
        case .appleII40, .appleII80:  return .green
        case .c64, .vic20:            return .c64Blue
        case .msDOS:                  return .white
        }
    }

    /// Screen color options that make sense for this platform.
    var availableScreenColors: [ConversionSettings.ScreenColor] {
        switch self {
        case .appleII40, .appleII80:  return [.green, .amber, .white]
        case .c64, .vic20:            return [.c64Blue, .green, .white]
        case .msDOS:                  return [.white, .green, .amber]
        }
    }

    // MARK: - Capabilities

    /// Whether this platform supports Apple II-specific exports
    /// (ProDOS disk image, Applesoft BASIC).
    var isAppleII: Bool {
        self == .appleII40 || self == .appleII80
    }
}
