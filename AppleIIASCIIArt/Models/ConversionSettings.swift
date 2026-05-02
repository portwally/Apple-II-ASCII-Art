import SwiftUI

struct ConversionSettings: Equatable {

    enum ColumnMode: String, CaseIterable, Identifiable {
        case forty = "40-col"
        case eighty = "80-col"
        var id: String { rawValue }
        var columns: Int { self == .forty ? 40 : 80 }
        var fontName: String { self == .forty ? "PrintChar21" : "PRNumber3" }
    }

    enum PhosphorColor: String, CaseIterable, Identifiable {
        case green = "Green"
        case amber = "Amber"
        case white = "White"
        var id: String { rawValue }
        var color: Color {
            switch self {
            case .green: return Color(red: 0.2, green: 1.0, blue: 0.0)
            case .amber: return Color(red: 1.0, green: 0.69, blue: 0.0)
            case .white: return .white
            }
        }
    }

    var columnMode: ColumnMode = .forty
    var rowCount: Int = 24
    var selectedRampID: String = CharacterRamp.appleIIClassic.id
    var brightness: Double = 0.0
    var contrast: Double = 0.0
    var invert: Bool = false
    var flipHorizontal: Bool = false
    var flipVertical: Bool = false
    var phosphorColor: PhosphorColor = .green

    var ramp: CharacterRamp {
        CharacterRamp.allPresets.first { $0.id == selectedRampID } ?? .appleIIClassic
    }
}
