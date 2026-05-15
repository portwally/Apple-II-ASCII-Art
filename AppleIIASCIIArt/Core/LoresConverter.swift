import AppKit

/// CPU fallback path for LORES / Double-LORES quantization. The Metal
/// path (`MetalASCIIConverter.convertLores`) is the production code; this
/// is used only when `MetalASCIIConverter.shared` is nil or the texture
/// upload fails.
///
/// Output grid is `cols × 48` palette-index bytes (LORES = 40 cols,
/// DLORES = 80 cols). Brightness / contrast / flip / invert are applied
/// the same way `ASCIIConverter` applies them, then each pixel is
/// quantized to the closest of the 16 LORES colors via
/// `AppleIILoresPalette.closestIndex(r:g:b:)`.
enum LoresConverter {

    /// Apple II native screen resolution used as the aspect-fill canvas
    /// (matches `ComputerPlatform.appleII40.screenSize`).
    private static let screen = CGSize(width: 280, height: 192)

    static func convert(image: NSImage,
                        cols: Int,           // 40 (LORES) or 80 (DLORES)
                        settings: ConversionSettings) -> LoresFrameResult {

        let rows = 48
        let cellW = screen.width  / Double(cols)
        let cellH = screen.height / Double(rows)

        // Step 1 — render source into a (cols × 48) bitmap with aspect-fill.
        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: cols,
            pixelsHigh: rows,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .calibratedRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            return empty(cols: cols, rows: rows)
        }

        NSGraphicsContext.saveGraphicsState()
        guard let ctx = NSGraphicsContext(bitmapImageRep: bitmap) else {
            NSGraphicsContext.restoreGraphicsState()
            return empty(cols: cols, rows: rows)
        }
        NSGraphicsContext.current = ctx
        ctx.imageInterpolation = .high

        let srcSize = image.size
        let scaleX  = screen.width  / srcSize.width
        let scaleY  = screen.height / srcSize.height
        let scale   = max(scaleX, scaleY)
        let scaledW = srcSize.width  * scale
        let scaledH = srcSize.height * scale
        let dispOffX = (screen.width  - scaledW) / 2.0
        let dispOffY = (screen.height - scaledH) / 2.0

        let destX = dispOffX / cellW
        let destY = dispOffY / cellH
        let destW = scaledW  / cellW
        let destH = scaledH  / cellH

        image.draw(
            in: NSRect(x: destX, y: destY, width: destW, height: destH),
            from: .zero,
            operation: .copy,
            fraction: 1.0
        )
        NSGraphicsContext.restoreGraphicsState()

        // Step 2 — per-pixel brightness/contrast + quantization to palette.
        let brightnessOffset = settings.brightness * 255.0
        let contrastFactor   = settings.contrast >= 0
            ? (1.0 + settings.contrast * 3.0)
            : (1.0 + settings.contrast)

        var grid = [[UInt8]](repeating: [UInt8](repeating: 0, count: cols),
                             count: rows)

        for row in 0..<rows {
            for col in 0..<cols {
                guard let c = bitmap.colorAt(x: col, y: row) else { continue }

                var r = Double(c.redComponent)   * 255.0
                var g = Double(c.greenComponent) * 255.0
                var b = Double(c.blueComponent)  * 255.0

                r = max(0, min(255, (r - 128) * contrastFactor + 128 + brightnessOffset))
                g = max(0, min(255, (g - 128) * contrastFactor + 128 + brightnessOffset))
                b = max(0, min(255, (b - 128) * contrastFactor + 128 + brightnessOffset))

                if settings.invert {
                    r = 255 - r; g = 255 - g; b = 255 - b
                }

                grid[row][col] = AppleIILoresPalette.closestIndex(
                    r: UInt8(r), g: UInt8(g), b: UInt8(b)
                )
            }
        }

        if settings.flipHorizontal { grid = grid.map { Array($0.reversed()) } }
        if settings.flipVertical   { grid.reverse() }

        return LoresFrameResult(cols: cols, rows: rows, indices: grid)
    }

    private static func empty(cols: Int, rows: Int) -> LoresFrameResult {
        LoresFrameResult(
            cols: cols, rows: rows,
            indices: [[UInt8]](repeating: [UInt8](repeating: 0, count: cols),
                               count: rows)
        )
    }
}
