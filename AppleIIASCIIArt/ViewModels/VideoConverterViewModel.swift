import SwiftUI
import Combine
import UniformTypeIdentifiers
import AVFoundation

/// Which Apple II text mode(s) to include on the exported disk.
enum VideoColMode: String, CaseIterable, Identifiable {
    case col40 = "40-col only"
    case col80 = "80-col only"
    case both  = "Both 40 + 80"
    var id: String { rawValue }

    var includes40: Bool { self == .col40 || self == .both }
    var includes80: Bool { self == .col80 || self == .both }

    /// Bytes per frame counted against the disk capacity. When both modes
    /// are shipped, each frame's storage = 1 KB (40-col) + 2 KB (80-col).
    var bytesPerFrame: Int {
        var total = 0
        if includes40 { total += 1024 }
        if includes80 { total += 2048 }
        return total
    }
}

/// Drives the video-converter window: video loading, frame extraction,
/// per-frame ASCII conversion, preview scrubbing, and disk export.
@MainActor
final class VideoConverterViewModel: ObservableObject {

    // MARK: - Inputs

    @Published var videoURL:        URL?
    @Published var videoName:       String  = ""
    @Published var videoDuration:   Double  = 0      // seconds

    @Published var targetFPS:       Double  = 4      // 1, 2, 4, 6, 8
    @Published var diskFormat:      DiskImageFormat = .po140
    @Published var colMode:         VideoColMode    = .both

    @Published var settings:        ConversionSettings = {
        var s = ConversionSettings()
        s.platform = .appleII40
        return s
    }()
    @Published var useCustomRamp:   Bool    = false
    @Published var customRampText:  String  = " .:-=+*#%@"

    @Published var previewFrameIndex: Int = 0
    @Published var previewUses80:    Bool = false    // toggle between 40/80 preview
    @Published var isPlaying:        Bool = false    // in-app preview playback

    // MARK: - Outputs / state

    @Published var rawFrames:       [NSImage]     = []
    @Published var frames40:        [ASCIIResult] = []
    @Published var frames80:        [ASCIIResult] = []

    @Published var isExtracting:    Bool   = false
    @Published var isConverting:    Bool   = false
    @Published var isExporting:     Bool   = false
    @Published var progress:        Double = 0     // 0–1
    @Published var statusMessage:   String = ""
    @Published var errorMessage:    String?

    // MARK: - Computed

    /// Frames the chosen disk format can hold (with our overhead estimate).
    var maxFrames: Int {
        diskFormat.maxFrames(bytesPerFrame: colMode.bytesPerFrame)
    }

    /// Frames we'll actually export (whichever is smaller).
    var frameCount: Int {
        min(rawFrames.count, maxFrames)
    }

    /// Estimated playback duration in seconds.
    var estimatedDuration: Double {
        guard targetFPS > 0 else { return 0 }
        return Double(frameCount) / targetFPS
    }

    /// Frames-by-bytes approximation for the disk-usage readout.
    var diskUsageBytes: Int {
        frameCount * colMode.bytesPerFrame
    }

    var effectiveRamp: CharacterRamp {
        if useCustomRamp {
            let chars = Array(customRampText).filter { !$0.isNewline }
            return CharacterRamp(id: "custom", displayName: "Custom",
                                 characters: chars.isEmpty ? [" "] : chars)
        }
        return settings.ramp
    }

    /// Frame to render in the preview pane (handles 40/80 toggle and empty).
    var previewFrame: ASCIIResult? {
        let list = previewUses80 ? frames80 : frames40
        guard !list.isEmpty else { return nil }
        let idx = min(max(0, previewFrameIndex), list.count - 1)
        return list[idx]
    }

    /// The settings to pass to ASCIICanvas — same as `settings` but
    /// platform reflects the preview toggle so the canvas uses the
    /// right font / cell math for whatever it's drawing.
    var previewSettings: ConversionSettings {
        var s = settings
        s.platform = previewUses80 ? .appleII80 : .appleII40
        return s
    }

    // MARK: - Reactive plumbing

    private var cancellables = Set<AnyCancellable>()
    private var reconvertTask: Task<Void, Never>?
    private var playbackTask: Task<Void, Never>?

