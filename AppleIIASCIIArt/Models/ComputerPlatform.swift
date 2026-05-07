import Foundation

/// Represents a classic computer's text-mode display.
/// Each case encapsulates the grid dimensions, screen pixel size (for aspect
/// ratio), font, default character ramp, and color model for that platform.
///
/// Adding a new platform requires only a new case here — the rest of the app
/// (canvas, converter, settings panel) adapts automatically.
enum ComputerPlatform: String, CaseIterable, Identifiable, Equatable, Hashable {
    case appleII40  = "Apple II (40-col)"
    case appleII80  = "Apple II (80-col)"
    case pet        = "Commodore PET"
    case c64        = "Commodore 64"
    case c128       = "Commodore 128 (80-col)"
    case vic20      = "VIC-20"
    case atari8bit  = "Atari 8-bit"
    case zxSpectrum = "ZX Spectrum"
    case amiga      = "Amiga"
    case atariST    = "Atari ST"
    case msDOS      = "MS-DOS"
    case amstradCPC = "Amstrad CPC"
    case coco       = "TRS-80 CoCo"
    case msx40      = "MSX (40-col)"
    case msx32      = "MSX (32-col)"

    var id: String { rawValue }

    // MARK: - Grid dimensions

    var columns: Int {
        switch self {
        case .appleII40, .pet, .c64, .atari8bit, .msx40:                 return 40
        case .appleII80, .c128, .amiga, .atariST, .msDOS:                return 80
        case .amstradCPC:                                                 return 40
        case .vic20:                                                      return 22
        case .zxSpectrum, .msx32:                                         return 32
        case .coco:                                                       return 32
        }
    }

    /// Native row count for this platform's text screen.
    var rows: Int {
        switch self {
        case .appleII40, .appleII80, .atari8bit, .zxSpectrum,
             .msx40, .msx32:                                              return 24
        case .pet, .c64, .c128, .amiga, .atariST, .msDOS, .amstradCPC:    return 25
        case .vic20:                                                       return 23
        case .coco:                                                        return 16
        }
    }

    // MARK: - Display

    /// Physical pixel dimensions of the original text screen.
    /// Used only to derive the correct aspect ratio for the on-screen preview.
    ///
    /// **Per-font notes** (advance/UPM ratio determines whether cells are
    /// square or rectangular at the natural rendering size = cellH):
    ///
    /// - Pet Me 64 (C64, PET): square (1.0)  → use native screen size.
    /// - Pet Me 2X (VIC-20): 2.0  → width = 2 × (height/rows) × cols = 352.
    /// - EightBit Atari (Atari 8-bit): 1.0 → native 320×192 fits 40×24.
    /// - ZX Spectrum: 1.143 → width = 1.143 × (height/rows) × cols ≈ 293.
    /// - Amiga Topaz: 0.5 (half-width chars, true 8×16) → native 640×400 ✓.
    /// - Atari ST (the .otf the user provided is square 1.0) → use 1280×400.
    /// - Perfect DOS VGA 437: ~9/16 wide (close to 0.56) → native 640×400 ≈ ok.
    var screenSize: CGSize {
        switch self {
        case .appleII40, .appleII80:  return CGSize(width: 280,  height: 192)
        case .pet:                    return CGSize(width: 320,  height: 200)
        case .c64:                    return CGSize(width: 320,  height: 200)
        case .c128:                   return CGSize(width: 320,  height: 200)
        case .vic20:                  return CGSize(width: 352,  height: 184)
        case .atari8bit:              return CGSize(width: 320,  height: 192)
        case .zxSpectrum:             return CGSize(width: 293,  height: 192)
        case .amiga:                  return CGSize(width: 640,  height: 400)
        case .atariST:                return CGSize(width: 640,  height: 400)
        case .msDOS:                  return CGSize(width: 640,  height: 400)
        case .amstradCPC:             return CGSize(width: 320,  height: 200)
        case .coco:                   return CGSize(width: 256,  height: 192)
        case .msx40:                  return CGSize(width: 240,  height: 192)
        case .msx32:                  return CGSize(width: 256,  height: 192)
        }
    }

    var aspectRatio: Double {
        screenSize.width / screenSize.height
    }

    // MARK: - Font

    /// Registered font family name bundled in the app.
    var fontName: String {
        switch self {
        case .appleII40:   return "PrintChar21"
        case .appleII80:   return "PRNumber3"
        case .pet:         return "Pet Me 64"
        case .c64:         return "Pet Me 64"
        case .c128:        return "Pet Me 128 2Y"      // half-width glyphs match C128 80-col 2:1 cell aspect
        case .vic20:       return "Pet Me 2X"          // double-width glyphs match VIC-20's wide pixels
        case .atari8bit:   return "EightBit Atari"
        case .zxSpectrum:  return "ZX Spectrum"
        case .amiga:       return "Amiga Topaz"
        case .atariST:     return "Atari ST 8x16 System Font"
        case .msDOS:       return "Perfect DOS VGA 437"
        case .amstradCPC:  return "Amstrad CPC464"
        case .coco:        return "Hot CoCo"
        case .msx40:       return "MSX Screen 0"
        case .msx32:       return "MSX Screen 1"
        }
    }

