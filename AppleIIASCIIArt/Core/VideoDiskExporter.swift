import Foundation

/// Builds a ProDOS disk image carrying a frame-by-frame ASCII video plus
/// a 6502 ML player. Two playback modes (40-col / 80-col) can ship on the
/// same disk; either or both may be supplied.
///
/// **Bootability for every size — including 32 MB.** The exporter always
/// builds a fresh ProDOS volume of the requested size (so the bitmap is
/// correctly sized — a 32 MB volume needs 16 bitmap blocks; a single
/// resized template would put the bitmap on top of PRODOS file data).
/// It then injects three things from the bundled `ProDOS_2_0_3.po`:
///
///   1. **Boot blocks** (blocks 0–1, 1024 bytes total). ProDOSWriter's
///      from-scratch boot code is incomplete — only the first 128 bytes
///      are filled. We overwrite blocks 0–1 with the template's full
///      boot code so the disk boots ProDOS as expected.
///   2. **PRODOS** (the ProDOS-8 kernel, type $FF). Added as a file —
///      ProDOSWriter's allocator places it at block 24+ rather than
///      block 8, but boot blocks find it by name in the directory, not
///      by hard-coded block.
///   3. **BASIC.SYSTEM** (the Applesoft shell, type $FF, aux $2000).
///      Same as above.
///
/// Disk layout (file order):
///
///     /VIDEO/
///       PRODOS, BASIC.SYSTEM       (from the bundled template)
///       STARTUP                    (Applesoft, auto-runs at boot — menu)
///       PLAY40                     (BAS wrapper → BRUN PLAY40.BIN)
///       PLAY40.BIN                 (ML player, $0900 — patched at
///                                   offsets 3-5 with frame count +
///                                   FPS delay)
///       FRAMES40                   (40-col frames concatenated)
///       PLAY80                     (BAS wrapper → BRUN PLAY80.BIN)
///       PLAY80.BIN                 (ML player; uses JSR $C300 itself
///                                   so PR# 3 isn't needed from BASIC)
///       FRAMES80                   (80-col frames concatenated)
struct VideoDiskExporter {

    enum DiskExportError: Error, LocalizedError {
        case templateMissing
        case templateUnreadable(String)
        case missingSystemFile(String)
        case write(String)
        case noFrames

        var errorDescription: String? {
            switch self {
            case .templateMissing:           return "Bundled ProDOS template image is missing."
            case .templateUnreadable(let m): return "Could not read ProDOS template: \(m)"
            case .missingSystemFile(let n):  return "ProDOS template is missing the \(n) file."
            case .write(let msg):            return "ProDOS write failed: \(msg)"
            case .noFrames:                  return "No frames to export."
            }
        }
    }

    // MARK: - Frame packing

    private static func packFrames40(_ frames: [ASCIIResult]) -> Data {
        var d = Data()
        d.reserveCapacity(frames.count * 1024)
        for f in frames { d.append(AppleIIScreenMemory.buildScreen40(grid: f.grid)) }
        return d
    }
    private static func packFrames80(_ frames: [ASCIIResult]) -> Data {
        var d = Data()
        d.reserveCapacity(frames.count * 2048)
        for f in frames { d.append(AppleIIScreenMemory.buildScreen80(grid: f.grid)) }
        return d
    }

    // MARK: - Public entry point

    static func export(
        frames40: [ASCIIResult]?,
        frames80: [ASCIIResult]?,
        fps: Double,
        format: DiskImageFormat,
        to url: URL
    ) async throws {
        guard (frames40?.isEmpty == false) || (frames80?.isEmpty == false) else {
            throw DiskExportError.noFrames
        }

        // Read the bundled template up front — we need its boot blocks +
        // PRODOS + BASIC.SYSTEM regardless of the requested disk size.
        guard let templateURL = Bundle.main.url(forResource: "ProDOS_2_0_3", withExtension: "po") else {
            throw DiskExportError.templateMissing
        }
        let templateData: Data
        do { templateData = try Data(contentsOf: templateURL) }
        catch { throw DiskExportError.templateUnreadable(error.localizedDescription) }

        guard let prodos = ProDOSWriter.shared.extractFileFromProDOS(templateData, fileName: "PRODOS") else {
            throw DiskExportError.missingSystemFile("PRODOS")
        }
        guard let basicSys = ProDOSWriter.shared.extractFileFromProDOS(templateData, fileName: "BASIC.SYSTEM") else {
            throw DiskExportError.missingSystemFile("BASIC.SYSTEM")
        }

        // Build empty ProDOS volume of the requested size.
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("1977_video_\(UUID().uuidString).po")
        defer { try? FileManager.default.removeItem(at: tempURL) }

        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            ProDOSWriter.shared.createDiskImage(
                at: tempURL,
                volumeName: "VIDEO",
                totalBlocks: format.totalBlocks
            ) { ok, msg in
                if ok { cont.resume() }
                else  { cont.resume(throwing: DiskExportError.write(msg)) }
            }
        }

