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
            // Crop tool overlay
            .overlay {
                if vm.showCropTool {
                    CropToolOverlay(vm: vm)
                        .transition(.opacity)
                }
            }
            // Crop trigger button — bottom-trailing, visible whenever an image is loaded
            .overlay(alignment: .bottomTrailing) {
                if vm.sourceImage != nil && !vm.showCropTool {
                    Button { vm.showCropTool = true } label: {
                        Image(systemName: "crop")
                            .font(.system(size: 14, weight: .medium))
                            .padding(8)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .padding(14)
                    .help("Crop source image")
                    .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.18), value: vm.showCropTool)
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
        let screenBg   = vm.settings.resolvedBackground
        let glowColor  = vm.settings.resolvedForeground

        ZStack {
            // Outer bezel
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(red: 0.18, green: 0.18, blue: 0.18))
                .frame(width: size.width + 24, height: size.height + 24)

            // Screen
            ZStack {
                screenBg

                // Always show the canvas — even during conversion — so the
                // preview never blanks to a spinner and back.  The settings
                // it uses match the new platform/ramp; the grid is the old
                // result for ~30–100 ms, which is invisible in practice.
                ASCIICanvas(result: result, settings: vm.settings)

                if vm.isConverting {
                    ProgressView()
                        .scaleEffect(0.5)
                        .opacity(0.55)
                        .colorScheme(.dark)
                        .frame(maxWidth: .infinity, maxHeight: .infinity,
                               alignment: .topTrailing)
                        .padding(8)
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
            let fgColor  = settings.resolvedForeground

            // The glyph rendered at font size cellH naturally occupies a width
            // proportional to the platform's native cell aspect (nativeCellW /
            // nativeCellH). When rowCount is doubled, cellH halves but cellW
            // doesn't — so the glyph is only ~half as wide as its cell.
            // Compensate with a horizontal scale that becomes 1.0 at native
            // rows and 2.0 at 2× native rows.
            let nativeCellW = settings.platform.screenSize.width  / CGFloat(settings.platform.columns)
            let nativeCellH = settings.platform.screenSize.height / CGFloat(settings.platform.rows)
            let scaleX      = (cellW * nativeCellH) / (cellH * nativeCellW)

            Canvas(
                opaque: true,
                colorMode: .linear,
                rendersAsynchronously: false
            ) { context, _ in
                context.fill(Path(CGRect(origin: .zero, size: size)),
                             with: .color(settings.resolvedBackground))

                let baseTransform = context.transform

                for (rowIdx, row) in result.grid.enumerated() {
                    for (colIdx, char) in row.enumerated() {
                        guard char != " " else { continue }
                        let text = Text(String(char))
                            .font(.custom(fontName, size: cellH))
                            .foregroundColor(fgColor)
                        let originX = CGFloat(colIdx) * cellW
                        let originY = CGFloat(rowIdx) * cellH
                        if abs(scaleX - 1.0) < 0.001 {
                            context.draw(text,
                                         at: CGPoint(x: originX, y: originY),
                                         anchor: .topLeading)
                        } else {
                            context.transform = baseTransform
                                .translatedBy(x: originX, y: originY)
                                .scaledBy(x: scaleX, y: 1.0)
                            context.draw(text, at: .zero, anchor: .topLeading)
                        }
                    }
                }
                context.transform = baseTransform
            }
            .frame(width: size.width, height: size.height)
        }
    }
}