    // MARK: - Color model

    /// How this platform models its display colors.
    /// `.phosphor` for monochrome (Apple II, PET), `.palette(...)` for systems
    /// with independent foreground/background hardware palette.
    var colorMode: ColorMode {
        switch self {
        case .appleII40, .appleII80:
            return .phosphorOrPalette(name: "Apple IIgs", colors: Palettes.appleIIgs)
        case .pet:
            return .phosphor
        case .c64:
            return .palette(name: "C64",         colors: Palettes.c64)
        case .c128:
            return .palette(name: "C128",        colors: Palettes.c64)   // C128 uses the same 16-color palette
        case .vic20:
            return .palette(name: "VIC-20",      colors: Palettes.vic20)
        case .atari8bit:
            return .palette(name: "Atari 8-bit", colors: Palettes.atari8)
        case .zxSpectrum:
            return .palette(name: "ZX Spectrum", colors: Palettes.zxSpectrum)
        case .amiga:
            return .palette(name: "Amiga",       colors: Palettes.amiga)
        case .atariST:
            return .palette(name: "Atari ST",    colors: Palettes.atariST)
        case .msDOS:
            return .palette(name: "CGA",         colors: Palettes.cga)
        case .amstradCPC:
            return .palette(name: "Amstrad CPC", colors: Palettes.amstradCPC)
        case .coco:
            return .palette(name: "CoCo",        colors: Palettes.coco)
        case .msx40, .msx32:
            return .palette(name: "MSX",         colors: Palettes.msx)
        }
    }

    /// Default phosphor preset for `.phosphor` platforms.
    /// (Ignored for `.palette` platforms — they use `defaultPaletteSelection`.)
    var defaultPhosphor: ConversionSettings.ScreenColor {
        switch self {
        case .appleII40, .appleII80, .pet:  return .green
        default:                            return .green   // unused
        }
    }

    /// Default palette FG/BG indices for `.palette` and `.phosphorOrPalette`
    /// platforms.  (Ignored for the pure `.phosphor` platforms.)
    var defaultPaletteSelection: PaletteSelection {
        switch self {
        case .appleII40, .appleII80:
                          return PaletteSelection(fgIndex: 15, bgIndex: 0)   // White on Black (IIgs default)
        case .c64:        return PaletteSelection(fgIndex: 14, bgIndex: 6)   // Light Blue on Blue
        case .c128:       return PaletteSelection(fgIndex: 14, bgIndex: 6)   // Light Blue on Blue
        case .vic20:      return PaletteSelection(fgIndex: 14, bgIndex: 6)   // Light Blue on Blue
        case .atari8bit:  return PaletteSelection(fgIndex: 3,  bgIndex: 1)   // Light Blue on Dark Blue
        case .zxSpectrum: return PaletteSelection(fgIndex: 0,  bgIndex: 7)   // Black ink on White paper (BASIC default)
        case .amiga:      return PaletteSelection(fgIndex: 1,  bgIndex: 0)   // Black on Workbench Blue
        case .atariST:    return PaletteSelection(fgIndex: 0,  bgIndex: 15)  // Black on White (TOS hi-res)
        case .msDOS:      return PaletteSelection(fgIndex: 15, bgIndex: 0)   // White on Black
        case .amstradCPC: return PaletteSelection(fgIndex: 24, bgIndex: 1)   // Bright Yellow on Blue (CPC464 boot screen)
        case .coco:       return PaletteSelection(fgIndex: 0,  bgIndex: 1)   // Black on Green (CoCo BASIC default)
        case .msx40:      return PaletteSelection(fgIndex: 15, bgIndex: 4)   // White on Dark Blue (MSX BASIC default)
        case .msx32:      return PaletteSelection(fgIndex: 15, bgIndex: 4)   // White on Dark Blue
        case .pet:
            return PaletteSelection(fgIndex: 0, bgIndex: 0)                  // unused (pure phosphor)
        }
    }

    // MARK: - Defaults

    /// Default character ramp ID for this platform.
    var defaultRampID: String {
        switch self {
        case .appleII40, .appleII80:        return CharacterRamp.appleIIClassic.id
        case .pet, .c64, .c128, .vic20:     return CharacterRamp.petsciiBlocks.id
        case .msDOS:                        return CharacterRamp.cp437Blocks.id
        case .atari8bit, .zxSpectrum,
             .amiga, .atariST,
             .amstradCPC, .coco,
             .msx40, .msx32:                return CharacterRamp.standard.id
        }
    }

    // MARK: - Capabilities

    /// Whether this platform supports Apple II-specific exports
    /// (ProDOS disk image, Applesoft BASIC).
    var isAppleII: Bool {
        self == .appleII40 || self == .appleII80
    }
}
