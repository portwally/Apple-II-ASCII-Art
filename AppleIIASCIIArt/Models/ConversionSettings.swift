import SwiftUI

struct ConversionSettings: Equatable {

    /// Phosphor preset for monochrome platforms (Apple II, PET).  Background
    /// is always black; only the foreground "phosphor" color varies.
    enum ScreenColor: String, CaseIterable, Identifiable {
        case green = "Green"
        case amber = "Amber"
        case white = "White"

        var id: String { rawValue }

        /// Foreground (character) color.
        var foregroundColor: Color {
            switch self {
            case .green: return Color(red: 0.2, green: 1.0,  blue: 0.0)
            case .amber: return Color(red: 1.0, green: 0.69, blue: 0.0)
            case .white: return .white
            }
        }

        /// Background color is always black for phosphor mode.
        var backgroundColor: Color { .black }
    }

    // MARK: - Stored state

    var platform: ComputerPlatform = .appleII40
    var rowCount: Int              = 24
    var selectedRampID: String     = CharacterRamp.appleIIClassic.id
    var brightness: Double         = 0.0
    var contrast: Double           = 0.0
    var invert: Bool               = false
    var flipHorizontal: Bool       = false
    var flipVertical: Bool         = false

    /// Per-platform memory of the user's last color choice during this session.
    /// Looked up by `applyPlatform(_:)` and the resolved-color computed properties.
    /// Lazily populated — missing keys fall through to the platform's default.
    private var phosphorByPlatform: [ComputerPlatform: ScreenColor]    = [:]
    private var paletteByPlatform:  [ComputerPlatform: PaletteSelection] = [:]

    // MARK: - Derived

    var ramp: CharacterRamp {
        CharacterRamp.allPresets.first { $0.id == selectedRampID } ?? .appleIIClassic
    }

    /// Foreground color used by the renderer.  Resolves through the active
    /// platform's `colorMode`.
    var resolvedForeground: Color {
        switch platform.colorMode {
        case .phosphor:
            return currentPhosphor.foregroundColor
        case .palette(_, let colors):
            let sel = currentPaletteSelection
            return colors[safe: sel.fgIndex]?.color ?? .white
        }
    }

    /// Background color used by the renderer.
    var resolvedBackground: Color {
        switch platform.colorMode {
        case .phosphor:
            return currentPhosphor.backgroundColor
        case .palette(_, let colors):
            let sel = currentPaletteSelection
            return colors[safe: sel.bgIndex]?.color ?? .black
        }
    }

    // MARK: - Phosphor / palette accessors with per-platform memory

    /// Phosphor preset for the current platform (defaults to platform's default
    /// if the user hasn't set one yet this session).
    var currentPhosphor: ScreenColor {
        get { phosphorByPlatform[platform] ?? platform.defaultPhosphor }
        set { phosphorByPlatform[platform] = newValue }
    }

    /// Palette FG/BG selection for the current platform.
    var currentPaletteSelection: PaletteSelection {
        get { paletteByPlatform[platform] ?? platform.defaultPaletteSelection }
        set { paletteByPlatform[platform] = newValue }
    }

    /// Convenience bindings for the SettingsPanel — read/write the index but
    /// preserve the other half of the selection.
    var paletteFGIndex: Int {
        get { currentPaletteSelection.fgIndex }
        set { currentPaletteSelection = PaletteSelection(fgIndex: newValue,
                                                          bgIndex: currentPaletteSelection.bgIndex) }
    }
    var paletteBGIndex: Int {
        get { currentPaletteSelection.bgIndex }
        set { currentPaletteSelection = PaletteSelection(fgIndex: currentPaletteSelection.fgIndex,
                                                          bgIndex: newValue) }
    }

    // MARK: - Platform switching

    /// Switch to a new platform, restoring this session's previously chosen
    /// colors / ramp / row count for it (or the platform's defaults if none
    /// stored yet).
    mutating func applyPlatform(_ p: ComputerPlatform) {
        platform       = p
        rowCount       = p.rows
        selectedRampID = p.defaultRampID
        // Phosphor / palette dictionaries are read on-demand by the resolved-
        // color computed properties — no further mutation needed.  If the user
        // had never visited this platform this session, the default is used.
    }
}

// MARK: - Helpers

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
