import Foundation
import AVFoundation
import AppKit
import CoreImage

/// Streams frames from a video file by reading the source in 30-second
/// **chunks**, each handled by its own fresh `AVAssetReader`.
///
/// Why chunked: single-reader strategies — `generateCGImagesAsynchronously`,
/// `image(at:)`, and even a single linear `AVAssetReader` — all silently
/// stop returning samples after the first segment of fragmented HEVC MP4
/// sources (the 34-frame / 8.5-second ceiling we kept hitting on
/// MeGusta-style x265 rips). A fresh reader scoped to each 30-second
/// window forces AVFoundation to re-seek using the file's random-access
/// index, side-stepping whatever state gets stuck.
///
/// Each yielded frame is downsampled via CIImage to ≤ 320 px on the long
/// edge — plenty of resolution for ASCII conversion, small enough that
/// the cached `[NSImage]` for re-conversion stays under ~1.5 GB even for
/// a feature-length film.
enum VideoFrameExtractor {

    enum ExtractError: Error, LocalizedError {
        case noVideoTrack
        case loadFailure(String)
        case readerFailure(String)

        var errorDescription: String? {
            switch self {
            case .noVideoTrack:         return "The file does not contain a video track."
            case .loadFailure(let m):   return "Could not load the video: \(m)"
            case .readerFailure(let m): return "Could not read video: \(m)"
            }
        }
    }

    /// `preferPreciseDurationAndTiming` forces AVFoundation to scan the
    /// full container up front — without it, fragmented MP4 sources
    /// report only the first segment's duration.
    private static let assetOptions: [String: Any] = [
        AVURLAssetPreferPreciseDurationAndTimingKey: true
    ]

    /// How big each AVAssetReader window is (seconds of source video).
    private static let chunkSeconds: Double = 30.0

    /// Cap on the downsampled long edge, in pixels.
    private static let maxFrameSide: CGFloat = 320

    /// Probe a movie file and return its duration in seconds.
    static func duration(of url: URL) async throws -> Double {
        let asset = AVURLAsset(url: url, options: assetOptions)
        let d = try await asset.load(.duration)
        return CMTimeGetSeconds(d)
    }

