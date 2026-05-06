import SwiftUI

struct ConversionSettings: Equatable {

    /// Text / foreground color of the on-screen preview, plus the matching
    /// background. Named "ScreenColor" rather than "PhosphorColor" because
    /// non-Apple II platforms have non-phosphor display colors.
    enum ScreenColor: String, CaseIterable, Identifiable {
        case green   = "Green"
        case amber   = "Amber"
        case white   = "White"
        case c64Blue = "C64 Blue"

        var id: String { rawValue }

        /// Foreground (character) color.
        var foregroundColor: Color {
            switch self {
            case .green:   return Color(red: 0.2,        green: 1.0,        blue: 0.0)
            case .amber:   return Color(red: 1.0,        green: 0.69,       blue: 0.0)
            case .white:   return .white
            case .c64Blue: return Color(red: 0x67/255.0, green: 0x69/255.0, blue: 0xDA/255.0)
            }
        }

        /// Background color for the virtual screen.
        var backgroundColor: Color {
            switch self {
            case .green, .amber, .white: return .black
            case .c64Blue:               return Color(red: 0x2E/255.0,
                                                      green: 0x30/255.0,
                                                      blue: 0xA1/255.0)
            }
        }
    }

    var platform: ComputerPlatform       = .appleII40
    var rowCount: Int                    = 24
    var selectedRampID: String           = CharacterRamp.appleIIClassic.id
    var brightness: Double               = 0.0
    var contrast: Double                 = 0.0
    var invert: Bool                     = false
    var flipHorizontal: Bool             = false
    var flipVertical: Bool               = false
    var screenColor: ScreenColor         = .green

    var ramp: CharacterRamp {
        CharacterRamp.allPresets.first { $0.id == selectedRampID } ?? .appleIIClassic
    }
}