    init() {
        // Debounced re-convert on any settings change once frames are loaded.
        $settings
            .debounce(for: .milliseconds(150), scheduler: RunLoop.main)
            .dropFirst()
            .sink { [weak self] _ in self?.reconvertExistingFrames() }
            .store(in: &cancellables)

        $useCustomRamp
            .dropFirst()
            .sink { [weak self] _ in self?.reconvertExistingFrames() }
            .store(in: &cancellables)

        $customRampText
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .dropFirst()
            .sink { [weak self] _ in
                guard let self else { return }
                if self.useCustomRamp { self.reconvertExistingFrames() }
            }
            .store(in: &cancellables)

        $colMode
            .dropFirst()
            .sink { [weak self] mode in
                guard let self else { return }
                // Hide the 80-col preview toggle if mode no longer includes it.
                if !mode.includes80 { self.previewUses80 = false }
                if !mode.includes40 { self.previewUses80 = true  }
                self.reconvertExistingFrames()
            }
            .store(in: &cancellables)
    }

    // MARK: - Video loading

    /// Show the open panel and load the chosen file. Restricted to MP4
    /// and MOV containers — everything else (MKV, WebM, FLV, etc.) is
    /// greyed out, since AVFoundation on macOS can't reliably decode
    /// those without third-party codecs.
    func openVideoFilePicker() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes     = [.mpeg4Movie, .quickTimeMovie]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories    = false
        panel.message                 = "Choose an MP4 or MOV file."
        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            Task { @MainActor in await self?.loadVideo(from: url) }
        }
    }

    /// Drop-handler version: accept the first .fileURL provider.
    func loadDroppedProviders(_ providers: [NSItemProvider]) {
        guard let p = providers.first else { return }
        if p.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            p.loadItem(forTypeIdentifier: UTType.fileURL.identifier) { [weak self] item, _ in
                let url: URL? = {
                    if let u = item as? URL { return u }
                    if let d = item as? Data { return URL(dataRepresentation: d, relativeTo: nil) }
                    if let s = item as? String { return URL(string: s) }
                    return nil
                }()
                guard let url else { return }
                Task { @MainActor in await self?.loadVideo(from: url) }
            }
        }
    }

    func loadVideo(from url: URL) async {
        AppDebugLog.shared.clear()
        appLog("VM [v4]: loadVideo START url=\(url.lastPathComponent)")
        videoURL  = url
        videoName = url.deletingPathExtension().lastPathComponent

        do {
            videoDuration = try await VideoFrameExtractor.duration(of: url)
            appLog("VM [v4]: loadVideo got videoDuration=\(String(format: "%.3f", videoDuration))s from duration(of:)")
            statusMessage = "Loaded: \(videoName) — \(formatDuration(videoDuration))"
            rawFrames     = []
            frames40      = []
            frames80      = []
            previewFrameIndex = 0
            // Kick off extraction + conversion automatically.
            await processFrames()
        } catch {
            appLog("VM [v4]: loadVideo FAILED \(error.localizedDescription)")
            errorMessage = "Could not load video: \(error.localizedDescription)"
        }
    }

    // MARK: - Processing pipeline

    /// Stream frames from the loaded video and convert each one as it
    /// arrives. Single-pass: each frame is extracted, immediately turned
    /// into ASCIIResult(s), then released. Memory usage stays bounded
    /// (~300 KB live × small backbuffer) regardless of video length.
    func processFrames() async {
        guard let url = videoURL else { return }

        // Stop any preview playback before we wipe the frame arrays.
        stopPlayback()

        isExtracting  = true
        isConverting  = true
        progress      = 0
        statusMessage = "Extracting frames…"

        let fps    = targetFPS
        let cap    = max(1, maxFrames)
        let ramp   = effectiveRamp
        var s40    = settings; s40.platform = .appleII40
        var s80    = settings; s80.platform = .appleII80
        let want40 = colMode.includes40
        let want80 = colMode.includes80

        rawFrames         = []
        frames40          = []
        frames80          = []
        previewFrameIndex = 0

        var newRaw: [NSImage]     = []
        var new40:  [ASCIIResult] = []
        var new80:  [ASCIIResult] = []
        var seenTotal = 0

        // Compute the expected frame count from the already-verified
        // video duration so the status bar can show it before extraction
        // starts (and so we don't depend on AVFoundation re-loading the
        // duration consistently inside the extractor).
        appLog("VM [v4]: processFrames START url=\(url.lastPathComponent)")
        appLog("VM [v4]: diskFormat=\(diskFormat.rawValue) maxFramesForDisk=\(cap) — IGNORED for extraction")
        // **Decouple extraction from disk format.** Disk size is an
        // export-time decision; extracting only `disk.maxFrames` frames
        // means switching to a bigger disk later requires re-opening the
        // file. Instead extract by source-video length, capped at a
        // generous absolute ceiling so a 4-hour rip doesn't OOM.
        let absoluteCap = 30_000
        let extractionCap = min(max(1, Int(floor(videoDuration * fps)) + 1), absoluteCap)
        appLog("VM [v4]: videoDuration=\(String(format: "%.3f", videoDuration))s fps=\(fps) " +
               "extractionCap=\(extractionCap) (source-bound, NOT disk-bound) colMode=\(colMode.rawValue)")

        let expectedTotal = extractionCap
        appLog("VM [v4]: expectedTotal = \(expectedTotal) frames")

        statusMessage = "Processing [v4] from \(String(format: "%.1f", videoDuration))s source → \(expectedTotal) frames…"

        do {
            appLog("VM [v4]: calling streamFrames(durationOverride: \(videoDuration), maxFrames: \(extractionCap))")
            let stream = VideoFrameExtractor.streamFrames(
                from: url,
                fps: fps,
                maxFrames: extractionCap,
                durationOverride: videoDuration
            )
            for try await chunk in stream {
                if Task.isCancelled { break }
                seenTotal = chunk.total

                // ASCII conversion runs OFF the main actor so the UI stays
                // responsive while we're processing thousands of frames.
                // Tries the Metal GPU path first; falls back to CPU
                // `ASCIIConverter` if Metal isn't available or the
                // texture upload fails for any reason.
                let img = chunk.image
                let (r40, r80): (ASCIIResult?, ASCIIResult?) = await Task.detached(priority: .userInitiated) {
                    if let metal = MetalASCIIConverter.shared {
                        let (m40, m80) = metal.convertBoth(
                            image: img,
                            settings40: want40 ? s40 : nil,
                            settings80: want80 ? s80 : nil,
                            customRamp: ramp
                        )
                        // If Metal returned anything, use it. Only fall
                        // through to CPU when Metal returned (nil, nil)
                        // for a mode we actually wanted.
                        if (want40 ? m40 : nil) != nil || !want40,
                           (want80 ? m80 : nil) != nil || !want80 {
                            return (m40, m80)
                        }
                    }
                    let a: ASCIIResult? = want40
                        ? ASCIIConverter.convert(image: img, settings: s40, customRamp: ramp)
                        : nil
                    let b: ASCIIResult? = want80
                        ? ASCIIConverter.convert(image: img, settings: s80, customRamp: ramp)
                        : nil
                    return (a, b)
                }.value

                newRaw.append(img)
                if let r = r40 { new40.append(r) }
                if let r = r80 { new80.append(r) }

                let done = chunk.index + 1
                progress = Double(done) / Double(chunk.total)
                statusMessage = "Processing [v4] frame \(done) / \(chunk.total)…"
                // Log only sparsely so we don't drown the debug panel —
                // the per-chunk logs in the extractor already give us
                // the per-30s granularity.
                if done == 1 || done % 100 == 0 {
                    appLog("VM [v4]: consumed frame \(done) / chunk.total=\(chunk.total)")
                }

                // Publish partial results every 25 frames so the preview
                // can scrub through what's been processed so far.
                if done % 25 == 0 || done == chunk.total {
                    rawFrames = newRaw
                    frames40  = new40
                    frames80  = new80
                }
            }
        } catch {
            errorMessage  = error.localizedDescription
        }

        rawFrames     = newRaw
        frames40      = new40
        frames80      = new80
        isExtracting  = false
        isConverting  = false
        progress      = 1.0

        let count = newRaw.count
        let effectiveTotal = max(seenTotal, expectedTotal)
        let dropped = max(0, effectiveTotal - count)
        appLog("VM [v4]: processFrames END count=\(count) seenTotal=\(seenTotal) expectedTotal=\(expectedTotal) effectiveTotal=\(effectiveTotal) dropped=\(dropped)")
        if dropped > 0 {
            statusMessage = "Ready [v4] · \(count) / \(effectiveTotal) frames (lost \(dropped)) · " +
                            "\(String(format: "%.1f", estimatedDuration)) s playback"
        } else {
            statusMessage = "Ready [v4] · \(count) frame\(count == 1 ? "" : "s") · " +
                            "\(String(format: "%.1f", estimatedDuration)) s playback"
        }
        previewFrameIndex = 0
    }

    /// Re-run ASCII conversion on the already-extracted `rawFrames` without
    /// touching AVFoundation. Triggered when settings change.
    private func reconvertExistingFrames() {
        guard !rawFrames.isEmpty else { return }
        reconvertTask?.cancel()

        let raw  = rawFrames
        let ramp = effectiveRamp
        var s40  = settings; s40.platform = .appleII40
        var s80  = settings; s80.platform = .appleII80
        let want40 = colMode.includes40
        let want80 = colMode.includes80

        isConverting  = true
        progress      = 0
        statusMessage = "Re-converting \(raw.count) frame\(raw.count == 1 ? "" : "s")…"

        reconvertTask = Task {
            let result: (f40: [ASCIIResult], f80: [ASCIIResult]) = await Task.detached(priority: .userInitiated) {
                var out40: [ASCIIResult] = []
                var out80: [ASCIIResult] = []
                out40.reserveCapacity(raw.count)
                out80.reserveCapacity(raw.count)
                for (i, img) in raw.enumerated() {
                    if Task.isCancelled { return (out40, out80) }
                    if want40 {
                        out40.append(ASCIIConverter.convert(image: img, settings: s40, customRamp: ramp))
                    }
                    if want80 {
                        out80.append(ASCIIConverter.convert(image: img, settings: s80, customRamp: ramp))
                    }
                    let p = Double(i + 1) / Double(raw.count)
                    await MainActor.run { self.progress = p }
                }
                return (out40, out80)
            }.value

            if Task.isCancelled { return }
            frames40 = result.f40
            frames80 = result.f80
            isConverting  = false
            progress      = 1.0
            statusMessage = "Ready · \(frameCount) frame\(frameCount == 1 ? "" : "s")"
        }
    }

    // MARK: - Export

    func exportDisk() {
        guard !rawFrames.isEmpty else {
            errorMessage = "Load and process a video first."
            return
        }
        let panel = NSSavePanel()
        let ext   = diskFormat.fileExtension
        panel.allowedContentTypes = [UTType(filenameExtension: ext) ?? .data]
        panel.nameFieldStringValue = "\(videoName.isEmpty ? "video" : videoName).\(ext)"

        // Trim each list to the disk capacity before exporting.
        let cap = frameCount
        let f40: [ASCIIResult]? = colMode.includes40 ? Array(frames40.prefix(cap)) : nil
        let f80: [ASCIIResult]? = colMode.includes80 ? Array(frames80.prefix(cap)) : nil
        let fps    = targetFPS
        let fmt    = diskFormat

        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url, let self else { return }
            Task { @MainActor in
                self.isExporting  = true
                self.statusMessage = "Writing disk image…"
                do {
                    try await VideoDiskExporter.export(
                        frames40: f40, frames80: f80,
                        fps: fps, format: fmt, to: url
                    )
                    self.statusMessage = "Exported: \(url.lastPathComponent)"
                } catch {
                    self.errorMessage = error.localizedDescription
                    self.statusMessage = ""
                }
                self.isExporting = false
            }
        }
    }

    // MARK: - In-app playback

    /// Start advancing `previewFrameIndex` at `targetFPS`, looping at the
    /// end. Uses a single async Task with `Task.sleep` rather than a Timer
    /// so everything stays main-actor isolated and cancellation is clean.
    func startPlayback() {
        let list = previewUses80 ? frames80 : frames40
        guard !list.isEmpty, targetFPS > 0 else { return }

        // If we're at the end, restart from 0.
        if previewFrameIndex >= list.count - 1 { previewFrameIndex = 0 }

        playbackTask?.cancel()
        isPlaying = true

        let interval = max(0.0, 1.0 / targetFPS)
        let nanos    = UInt64(interval * 1_000_000_000)

        playbackTask = Task { @MainActor [weak self] in
            while !Task.isCancelled, self?.isPlaying == true {
                try? await Task.sleep(nanoseconds: nanos)
                if Task.isCancelled { break }
                guard let self else { return }
                let current = self.previewUses80 ? self.frames80 : self.frames40
                guard !current.isEmpty else { self.stopPlayback(); return }
                let next = self.previewFrameIndex + 1
                self.previewFrameIndex = next >= current.count ? 0 : next
            }
        }
    }

    func stopPlayback() {
        playbackTask?.cancel()
        playbackTask = nil
        isPlaying = false
    }

    func togglePlayback() {
        if isPlaying { stopPlayback() } else { startPlayback() }
    }

    // MARK: - Helpers

    private func formatDuration(_ s: Double) -> String {
        let total = Int(s.rounded())
        let m = total / 60
        let sec = total % 60
        return String(format: "%d:%02d", m, sec)
    }
}