        // Overwrite the fresh disk's stub boot blocks with the template's
        // real ProDOS boot code (1024 bytes — blocks 0 and 1).
        try injectBootBlocks(from: templateData, to: tempURL)

        // Add PRODOS and BASIC.SYSTEM as the first two files. The boot
        // blocks scan the volume directory looking for the file named
        // "PRODOS" — they don't care which physical block holds it.
        try await addFile(to: tempURL, name: "PRODOS",
                          data: prodos.data, type: prodos.fileType, aux: prodos.auxType)
        try await addFile(to: tempURL, name: "BASIC.SYSTEM",
                          data: basicSys.data, type: basicSys.fileType, aux: basicSys.auxType)

        // STARTUP launcher
        let startupSrc = startupSource(
            has40: frames40?.isEmpty == false,
            has80: frames80?.isEmpty == false,
            count40: frames40?.count ?? 0,
            count80: frames80?.count ?? 0
        )
        let startupTokens = ApplesoftTokenizer.tokenize(startupSrc)
        try await addFile(to: tempURL, name: "STARTUP",
                          data: startupTokens, type: 0xFC, aux: 0x0801)

        // 40-col files
        if let f40 = frames40, !f40.isEmpty {
            let play40 = ApplesoftTokenizer.tokenize(playSource40())
            try await addFile(to: tempURL, name: "PLAY40",
                              data: play40, type: 0xFC, aux: 0x0801)

            let player40 = VideoMLPlayer.patched(
                VideoMLPlayer.play40Bytes,
                frameCount: f40.count, fps: fps, twoKBFrame: false
            )
            try await addFile(to: tempURL, name: "PLAY40.BIN",
                              data: player40, type: 0x06, aux: 0x0900)

            try await addFile(to: tempURL, name: "FRAMES40",
                              data: packFrames40(f40), type: 0x06, aux: 0x0000)
        }

        // 80-col files
        if let f80 = frames80, !f80.isEmpty {
            let play80 = ApplesoftTokenizer.tokenize(playSource80())
            try await addFile(to: tempURL, name: "PLAY80",
                              data: play80, type: 0xFC, aux: 0x0801)

            let player80 = VideoMLPlayer.patched(
                VideoMLPlayer.play80Bytes,
                frameCount: f80.count, fps: fps, twoKBFrame: true
            )
            try await addFile(to: tempURL, name: "PLAY80.BIN",
                              data: player80, type: 0x06, aux: 0x0900)

            try await addFile(to: tempURL, name: "FRAMES80",
                              data: packFrames80(f80), type: 0x06, aux: 0x0000)
        }

