import SwiftUI

struct PreviewView: View {
    @ObservedObject var vm: ConverterViewModel
    @ObservedObject private var appSettings = AppSettings.shared

    // Apple II display: always 280:192 regardless of column mode
    private let screenAspect = 280.0 / 192.0

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Bezel/preview-area background. Themed for retro modes;
                // falls back to the system window background under .system.
                bezelBackground

                if let result = vm.result {
                    appleScreen(result: result, available: geo.size)
                } else {
                    DropZoneView(
                        onOpenFile: { vm.openImageFilePicker() },
                        onDropProviders: { vm.loadDroppedProviders($0) }
                    )
                    .padding(40)
                }
            }
        }
    }

    @ViewBuilder
    private var bezelBackground: some View {
        if let themed = ChromeStyle(theme: appSettings.theme).background {
            themed
        } else {
            Color(NSColor.windowBackgroundColor)
        }
    }

    // MARK: - Screen frame

    @ViewBuilder
    private func appleScreen(result: ASCIIResult, available: CGSize) -> some View {
        let size = fitSize(in: available)

        ZStack {
            // Outer bezel
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(red: 0.18, green: 0.18, blue: 0.18))
                .frame(width: size.width + 24, height: size.height + 24)

            // Screen
            ZStack {
                Color.black

                if vm.isConverting {
                    ProgressView()
                        .scaleEffect(0.7)
                        .colorScheme(.dark)
                } else {
                    ASCIICanvas(result: result, settings: vm.settings)
                }
            }
            .frame(width: size.width, height: size.height)
            // Phosphor glow
            .shadow(color: vm.settings.phosphorColor.color.opacity(0.4), radius: 6)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func fitSize(in available: CGSize) -> CGSize {
        let maxW = available.width - 60
        let maxH = available.height - 60
        if maxW / screenAspect <= maxH {
            return CGSize(width: maxW, height: maxW / screenAspect)
        } else {
            return CGSize(width: maxH * screenAspect, height: maxH)
        }
    }
}

// MARK: - ASCII Canvas

struct ASCIICanvas: View {
    let result: ASCIIResult
    let settings: ConversionSettings

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            let cellW = size.width / CGFloat(result.columns)
            let cellH = size.height / CGFloat(result.rows)
            let fontSize = cellH
            let fontName = settings.columnMode.fontName
            let fgColor = settings.phosphorColor.color

            Canvas(
                opaque: true,
                colorMode: .linear,
                rendersAsynchronously: false
            ) { context, _ in
                context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.black))

                for (rowIdx, row) in result.grid.enumerated() {
                    for (colIdx, char) in row.enumerated() {
                        guard char != " " else { continue }
                        let text = Text(String(char))
                            .font(.custom(fontName, size: fontSize))
                            .foregroundColor(fgColor)
                        context.draw(
                            text,
                            at: CGPoint(
                                x: CGFloat(colIdx) * cellW,
                                y: CGFloat(rowIdx) * cellH
                            ),
                            anchor: .topLeading
                        )
                    }
                }
            }
            .frame(width: size.width, height: size.height)
        }
    }
}
