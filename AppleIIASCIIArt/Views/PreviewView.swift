import SwiftUI

struct PreviewView: View {
    @ObservedObject var vm: ConverterViewModel
    @ObservedObject private var appSettings = AppSettings.shared

    var body: some View {
        GeometryReader { geo in
            ZStack {
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
        let size       = fitSize(in: available)
        let screenBg   = vm.settings.screenColor.backgroundColor
        let glowColor  = vm.settings.screenColor.foregroundColor

        ZStack {
            // Outer bezel
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(red: 0.18, green: 0.18, blue: 0.18))
                .frame(width: size.width + 24, height: size.height + 24)

            // Screen
            ZStack {
                screenBg

                if vm.isConverting {
                    ProgressView()
                        .scaleEffect(0.7)
                        .colorScheme(.dark)
                } else {
                    ASCIICanvas(result: result, settings: vm.settings)
                }
            }
            .frame(width: size.width, height: size.height)
            // Screen glow
            .shadow(color: glowColor.opacity(0.4), radius: 6)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func fitSize(in available: CGSize) -> CGSize {
        let aspect = vm.settings.platform.aspectRatio
        let maxW   = available.width  - 60
        let maxH   = available.height - 60
        if maxW / aspect <= maxH {
            return CGSize(width: maxW, height: maxW / aspect)
        } else {
            return CGSize(width: maxH * aspect, height: maxH)
        }
    }
}

// MARK: - ASCII Canvas

struct ASCIICanvas: View {
    let result: ASCIIResult
    let settings: ConversionSettings

    var body: some View {
        GeometryReader { geo in
            let size     = geo.size
            let cellW    = size.width  / CGFloat(result.columns)
            let cellH    = size.height / CGFloat(result.rows)
            let fontName = settings.platform.fontName
            let fgColor  = settings.screenColor.foregroundColor

            Canvas(
                opaque: true,
                colorMode: .linear,
                rendersAsynchronously: false
            ) { context, _ in
                context.fill(Path(CGRect(origin: .zero, size: size)),
                             with: .color(settings.screenColor.backgroundColor))

                for (rowIdx, row) in result.grid.enumerated() {
                    for (colIdx, char) in row.enumerated() {
                        guard char != " " else { continue }
                        let text = Text(String(char))
                            .font(.custom(fontName, size: cellH))
                            .foregroundColor(fgColor)
                        context.draw(
                            text,
                            at: CGPoint(x: CGFloat(colIdx) * cellW,
                                        y: CGFloat(rowIdx) * cellH),
                            anchor: .topLeading
                        )
                    }
                }
            }
            .frame(width: size.width, height: size.height)
        }
    }
}
