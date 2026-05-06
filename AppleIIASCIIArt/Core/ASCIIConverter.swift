import AppKit

class ASCIIConverter {

    static func convert(image: NSImage,
                        settings: ConversionSettings,
                        customRamp: CharacterRamp? = nil) -> ASCIIResult {
        let platform = settings.platform
        let cols = platform.columns
        let rows = settings.rowCount
        let ramp = customRamp ?? settings.ramp

        // Physical screen size of the target platform — used to derive the
        // correct aspect ratio and cell dimensions for sampling the source image.
        let screenSize = platform.screenSize
        let cellW = screenSize.width  / Double(cols)
        let cellH = screenSize.height / Double(rows)

        // Step 1: create an NSBitmapImageRep of size (cols × rows).
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

        // Map source image into the platform screen with aspect-fill (center crop),
        // then convert display coords → bitmap pixel coords by dividing by cell size.
        let srcSize = image.size
        let scaleX = screenSize.width  / srcSize.width
        let scaleY = screenSize.height / srcSize.height
        let scale  = max(scaleX, scaleY)

        let scaledW  = srcSize.width  * scale
        let scaledH  = srcSize.height * scale
        let dispOffX = (screenSize.width  - scaledW) / 2.0
        let dispOffY = (screenSize.height - scaledH) / 2.0

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

        // Step 2: brightness/contrast factors
        let brightnessOffset = settings.brightness * 255.0
        let contrastFactor = settings.contrast >= 0
            ? (1.0 + settings.contrast * 3.0)
            : (1.0 + settings.contrast)

        // Step 3: per-cell luminance → character
        var grid = [[Character]](repeating: [Character](repeating: " ", count: cols), count: rows)

        for row in 0..<rows {
            for col in 0..<cols {
                guard let nsColor = bitmapRep.colorAt(x: col, y: row) else { continue }
                var r = Double(nsColor.redComponent)   * 255.0
                var g = Double(nsColor.greenComponent) * 255.0
                var b = Double(nsColor.blueComponent)  * 255.0

                r = max(0, min(255, (r - 128) * contrastFactor + 128 + brightnessOffset))
                g = max(0, min(255, (g - 128) * contrastFactor + 128 + brightnessOffset))
                b = max(0, min(255, (b - 128) * contrastFactor + 128 + brightnessOffset))

                let lum = (0.2126 * r + 0.7152 * g + 0.0722 * b) / 255.0
                let brightness = settings.invert ? (1.0 - lum) : lum

                grid[row][col] = ramp.character(forBrightness: brightness)
            }
        }

        if settings.flipHorizontal { grid = grid.map { Array($0.reversed()) } }
        if settings.flipVertical   { grid.reverse() }

        return ASCIIResult(columns: cols, rows: rows, grid: grid, sourceName: "")
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
