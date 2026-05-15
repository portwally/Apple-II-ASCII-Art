import SwiftUI
import UniformTypeIdentifiers

/// Standalone video-to-ASCII converter window. Reuses the image
/// converter's `ASCIICanvas` for frame previews and `ConversionSettings`
/// for adjustments — the only fundamentally new pieces are FPS / disk
/// format selectors and the timeline scrubber.
struct VideoConverterView: View {
    @StateObject private var vm = VideoConverterViewModel()
    @ObservedObject private var appSettings = AppSettings.shared
    @ObservedObject private var debugLog = AppDebugLog.shared
    @State private var showDebugLog = false

    var body: some View {
        HSplitView {
            sidebar
            mainArea
        }
        .frame(minWidth: 900, minHeight: 620)
        .toolbar { toolbarContent }
        .alert("Error", isPresented: Binding(
            get: { vm.errorMessage != nil },
            set: { if !$0 { vm.errorMessage = nil } }
        )) {
            Button("OK") { vm.errorMessage = nil }
        } message: {
            Text(vm.errorMessage ?? "")
        }
        // Only accept MP4 and MOV containers system-wide. macOS native
        // AVFoundation playback for arbitrary containers (MKV, WebM, FLV)
        // isn't reliable enough to be worth offering — drag-drop is
        // restricted to the same UTTypes the file picker shows.
        .onDrop(of: [.mpeg4Movie, .quickTimeMovie],
                isTargeted: nil) { providers in
            vm.loadDroppedProviders(providers)
            return true
        }
        .onDisappear { vm.stopPlayback() }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                fpsSection
                modeSection
                formatSection
                Divider()
                rampSection
                adjustmentsSection
                flipSection
                Divider()
                diskInfoSection
            }
            .padding(16)
        }
        .frame(minWidth: 240, maxWidth: 300)
        .background(sidebarBackground)
    }

    private var sidebarBackground: Color {
        ChromeStyle(theme: appSettings.theme).sidebarBackground
            ?? Color(NSColor.controlBackgroundColor)
    }

    private var fpsSection: some View {
        section(title: "Frame rate") {
            Picker("", selection: $vm.targetFPS) {
                Text("1 fps").tag(1.0)
                Text("2 fps").tag(2.0)
                Text("4 fps").tag(4.0)
                Text("6 fps").tag(6.0)
                Text("8 fps").tag(8.0)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .disabled(vm.isExtracting || vm.isConverting)
        }
    }

    private var modeSection: some View {
        section(title: "Mode") {
            Picker("", selection: $vm.colMode) {
                ForEach(VideoColMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .disabled(vm.isExtracting || vm.isConverting)
        }
    }

    private var formatSection: some View {
        section(title: "Disk format") {
            Picker("", selection: $vm.diskFormat) {
                ForEach(DiskImageFormat.allCases) { f in
                    Text(f.rawValue).tag(f)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
        }
    }

    private var rampSection: some View {
        section(title: "Character Ramp") {
            // Apple II text page 1 can only display 7-bit ASCII glyphs —
            // PETSCII / CP437 / Unicode-block ramps render as dots on the
            // real hardware. Show only ramps that survive that ROM.
            Picker("", selection: $vm.settings.selectedRampID) {
                ForEach(CharacterRamp.appleIIPresets) { ramp in
                    Text(ramp.displayName).tag(ramp.id)
                }
                Text("Custom").tag("custom")
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .onChange(of: vm.settings.selectedRampID) { _, newVal in
                vm.useCustomRamp = (newVal == "custom")
            }
            .onAppear {
                // If a previously chosen ramp isn't Apple II-compatible
                // (e.g. user switched here from the image converter),
                // snap back to the Classic preset so the picker has a
                // valid selection.
                let current = vm.settings.selectedRampID
                let ok = CharacterRamp.appleIIPresets.contains { $0.id == current }
                if !ok && !vm.useCustomRamp {
                    vm.settings.selectedRampID = CharacterRamp.appleIIClassic.id
                }
            }

            if vm.useCustomRamp {
                TextField("e.g.  .:-=+*#%@", text: $vm.customRampText)
                    .font(.custom(vm.previewSettings.platform.fontName, size: 13))
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: vm.customRampText) { _, newVal in
                        // Strip non-ASCII chars from the custom ramp —
                        // they'd become spaces in the disk export anyway.
                        let filtered = newVal.filter { ch in
                            guard let v = ch.asciiValue else { return false }
                            return v >= 0x20 && v < 0x7F
                        }
                        if filtered != newVal { vm.customRampText = filtered }
                    }
            } else {
                Text(vm.settings.ramp.characters.map(String.init).joined())
                    .font(.custom(vm.previewSettings.platform.fontName, size: 11))
                    .lineLimit(2)
                    .truncationMode(.tail)
                    .chromeForeground(.secondary)
            }
        }
    }

    private var adjustmentsSection: some View {
        section(title: "Adjustments") {
            sliderRow(label: "Brightness", value: $vm.settings.brightness,
                      range: -1.0...1.0, minIcon: "sun.min", maxIcon: "sun.max")
            sliderRow(label: "Contrast", value: $vm.settings.contrast,
                      range: -1.0...1.0, minIcon: "circle.lefthalf.filled", maxIcon: "circle.righthalf.filled")
            Toggle("Invert", isOn: $vm.settings.invert)
                .toggleStyle(.checkbox)
        }
    }

    private var flipSection: some View {
        section(title: "Flip") {
            HStack(spacing: 8) {
                Button {
                    vm.settings.flipHorizontal.toggle()
                } label: {
                    Label("H", systemImage: "arrow.left.and.right")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(vm.settings.flipHorizontal ? Color.accentColor.opacity(0.25) : Color.clear)
                )

                Button {
                    vm.settings.flipVertical.toggle()
                } label: {
                    Label("V", systemImage: "arrow.up.and.down")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(vm.settings.flipVertical ? Color.accentColor.opacity(0.25) : Color.clear)
                )
            }
        }
    }

    private var diskInfoSection: some View {
        section(title: "Disk Info") {
            if vm.videoDuration > 0 {
                infoRow("Source", String(format: "%.1f s", vm.videoDuration))
            }
            infoRow("Extracted", "\(vm.rawFrames.count) frames")
            let willExport = min(vm.rawFrames.count, vm.maxFrames)
            let willFit = vm.rawFrames.count <= vm.maxFrames
            infoRow("Disk fits", willFit
                    ? "all \(vm.maxFrames) max"
                    : "\(willExport) / \(vm.maxFrames) max ✂️")
            infoRow("Playback", String(format: "%.1f s @ %d fps",
                                       Double(willExport) / vm.targetFPS,
                                       Int(vm.targetFPS)))
            infoRow("Frame size", "\(vm.colMode.bytesPerFrame) B")
            infoRow("Export size", formatBytes(willExport * vm.colMode.bytesPerFrame))
        }
    }

    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).chromeFont(.caption).chromeForeground(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 11, design: .monospaced))
                .chromeForeground(.primary)
        }
    }

    // MARK: - Main area (preview + scrub bar + status)

    private var mainArea: some View {
        VStack(spacing: 0) {
            previewPane
            scrubBar
            statusBar
            if showDebugLog {
                debugPanel
            }
        }
    }

    /// Live diagnostic log — collapsed by default, expand via the
    /// "Debug" chevron in the status bar. Mirrors `appLog(...)` calls
    /// from the extractor / VM so we don't have to open Console.app.
    private var debugPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Text("Debug log")
                    .chromeFont(.caption)
                    .chromeForeground(.secondary)
                Spacer()
                Button {
                    let text = debugLog.lines.joined(separator: "\n")
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(text, forType: .string)
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 10))
                }
                .buttonStyle(.borderless)
                .help("Copy log to clipboard")

                Button {
                    debugLog.clear()
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 10))
                }
                .buttonStyle(.borderless)
                .help("Clear log")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(sidebarBackground)

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(debugLog.lines.enumerated()), id: \.offset) { idx, line in
                            Text(line)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(.green)
                                .lineLimit(nil)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 1)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .id(idx)
                        }
                    }
                }
                .background(Color.black)
                .frame(height: 160)
                .onChange(of: debugLog.lines.count) { _, count in
                    guard count > 0 else { return }
                    withAnimation(.linear(duration: 0.1)) {
                        proxy.scrollTo(count - 1, anchor: .bottom)
                    }
                }
            }
        }
        .overlay(Divider(), alignment: .top)
    }

    private var previewPane: some View {
        GeometryReader { geo in
            ZStack {
                bezelBackground
                if vm.videoURL == nil {
                    DropZoneView(
                        onOpenFile:   { vm.openVideoFilePicker() },
                        onDropProviders: { vm.loadDroppedProviders($0) },
                        title: "DROP VIDEO HERE",
                        subtitle: "MP4 or MOV",
                        buttonLabel: "Open Video…",
                        iconName: "film",
                        acceptedTypes: [.mpeg4Movie, .quickTimeMovie]
                    )
                    .padding(40)
                } else if let frame = vm.previewFrame {
                    appleScreen(result: frame, available: geo.size)
                } else if vm.isExtracting || vm.isConverting {
                    VStack(spacing: 12) {
                        ProgressView(value: vm.progress)
                            .progressViewStyle(.linear)
                            .frame(width: 280)
                        Text(vm.statusMessage)
                            .chromeFont(.body)
                            .chromeForeground(.secondary)
                    }
                } else {
                    Text("No frames")
                        .chromeFont(.body)
                        .chromeForeground(.secondary)
                }
            }
        }
        .frame(minHeight: 360)
    }

    @ViewBuilder
    private var bezelBackground: some View {
        if let themed = ChromeStyle(theme: appSettings.theme).background {
            themed
        } else {
            Color(NSColor.windowBackgroundColor)
        }
    }

    @ViewBuilder
    private func appleScreen(result: ASCIIResult, available: CGSize) -> some View {
        let settings  = vm.previewSettings
        let aspect    = settings.platform.aspectRatio
        let maxW      = available.width  - 60
        let maxH      = available.height - 60
        let size: CGSize = (maxW / aspect <= maxH)
            ? CGSize(width: maxW, height: maxW / aspect)
            : CGSize(width: maxH * aspect, height: maxH)

        let screenBg  = settings.resolvedBackground
        let glowColor = settings.resolvedForeground

        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(red: 0.18, green: 0.18, blue: 0.18))
                .frame(width: size.width + 24, height: size.height + 24)

            ZStack {
                screenBg
                ASCIICanvas(result: result, settings: settings)
                if vm.isConverting || vm.isExtracting || vm.isExporting {
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
            .shadow(color: glowColor.opacity(0.4), radius: 6)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var scrubBar: some View {
        let activeList = vm.previewUses80 ? vm.frames80 : vm.frames40
        let count = activeList.count
        return HStack(spacing: 10) {
            // 40 / 80 toggle (only shown when both modes are loaded)
            if !vm.frames40.isEmpty && !vm.frames80.isEmpty {
                Picker("", selection: $vm.previewUses80) {
                    Text("40").tag(false)
                    Text("80").tag(true)
                }
                .pickerStyle(.segmented)
                .frame(width: 80)
                .labelsHidden()
            }

            // Play / pause toggle
            Button {
                vm.togglePlayback()
            } label: {
                Image(systemName: vm.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 14, weight: .medium))
                    .frame(width: 24, height: 20)
            }
            .buttonStyle(.borderless)
            .disabled(count <= 1)
            .help(vm.isPlaying ? "Pause playback" : "Play at \(Int(vm.targetFPS)) fps")

            // Previous / next frame
            Button {
                vm.stopPlayback()
                vm.previewFrameIndex = max(0, vm.previewFrameIndex - 1)
            } label: { Image(systemName: "backward.frame") }
                .disabled(count == 0 || vm.previewFrameIndex == 0)

            Button {
                vm.stopPlayback()
                vm.previewFrameIndex = min(count - 1, vm.previewFrameIndex + 1)
            } label: { Image(systemName: "forward.frame") }
                .disabled(count == 0 || vm.previewFrameIndex >= count - 1)

            Text(count > 0 ? "Frame \(vm.previewFrameIndex + 1) / \(count)"
                          : "—")
                .font(.system(size: 11, design: .monospaced))
                .chromeForeground(.secondary)
                .frame(width: 130, alignment: .leading)

            // Slider
            Slider(
                value: Binding(
                    get: { Double(vm.previewFrameIndex) },
                    set: {
                        vm.stopPlayback()
                        vm.previewFrameIndex = Int($0.rounded())
                    }
                ),
                in: 0...Double(max(0, count - 1))
            )
            .disabled(count <= 1)
        }
        .padding(.horizontal, 12)
        .frame(height: 40)
        .background(sidebarBackground)
        .overlay(Divider(), alignment: .top)
    }

    private var statusBar: some View {
        HStack(spacing: 12) {
            if vm.isExtracting || vm.isConverting || vm.isExporting {
                ProgressView(value: vm.progress)
                    .progressViewStyle(.linear)
                    .frame(width: 160)
            }
            Text(vm.statusMessage.isEmpty
                 ? (vm.videoURL == nil ? "Open a movie to begin" : "Ready")
                 : vm.statusMessage)
                .chromeFont(.footnote)
                .chromeForeground(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer()
            Button {
                showDebugLog.toggle()
            } label: {
                Image(systemName: showDebugLog ? "chevron.down" : "chevron.up")
                    .font(.system(size: 10))
                Text("Debug")
                    .chromeFont(.footnote)
            }
            .buttonStyle(.borderless)
            .chromeForeground(.secondary)
            .help(showDebugLog ? "Hide debug log" : "Show debug log")
        }
        .padding(.horizontal, 12)
        .frame(height: 28)
        .background(sidebarBackground)
        .overlay(Divider(), alignment: .top)
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button {
                vm.exportDisk()
            } label: {
                Label("Export Disk", systemImage: "internaldrive")
            }
            .disabled(vm.frames40.isEmpty && vm.frames80.isEmpty || vm.isExporting)
            .keyboardShortcut("e", modifiers: .command)
            .help("Export bootable ProDOS disk image")
        }
        ToolbarItem(placement: .primaryAction) {
            Button {
                vm.openVideoFilePicker()
            } label: {
                Label("Open Movie", systemImage: "film")
            }
            .keyboardShortcut("o", modifiers: .command)
            .help("Open movie file")
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func section<Content: View>(title: String,
                                        @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).chromeFont(.headline).chromeForeground(.primary)
            content()
        }
    }

    @ViewBuilder
    private func sliderRow(label: String, value: Binding<Double>,
                           range: ClosedRange<Double>,
                           minIcon: String, maxIcon: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(label).chromeFont(.caption).chromeForeground(.secondary)
                Spacer()
                Text(String(format: "%+.0f%%", value.wrappedValue * 100))
                    .font(.system(size: 11, design: .monospaced))
                    .chromeForeground(.secondary)
                    .frame(width: 44, alignment: .trailing)
            }
            HStack(spacing: 4) {
                Image(systemName: minIcon).font(.system(size: 11)).chromeForeground(.secondary)
                Slider(value: value, in: range)
                Image(systemName: maxIcon).font(.system(size: 11)).chromeForeground(.secondary)
            }
        }
    }

    private func formatBytes(_ b: Int) -> String {
        if b >= 1024 * 1024 { return String(format: "%.1f MB", Double(b) / 1024 / 1024) }
        if b >= 1024        { return String(format: "%.1f KB", Double(b) / 1024) }
        return "\(b) B"
    }
}
