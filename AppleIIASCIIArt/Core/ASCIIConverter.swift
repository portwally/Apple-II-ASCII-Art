import AppKit

class ASCIIConverter {

    // Apple II display dimensions (same for both 40-col and 80-col)
    // 40-col: 40 chars × 7px = 280px wide, 24 rows × 8px = 192px tall
    // 80-col: 80 chars × 3.5px = 280px wide, same height
    private static let displayW = 280.0
    private static let displayH_perRow = 8.0

    static func convert(image: NSImage, settings: ConversionSettings, customRamp: CharacterRamp? = nil) -> ASCIIResult {
        let cols = settings.columnMode.columns
        let rows = settings.rowCount
        let ramp = customRamp ?? settings.ramp
        let sourceName = ""

        let displayH = displayH_perRow * Double(rows)
        let cellW = settings.columnMode == .forty ? 7.0 : 3.5

        // Step 1: create an NSBitmapImageRep of size (cols × rows)
        // This represents the downsampled image at character resolution.
        guard let bitmapRep = NSBitmapImageRep(
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
        guard let ctx = NSGraphicsContext(bitmapImageRep: bitmapRep) else {
            NSGraphicsContext.restoreGraphicsState()
            return empty(cols: cols, rows: rows)
        }
        NSGraphicsContext.current = ctx
        ctx.imageInterpolation = .high

        // Compute the draw rect in bitmap pixel space.
        // The bitmap (cols × rows) represents the Apple II display (displayW × displayH).
        // Each bitmap pixel corresponds to one character cell of size (cellW × 8px).
        //
        // Map source image into the Apple II display with aspect-fill (center crop),
        // then convert those display coords to bitmap coords by dividing by cell size.
        let srcSize = image.size
        let scaleX = displayW / srcSize.width
        let scaleY = displayH / srcSize.height
        let scale = max(scaleX, scaleY)

        let scaledW = srcSize.width * scale
        let scaledH = srcSize.height * scale
        let dispOffX = (displayW - scaledW) / 2.0
        let dispOffY = (displayH - scaledH) / 2.0

        // Convert display coords → bitmap pixel coords
        let destX = dispOffX / cellW
        let destY = dispOffY / displayH_perRow
        let destW = scaledW / cellW
        let destH = scaledH / displayH_perRow

        image.draw(
            in: NSRect(x: destX, y: destY, width: destW, height: destH),
            from: .zero,
            operation: .copy,
            fraction: 1.0
        )
        NSGraphicsContext.restoreGraphicsState()

        // Step 2: brightness/contrast factors (from Retro-Graphics-Converter)
        let brightnessOffset = settings.brightness * 255.0
        let contrastFactor = settings.contrast >= 0
            ? (1.0 + settings.contrast * 3.0)
            : (1.0 + settings.contrast)

        // Step 3: per-cell luminance → character
        var grid = [[Character]](repeating: [Character](repeating: " ", count: cols), count: rows)

        for row in 0..<rows {
            for col in 0..<cols {
                guard let nsColor = bitmapRep.colorAt(x: col, y: row) else { continue }
                var r = Double(nsColor.redComponent) * 255.0
                var g = Double(nsColor.greenComponent) * 255.0
                var b = Double(nsColor.blueComponent) * 255.0

                // Apply contrast then brightness
                r = max(0, min(255, (r - 128) * contrastFactor + 128 + brightnessOffset))
                g = max(0, min(255, (g - 128) * contrastFactor + 128 + brightnessOffset))
                b = max(0, min(255, (b - 128) * contrastFactor + 128 + brightnessOffset))

                // BT.709 perceptual luminance
                let lum = (0.2126 * r + 0.7152 * g + 0.0722 * b) / 255.0
                let brightness = settings.invert ? (1.0 - lum) : lum

                grid[row][col] = ramp.character(forBrightness: brightness)
            }
        }

        if settings.flipHorizontal {
            grid = grid.map { Array($0.reversed()) }
        }
        if settings.flipVertical {
            grid.reverse()
        }

        return ASCIIResult(columns: cols, rows: rows, grid: grid, sourceName: sourceName)
    }

    private static func empty(cols: Int, rows: Int) -> ASCIIResult {
        ASCIIResult(
            columns: cols,
            rows: rows,
            grid: [[Character]](repeating: [Character](repeating: " ", count: cols), count: rows),
            sourceName: ""
        )
    }
}
