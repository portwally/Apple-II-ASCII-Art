import SwiftUI
import CoreText

/// A popover that displays every glyph available in the current platform's font.
/// Tapping a glyph appends it to `rampText`; tapping a highlighted one removes it.
/// The ramp preview at the top stays in sync with the text field in SettingsPanel.
struct CharacterPickerPopover: View {
    let fontName: String
    @Binding var rampText: String

    @State private var availableChars: [Character] = []

    private let columns = Array(
        repeating: GridItem(.fixed(28), spacing: 2),
        count: 10
    )

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            characterGrid
        }
        .frame(width: 320)
        .task(id: fontName) {
            availableChars = await loadChars(for: fontName)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 6) {
            Text("Ramp:")
                .font(.caption)
                .foregroundStyle(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                Text(rampText.isEmpty ? "—" : rampText)
                    .font(.custom(fontName, size: 13))
                    .foregroundStyle(rampText.isEmpty ? Color.secondary.opacity(0.5) : Color.primary)
                    .fixedSize()
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button("Clear all") { rampText = "" }
                .buttonStyle(.borderless)
                .font(.caption)
                .disabled(rampText.isEmpty)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }

    // MARK: - Character grid

    @ViewBuilder
    private var characterGrid: some View {
        if availableChars.isEmpty {
            ProgressView()
                .frame(width: 320, height: 220)
        } else {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 2) {
                    ForEach(availableChars, id: \.self) { char in
                        charCell(char)
                    }
                }
                .padding(8)
            }
            .frame(height: 240)
        }
    }

    // MARK: - Individual cell

    @ViewBuilder
    private func charCell(_ char: Character) -> some View {
        let isSelected = rampText.contains(char)
        Button {
            if isSelected {
                rampText.removeAll { $0 == char }
            } else {
                rampText.append(char)
            }
        } label: {
            Text(String(char))
                .font(.custom(fontName, size: 14))
                .frame(width: 26, height: 26)
                .background(isSelected ? Color.accentColor.opacity(0.25) : Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: 3)
                        .stroke(
                            isSelected ? Color.accentColor : Color.secondary.opacity(0.2),
                            lineWidth: isSelected ? 1.5 : 0.5
                        )
                )
                .clipShape(RoundedRectangle(cornerRadius: 3))
        }
        .buttonStyle(.plain)
        .help(unicodeLabel(char))
    }

    private func unicodeLabel(_ char: Character) -> String {
        guard let scalar = char.unicodeScalars.first else { return "" }
        return String(format: "U+%04X", scalar.value)
    }
}

// MARK: - Font glyph enumeration

/// Returns every printable character that the named font actually has a glyph for.
/// Runs on a background executor so it doesn't block the main thread.
private func loadChars(for fontName: String) async -> [Character] {
    await Task.detached(priority: .userInitiated) {
        let ctFont = CTFontCreateWithName(fontName as CFString, 16, nil)
        let charset = CTFontCopyCharacterSet(ctFont) as CharacterSet

        var result: [Character] = []
        // Scan all BMP code points. Skipping control characters (< 0x20) and
        // a handful of layout-only code points that render as blanks.
        for cp: UInt32 in 0x0020...0xFFFD {
            guard cp != 0x00AD,              // soft hyphen (invisible)
                  cp != 0x200B,              // zero-width space
                  let scalar = Unicode.Scalar(cp),
                  charset.contains(scalar)
            else { continue }
            result.append(Character(scalar))
        }
        return result
    }.value
}