        // Wrap in container format and write to the user's URL.
        let raw     = try Data(contentsOf: tempURL)
        let wrapped = DiskImageWriter.wrap(raw, format: format)
        if FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.removeItem(at: url)
        }
        try wrapped.write(to: url, options: .atomic)
    }

    // MARK: - Boot block injection

    /// Copy blocks 0 and 1 (1024 bytes) from the template into the freshly
    /// built ProDOS volume at `url`. The template's blocks 0-1 are the real
    /// ProDOS boot loader — they search the volume directory for the file
    /// named "PRODOS" and load+execute it. Without this, the fresh volume
    /// has only ProDOSWriter's 128-byte boot stub and won't boot.
    private static func injectBootBlocks(from template: Data, to url: URL) throws {
        var data = try Data(contentsOf: url)
        let bootBytes = 1024
        guard template.count >= bootBytes, data.count >= bootBytes else {
            throw DiskExportError.write("Disk too small to inject boot blocks")
        }
        data.replaceSubrange(0..<bootBytes, with: template.prefix(bootBytes))
        try data.write(to: url, options: .atomic)
    }

    // MARK: - BASIC source

    private static func startupSource(has40: Bool, has80: Bool,
                                      count40: Int, count80: Int) -> String {
        // Single-mode disk: skip the menu and auto-launch the player.
        // (A menu with only one option is confusing — users naturally
        // press '1' even when the only entry is labelled '2', which
        // matches nothing and loops back to the same screen.)
        if has40 && !has80 {
            var src = ""
            src += "5 NOTRACE\r"
            src += "10 HOME\r"
            src += "20 PRINT CHR$(4);\"-PLAY40\""
            return src
        }
        if has80 && !has40 {
            var src = ""
            src += "5 NOTRACE\r"
            src += "10 HOME\r"
            src += "20 PRINT CHR$(4);\"-PLAY80\""
            return src
        }

        // Both modes available — show the picker menu.
        var src = ""
        src += "5 NOTRACE\r"
        src += "10 HOME\r"
        src += "20 PRINT \"            1977 VIDEO\"\r"
        src += "30 PRINT \"            ==========\"\r"
        src += "40 PRINT\r"
        src += "50 PRINT \"  1) 40-COL  (\(count40) FRAMES)\"\r"
        src += "60 PRINT \"  2) 80-COL  (\(count80) FRAMES)\"\r"
        src += "70 PRINT\r"
        src += "80 PRINT \"  SELECT: \";\r"
        // Credit pinned to row 23 of the 24-row screen.
        src += "90 VTAB 23\r"
        src += "100 HTAB 1\r"
        src += "110 PRINT \"  2026 WALTER TENGLER\"\r"
        // Return cursor to the SELECT prompt on row 7
        // (HOME=row1, title=1, =====2, blank=3, 40-COL=4, 80-COL=5, blank=6, SELECT=7)
        src += "120 VTAB 7\r"
        src += "130 HTAB 12\r"
        src += "140 GET A$\r"
        src += "150 PRINT A$\r"
        src += "160 IF A$ = \"1\" THEN PRINT CHR$(4);\"-PLAY40\"\r"
        src += "170 IF A$ = \"2\" THEN PRINT CHR$(4);\"-PLAY80\"\r"
        src += "180 GOTO 10"
        return src
    }

    /// PLAY40 wrapper — clears the screen, prints a "LOADING" message
    /// so the user has visible confirmation the BASIC ran, then BRUNs
    /// the player. If the user sees the message but no animation, we
    /// know the BAS executed but the ML player failed (and the on-screen
    /// error code from the player tells us why).
    private static func playSource40() -> String {
        var src = ""
        src += "5 NOTRACE\r"
        src += "10 HOME\r"
        src += "20 PRINT \"  LOADING 40-COL VIDEO...\"\r"
        src += "30 PRINT CHR$(4);\"BRUN PLAY40.BIN\""
        return src
    }

    /// PLAY80 wrapper — BRUN while still in 40-col mode.
    /// The player itself switches to 80-col via JSR $C300 after MLI OPEN,
    /// avoiding the BASIC.SYSTEM Ctrl-D bug where PR# 3 before a Ctrl-D
    /// command leaves COUT redirected to the 80-col card and the BRUN
    /// never reaches BASIC.SYSTEM.
    private static func playSource80() -> String {
        var src = ""
        src += "5 NOTRACE\r"
        src += "10 HOME\r"
        src += "20 PRINT \"  LOADING 80-COL VIDEO...\"\r"
        src += "30 PRINT CHR$(4);\"BRUN PLAY80.BIN\""
        return src
    }

    // MARK: - Helper

    private static func addFile(to disk: URL, name: String, data: Data,
                                type: UInt8, aux: UInt16) async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            ProDOSWriter.shared.addFile(
                diskImagePath: disk,
                fileName: name,
                fileData: data,
                fileType: type,
                auxType: aux
            ) { ok, msg in
                if ok { cont.resume() }
                else  { cont.resume(throwing: DiskExportError.write("\(name): \(msg)")) }
            }
        }
    }
}
