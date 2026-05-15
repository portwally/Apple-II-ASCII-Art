import Foundation
import Metal
import MetalKit
import AppKit
import CoreGraphics

/// GPU-accelerated counterpart to `ASCIIConverter`. The compute shader
/// (`AsciiShaders.metal`) does the resize + brightness/contrast + luminance
/// math in one dispatch per character grid. Output is a byte buffer of
/// luminance values (0–255) which we then map through the character ramp
/// on the CPU.
///
/// **Per-frame layout:**
///
///   1. NSImage → CGImage → MTLTexture (one upload per frame).
///   2. Encode 40-col + 80-col passes into the *same* command buffer —
///      both passes read from the same uploaded texture, so we pay the
///      CPU↔GPU sync cost exactly once per frame.
///   3. `waitUntilCompleted`, then map the luminance buffer through the
///      character ramp to build `ASCIIResult`s.
///
/// Falls back to the CPU `ASCIIConverter` if `MTLCreateSystemDefaultDevice()`
/// returns nil (e.g. running under a non-Metal sandbox or VM).
final class MetalASCIIConverter {

    /// Shared instance — nil if Metal isn't available on this system.
    /// Initialised lazily so we don't pay the pipeline-compile cost
    /// (~10 ms first time) until the first video frame is converted.
    static let shared: MetalASCIIConverter? = {
        guard let device = MTLCreateSystemDefaultDevice() else {
            print("MetalASCIIConverter: no Metal device — falling back to CPU")
            return nil
        }
        do {
            return try MetalASCIIConverter(device: device)
        } catch {
            print("MetalASCIIConverter: init failed (\(error)) — falling back to CPU")
            return nil
        }
    }()

    // MARK: - Private state

    private let device:        MTLDevice
    private let commandQueue:  MTLCommandQueue
    private let pipelineState:      MTLComputePipelineState   // text luminance
    private let loresPipelineState: MTLComputePipelineState   // LORES quantization
    private let textureLoader: MTKTextureLoader

    /// Parameters struct laid out byte-for-byte to match the Metal
    /// shader's `ConvertParams`. `MemoryLayout<ConvertParams>.stride`
    /// is what we send via `setBytes(...)` so any layout mismatch
    /// would produce visibly wrong frames immediately.
    private struct ConvertParams {
        var gridSize:   SIMD2<UInt32>
        var screenSize: SIMD2<UInt32>
        var sourceSize: SIMD2<UInt32>
        var brightness: Float
        var contrast:   Float
        var invert:     UInt32
        var flipH:      UInt32
        var flipV:      UInt32
    }

    private enum InitError: Error {
        case noCommandQueue
        case noLibrary
        case noFunction
    }

    private init(device: MTLDevice) throws {
        self.device = device

        guard let queue = device.makeCommandQueue() else { throw InitError.noCommandQueue }
        self.commandQueue = queue

        guard let library = device.makeDefaultLibrary() else { throw InitError.noLibrary }
        guard let function = library.makeFunction(name: "convertToLuminance") else {
            throw InitError.noFunction
        }
        self.pipelineState = try device.makeComputePipelineState(function: function)

        guard let loresFn = library.makeFunction(name: "convertToLores") else {
            throw InitError.noFunction
        }
        self.loresPipelineState = try device.makeComputePipelineState(function: loresFn)

        self.textureLoader = MTKTextureLoader(device: device)
    }

    // MARK: - Public API

    /// Convert a single NSImage into one or both ASCII grids
    /// (40-col + 80-col share the same texture upload).
    /// Returns `(nil, nil)` only if the GPU upload itself fails — the
    /// caller should treat this as "fall back to CPU for this frame".
    func convertBoth(
        image: NSImage,
        settings40: ConversionSettings?,
        settings80: ConversionSettings?,
        customRamp: CharacterRamp?
    ) -> (ASCIIResult?, ASCIIResult?) {

        // Need at least one of the two modes requested.
        guard settings40 != nil || settings80 != nil else { return (nil, nil) }

        // NSImage → CGImage → MTLTexture
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return (nil, nil)
        }
        let texOpts: [MTKTextureLoader.Option: Any] = [
            .SRGB: false,                                     // sample raw bytes; matches CPU `colorAt` semantics
            .textureUsage: NSNumber(value: MTLTextureUsage.shaderRead.rawValue),
        ]
        guard let texture = try? textureLoader.newTexture(cgImage: cgImage, options: texOpts) else {
            return (nil, nil)
        }

