import SwiftUI

/// Grid of clickable color swatches drawn from a platform's hardware palette.
/// The currently selected swatch is highlighted with a ring.
struct ColorSwatchGrid: View {
    let colors: [PaletteColor]
    @Binding var selection: Int

    private let columns = Array(
        repeating: GridItem(.flexible(), spacing: 4),
        count: 8
    )

    var body: some View {
        LazyVGrid(columns: columns, spacing: 4) {
            ForEach(colors) { paletteColor in
                Button {
                    selection = paletteColor.id
                } label: {
                    swatch(for: paletteColor)
                }
                .buttonStyle(.plain)
                .help(paletteColor.name)
            }
        }
    }

    @ViewBuilder
    private func swatch(for paletteColor: PaletteColor) -> some View {
        let isSelected = paletteColor.id == selection
        ZStack {
            RoundedRectangle(cornerRadius: 3)
                .fill(paletteColor.color)
                .aspectRatio(1, contentMode: .fit)
                .overlay(
                    RoundedRectangle(cornerRadius: 3)
                        .stroke(Color.black.opacity(0.25), lineWidth: 0.5)
                )
            if isSelected {
                RoundedRectangle(cornerRadius: 3)
                    .stroke(Color.accentColor, lineWidth: 2)
                    .padding(-1)
            }
        }
    }
}
