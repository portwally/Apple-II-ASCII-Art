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

    static let appleIIClassic = CharacterRamp(
        id: "appleIIClassic",
        displayName: "Apple II Classic",
        characters: Array(" .,:;+*?%SOKYH$#@MWBDQZ0UVXN")
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

    static let allPresets: [CharacterRamp] = [.appleIIClassic, .standard, .simple, .blocks]
}