        guard let cmdBuffer = commandQueue.makeCommandBuffer() else { return (nil, nil) }

        // Encode whichever passes are requested. Both passes share the
        // command buffer so we pay one waitUntilCompleted cost.
        let pass40 = settings40.flatMap { encodePass(texture: texture, settings: $0, cmdBuffer: cmdBuffer) }
        let pass80 = settings80.flatMap { encodePass(texture: texture, settings: $0, cmdBuffer: cmdBuffer) }

        cmdBuffer.commit()
        cmdBuffer.waitUntilCompleted()

        let result40 = pass40.map { p in
            buildResult(buffer: p.buffer, cols: p.cols, rows: p.rows,
                        ramp: customRamp ?? settings40!.ramp)
        }
        let result80 = pass80.map { p in
            buildResult(buffer: p.buffer, cols: p.cols, rows: p.rows,
                        ramp: customRamp ?? settings80!.ramp)
        }
        return (result40, result80)
    }

    /// Convert a single NSImage to one or both LORES grids (40×48 LORES
    /// and/or 80×48 DLORES). Same approach as `convertBoth`: one texture
    /// upload, two GPU dispatches sharing the source, one waitUntil.
    func convertLores(
        image: NSImage,
        lores40: Bool,
        dlores80: Bool,
        settings: ConversionSettings
    ) -> (LoresFrameResult?, LoresFrameResult?) {

        guard lores40 || dlores80 else { return (nil, nil) }

        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return (nil, nil)
        }
        let texOpts: [MTKTextureLoader.Option: Any] = [
            .SRGB: false,
            .textureUsage: NSNumber(value: MTLTextureUsage.shaderRead.rawValue),
        ]
        guard let texture = try? textureLoader.newTexture(cgImage: cgImage, options: texOpts) else {
            return (nil, nil)
        }
        guard let cmdBuffer = commandQueue.makeCommandBuffer() else { return (nil, nil) }

        let pass40 = lores40
            ? encodeLoresPass(texture: texture, cols: 40, settings: settings, cmdBuffer: cmdBuffer)
            : nil
        let pass80 = dlores80
            ? encodeLoresPass(texture: texture, cols: 80, settings: settings, cmdBuffer: cmdBuffer)
            : nil

        cmdBuffer.commit()
        cmdBuffer.waitUntilCompleted()

        let result40 = pass40.map { p in buildLoresResult(buffer: p.buffer, cols: p.cols, rows: p.rows) }
        let result80 = pass80.map { p in buildLoresResult(buffer: p.buffer, cols: p.cols, rows: p.rows) }
        return (result40, result80)
    }

    // MARK: - Internals

    private struct EncodedPass {
        let buffer: MTLBuffer
        let cols:   Int
        let rows:   Int
    }

    private func encodePass(
        texture: MTLTexture,
        settings: ConversionSettings,
        cmdBuffer: MTLCommandBuffer
    ) -> EncodedPass? {

        let platform = settings.platform
        let cols = platform.columns
        let rows = settings.rowCount
        let outputBytes = cols * rows

        guard let buffer = device.makeBuffer(length: outputBytes,
                                             options: .storageModeShared) else { return nil }

        let contrastFactor: Float = settings.contrast >= 0
            ? Float(1.0 + settings.contrast * 3.0)
            : Float(1.0 + settings.contrast)

        var params = ConvertParams(
            gridSize:   SIMD2(UInt32(cols), UInt32(rows)),
            screenSize: SIMD2(UInt32(platform.screenSize.width),
                              UInt32(platform.screenSize.height)),
            sourceSize: SIMD2(UInt32(texture.width), UInt32(texture.height)),
            brightness: Float(settings.brightness * 255.0),
            contrast:   contrastFactor,
            invert:     settings.invert ? 1 : 0,
            flipH:      settings.flipHorizontal ? 1 : 0,
            flipV:      settings.flipVertical   ? 1 : 0
        )

        guard let encoder = cmdBuffer.makeComputeCommandEncoder() else { return nil }
        encoder.setComputePipelineState(pipelineState)
        encoder.setTexture(texture, index: 0)
        encoder.setBuffer(buffer, offset: 0, index: 0)
        encoder.setBytes(&params, length: MemoryLayout<ConvertParams>.stride, index: 1)

        // 8×8 threadgroups cover every grid we ship (40×24, 80×24, etc.)
        // with at most one threadgroup of slack along each axis.
        let tgSize = MTLSize(width: 8, height: 8, depth: 1)
        let groups = MTLSize(
            width:  (cols + 7) / 8,
            height: (rows + 7) / 8,
            depth:  1
        )
        encoder.dispatchThreadgroups(groups, threadsPerThreadgroup: tgSize)
        encoder.endEncoding()

        return EncodedPass(buffer: buffer, cols: cols, rows: rows)
    }

    /// Encode one LORES quantization pass into the supplied command
    /// buffer. Grid is `cols × 48`; output buffer holds one palette
    /// index byte per cell (40×48 = 1 920 bytes for LORES, 80×48 =
    /// 3 840 bytes for DLORES — well under any MTLBuffer alignment
    /// concern).
    private func encodeLoresPass(
        texture: MTLTexture,
        cols: Int,
        settings: ConversionSettings,
        cmdBuffer: MTLCommandBuffer
    ) -> EncodedPass? {
        let rows = 48
        let outputBytes = cols * rows
        guard let buffer = device.makeBuffer(length: outputBytes,
                                             options: .storageModeShared) else { return nil }

        let contrastFactor: Float = settings.contrast >= 0
            ? Float(1.0 + settings.contrast * 3.0)
            : Float(1.0 + settings.contrast)

        // Apple II native screen rect — same aspect-fill canvas as the
        // text players use, so the source crops identically whether the
        // user chose TEXT or LORES.
        var params = ConvertParams(
            gridSize:   SIMD2(UInt32(cols), UInt32(rows)),
            screenSize: SIMD2(280, 192),
            sourceSize: SIMD2(UInt32(texture.width), UInt32(texture.height)),
            brightness: Float(settings.brightness * 255.0),
            contrast:   contrastFactor,
            invert:     settings.invert ? 1 : 0,
            flipH:      settings.flipHorizontal ? 1 : 0,
            flipV:      settings.flipVertical   ? 1 : 0
        )

        guard let encoder = cmdBuffer.makeComputeCommandEncoder() else { return nil }
        encoder.setComputePipelineState(loresPipelineState)
        encoder.setTexture(texture, index: 0)
        encoder.setBuffer(buffer, offset: 0, index: 0)
        encoder.setBytes(&params, length: MemoryLayout<ConvertParams>.stride, index: 1)

        let tgSize = MTLSize(width: 8, height: 8, depth: 1)
        let groups = MTLSize(
            width:  (cols + 7) / 8,
            height: (rows + 7) / 8,
            depth:  1
        )
        encoder.dispatchThreadgroups(groups, threadsPerThreadgroup: tgSize)
        encoder.endEncoding()
        return EncodedPass(buffer: buffer, cols: cols, rows: rows)
    }

    private func buildLoresResult(buffer: MTLBuffer, cols: Int, rows: Int) -> LoresFrameResult {
        let ptr = buffer.contents().bindMemory(to: UInt8.self, capacity: cols * rows)
        var grid = [[UInt8]](repeating: [UInt8](repeating: 0, count: cols), count: rows)
        for row in 0..<rows {
            let rowBase = row * cols
            for col in 0..<cols {
                grid[row][col] = ptr[rowBase + col]
            }
        }
        return LoresFrameResult(cols: cols, rows: rows, indices: grid)
    }

    /// Map the GPU luminance buffer through the character ramp on the
    /// CPU. This loop is `cols × rows = 960` (40-col) or `1920` (80-col)
    /// pointer reads + ramp lookups — fast enough that doing it on the
    /// CPU isn't worth a second GPU pass.
    private func buildResult(buffer: MTLBuffer, cols: Int, rows: Int,
                             ramp: CharacterRamp) -> ASCIIResult {
        let lumPtr = buffer.contents().bindMemory(to: UInt8.self, capacity: cols * rows)
        var grid = [[Character]](repeating: [Character](repeating: " ", count: cols),
                                 count: rows)
        for row in 0..<rows {
            let rowBase = row * cols
            for col in 0..<cols {
                let lum = Double(lumPtr[rowBase + col]) / 255.0
                grid[row][col] = ramp.character(forBrightness: lum)
            }
        }
        return ASCIIResult(columns: cols, rows: rows, grid: grid, sourceName: "")
    }
}
