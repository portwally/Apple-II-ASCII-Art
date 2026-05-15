import Foundation

struct CharacterRamp: Equatable, Identifiable, Hashable {
    let id: String
    let displayName: String
    let characters: [Character]

    func character(forBrightness brightness: Double) -> Character {
        let clamped = max(0.0, min(1.0, brightness))
        let index = Int(clamped * Double(characters.count - 1))
        return characters[index]
    }

    // MARK: - Apple II presets

    /// Classic Apple II ramp built from printable ASCII characters.
    static let appleIIClassic = CharacterRamp(
        id: "appleIIClassic",
        displayName: "Apple II Classic",
        characters: Array(" .,:;+*?%SOKYH$#@MWBDQZ0UVXN")
    )

    /// Block-element ramp using PrintChar21's full Unicode block set.
    /// Gives smooth 12-level gradation with purely geometric shapes.
    static let appleIIBlocks = CharacterRamp(
        id: "appleIIBlocks",
        displayName: "Apple II Blocks",
        characters: Array(" \u{258F}\u{258E}\u{258D}\u{258C}\u{258B}\u{258A}\u{2589}\u{2591}\u{2592}\u{2593}\u{2588}")
        //          space   ▏      ▎      ▍      ▌      ▋      ▊      ▉      ░      ▒      ▓      █
    )

    static let standard = CharacterRamp(
        id: "standard",
        displayName: "Standard ASCII",
        characters: Array(" .'-_:;,^+~=<>!?ilI|1(){}[]xcvunrzJjftTLCYS7FZUVXK49PGO#EAQ&WMB@$")
    )

    static let simple = CharacterRamp(
        id: "simple",
        displayName: "Simple (10 levels)",
        characters: Array(" .:-=+*#%@")
    )

    static let blocks = CharacterRamp(
        id: "blocks",
        displayName: "Dense",
        characters: Array(" .:+o0O#@")
    )

    // MARK: - PETSCII / C64 / VIC-20 presets

    /// Block elements ordered light→dark — works beautifully with Pet Me 64.
    static let petsciiBlocks = CharacterRamp(
        id: "petsciiBlocks",
        displayName: "PETSCII Blocks",
        characters: Array(" .\u{2019}\u{258F}\u{258E}\u{258D}\u{258C}\u{2590}\u{2580}\u{2584}\u{2592}\u{2593}\u{2588}")
        //          space   .    '     ▏      ▎      ▍      ▌      ▐      ▀      ▄      ▒      ▓      █
    )

    /// Mixes classic Commodore graphic symbols for an authentic PETSCII feel.
    static let petsciiSymbols = CharacterRamp(
        id: "petsciiSymbols",
        displayName: "PETSCII Symbols",
        characters: Array(" .\u{00B7}+\u{2666}\u{25CF}\u{2660}\u{2663}\u{2592}\u{2588}")
        //          space   .    ·    +    ♦     ●     ♠     ♣     ▒     █
    )

    /// Box-drawing characters — geometric, structured look.
    static let petsciiLines = CharacterRamp(
        id: "petsciiLines",
        displayName: "PETSCII Lines",
        characters: Array(" \u{254C}\u{2500}\u{253C}\u{256C}\u{2593}\u{2588}")
        //          space    ╌      ─      ┼      ╬      ▓      █
    )

    // MARK: - CP437 / MS-DOS preset

    /// Classic DOS ANSI art palette — space + the four CP437 block characters.
    static let cp437Blocks = CharacterRamp(
        id: "cp437Blocks",
        displayName: "CP437 Blocks",
        characters: Array(" \u{2591}\u{2592}\u{2593}\u{2588}")
        //          space   ░      ▒      ▓      █
    )

    // MARK: - All presets

    static let allPresets: [CharacterRamp] = [
        // Apple II
        .appleIIClassic, .appleIIBlocks, .standard, .simple, .blocks,
        // C64 / VIC-20
        .petsciiBlocks, .petsciiSymbols, .petsciiLines,
        // MS-DOS
        .cp437Blocks,
    ]

    /// True if **every** character in the ramp is plain 7-bit ASCII
    /// printable ($20–$7E). The Apple II character ROM only knows ASCII,
    /// so any ramp containing PETSCII / CP437 / Unicode block characters
    /// gets silently replaced with spaces when written to text page 1
    /// (see `AppleIIScreenMemory.byte(for:)`). Use this to filter ramp
    /// pickers for Apple II disk exports.
    var isAppleIICompatible: Bool {
        characters.allSatisfy { ch in
            guard let v = ch.asciiValue else { return false }
            return v >= 0x20 && v < 0x7F
        }
    }

    /// Subset of `allPresets` whose characters all survive the Apple II
    /// text-screen ROM. The video converter (which always targets Apple
    /// II 40/80-col) uses this list instead of `allPresets` so users
    /// can't pick a ramp that's guaranteed to render as dots-on-blank.
    static let appleIIPresets: [CharacterRamp] = allPresets.filter { $0.isAppleIICompatible }
}