    /// Stream frames at the given target FPS. Each yielded tuple carries
    /// the frame index, the NSImage, and the total expected count.
    ///
    /// `durationOverride` lets the caller pass a known-good duration (in
    /// seconds) rather than have us re-load it from AVFoundation. On
    /// some fragmented-MP4 sources the asset's `.duration` property
    /// returns a different value the second time it's loaded — passing
    /// the VM's already-verified `videoDuration` removes that variability.
    static func streamFrames(
        from url: URL,
        fps: Double,
        maxFrames: Int,
        durationOverride: Double = 0
    ) -> AsyncThrowingStream<(index: Int, image: NSImage, total: Int), Error> {

        AsyncThrowingStream { continuation in
            let extractTask = Task.detached(priority: .userInitiated) {
                let asset = AVURLAsset(url: url, options: assetOptions)

                let durationCM: CMTime
                let videoTrack: AVAssetTrack
                let trackRange: CMTimeRange
                do {
                    async let d  = asset.load(.duration)
                    async let ts = asset.loadTracks(withMediaType: .video)
                    durationCM = try await d
                    let tracks = try await ts
                    appLog("VideoFrameExtractor [v4]: streamFrames called url=\(url.lastPathComponent) durationOverride=\(durationOverride) fps=\(fps) maxFrames=\(maxFrames)")
                    appLog("VideoFrameExtractor [v4]: found \(tracks.count) video track(s)")
                    guard let t = tracks.first else {
                        continuation.finish(throwing: ExtractError.noVideoTrack)
                        return
                    }
                    videoTrack = t
                    trackRange = try await t.load(.timeRange)
                } catch {
                    continuation.finish(throwing: ExtractError.loadFailure(error.localizedDescription))
                    return
                }

                // **Caller-supplied duration wins**. If the VM verified the
                // duration at load time (via `duration(of:)`) and passed
                // it in, trust that — re-loading inside AVAssetReader can
                // yield a different (smaller) number on flaky fragmented
                // MP4 sources. Otherwise fall back to whatever the asset
                // says now.
                let assetSec = CMTimeGetSeconds(durationCM)
                let trackSec = CMTimeGetSeconds(trackRange.duration)
                let durationSec: Double = {
                    if durationOverride > 0 { return durationOverride }
                    return assetSec
                }()
                let totalFromFPS = Int(floor(durationSec * fps)) + 1
                let total = max(1, min(totalFromFPS, maxFrames))

                if trackSec.isFinite && trackSec > 0 && trackSec < durationSec * 0.9 {
                    appLog("VideoFrameExtractor [v4]: ⚠️ FRAG-MP4 track=\(String(format: "%.1f", trackSec))s << using=\(String(format: "%.1f", durationSec))s")
                }
                appLog("VideoFrameExtractor [v4]: override=\(durationOverride)s asset=\(String(format: "%.3f", assetSec))s track=\(String(format: "%.3f", trackSec))s USING=\(String(format: "%.3f", durationSec))s")
                appLog("VideoFrameExtractor [v4]: totalFromFPS=\(totalFromFPS) maxFrames=\(maxFrames) TOTAL=\(total) chunks=\(max(1, Int(ceil(durationSec / chunkSeconds))))")

                let frameInterval: Double = 1.0 / fps
                let ciContext = CIContext(options: [.useSoftwareRenderer: false])
                let outputSettings: [String: Any] = [
                    kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
                ]
                let transform: CGAffineTransform =
                    (try? await videoTrack.load(.preferredTransform)) ?? .identity

                var nextIdx = 0
                var totalSamples = 0
                let totalChunks = max(1, Int(ceil(durationSec / chunkSeconds)))

                chunkLoop: for chunkIdx in 0..<totalChunks {
                    if Task.isCancelled { break }
                    if nextIdx >= total { break }

                    let chunkStart = Double(chunkIdx) * chunkSeconds
                    let chunkEnd   = min(chunkStart + chunkSeconds, durationSec)

                    // Fresh reader for this window — bypasses any state
                    // the previous reader got stuck in.
                    let reader: AVAssetReader
                    do { reader = try AVAssetReader(asset: asset) }
                    catch {
                        appLog("  chunk \(chunkIdx) reader-init FAILED: \(error.localizedDescription)")
                        continue chunkLoop
                    }
                    reader.timeRange = CMTimeRange(
                        start: CMTime(seconds: chunkStart, preferredTimescale: 600),
                        duration: CMTime(seconds: chunkEnd - chunkStart, preferredTimescale: 600)
                    )

                    let output = AVAssetReaderTrackOutput(track: videoTrack,
                                                          outputSettings: outputSettings)
                    output.alwaysCopiesSampleData = false
                    guard reader.canAdd(output) else {
                        appLog("  chunk \(chunkIdx) cannot-add-output")
                        continue chunkLoop
                    }
                    reader.add(output)

                    guard reader.startReading() else {
                        appLog("  chunk \(chunkIdx) startReading FAILED: \(reader.error?.localizedDescription ?? "no error")")
                        continue chunkLoop
                    }

                    var chunkSamples = 0
                    while reader.status == .reading, nextIdx < total {
                        if Task.isCancelled { reader.cancelReading(); break chunkLoop }

                        guard let buffer = output.copyNextSampleBuffer() else { break }
                        chunkSamples += 1
                        totalSamples += 1

                        let pts = CMSampleBufferGetPresentationTimeStamp(buffer)
                        let ptsSec = CMTimeGetSeconds(pts)
                        let target = Double(nextIdx) * frameInterval

                        if ptsSec + 0.001 >= target,
                           let pixelBuffer = CMSampleBufferGetImageBuffer(buffer) {

                            var ci = CIImage(cvPixelBuffer: pixelBuffer)
                            if !transform.isIdentity {
                                ci = ci.transformed(by: transform)
                                ci = ci.transformed(by:
                                    CGAffineTransform(translationX: -ci.extent.origin.x,
                                                      y: -ci.extent.origin.y))
                            }
                            let srcW = ci.extent.width
                            let srcH = ci.extent.height
                            let scale = min(maxFrameSide / srcW, maxFrameSide / srcH, 1.0)
                            if scale < 1.0 {
                                ci = ci.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
                            }

                            if let cg = ciContext.createCGImage(ci, from: ci.extent) {
                                let img = NSImage(cgImage: cg,
                                                  size: NSSize(width: cg.width, height: cg.height))
                                continuation.yield((nextIdx, img, total))
                                nextIdx += 1
                            }
                        }
                    }

                    let exitStatus = reader.status
                    let exitError  = reader.error?.localizedDescription
                    reader.cancelReading()

                    // Log EVERY chunk now — we need full visibility.
                    appLog("  chunk \(chunkIdx)/\(totalChunks-1) " +
                           "[\(String(format: "%.1f", chunkStart))..\(String(format: "%.1f", chunkEnd))s] " +
                           "samples=\(chunkSamples) yielded=\(nextIdx) " +
                           "status=\(exitStatus.rawValue)" +
                           (exitError != nil ? " error=\(exitError!)" : ""))
                }

                appLog("VideoFrameExtractor [v4]: DONE — extracted \(nextIdx) frames, " +
                       "\(totalSamples) samples across \(totalChunks) chunks")
                continuation.finish()
            }
            continuation.onTermination = { _ in extractTask.cancel() }
        }
    }
}
