import Foundation

/// Builds an Apple II ProDOS disk image (.po) containing the ASCII art result.
///
/// The base image is the bundled `ProDOS_2_4_3.po`, which carries Bitsy Bye as
/// a launcher — when booted on real hardware or in an emulator, Bitsy Bye lists
/// every program on the disk and lets the user pick one.
///
/// 40-col output produces:
///   - ART.BAS    — tokenized PRINT program (slow but reliable)
///   - ART.BIN    — 1024-byte $0400-format dump (aux=$2000, NOT $0400)
///   - LOADER.BAS — POKEs a 30-byte 6502 copier to $0300, BLOADs ART.BIN to
///                  $2000, CALL 768 copies it to text page 1
///
/// 80-col output produces:
///   - ART.BAS      — tokenized PRINT program (auto-emits PR#3)
///   - ART80.BIN    — 2048-byte combined dump (aux=$2000)
///   - LOADER80.BAS — POKEs the 52-byte AUX-bank-switch loader to $0300, PR#3,
///                    BLOADs ART80.BIN to $2000, CALL 768 splits it into
///                    AUX/MAIN $0400
///
/// The ML copiers are embedded as inline DATA in the BASIC loaders (rather
/// than separate BIN files) so we only need ONE BLOAD per program — fewer
/// chances to hit BASIC.SYSTEM's "NO BUFFERS AVAILABLE" error.
struct DiskExporter {

    enum DiskExportError: Error, LocalizedError {
        case templateMissing
        case write(String)

        var errorDescription: String? {
            switch self {
            case .templateMissing:
                return "Bundled ProDOS template image is missing from the app."
            case .write(let msg):
                return "ProDOS write failed: \(msg)"
            }
        }
    }

    /// Async — copies the bundled template to `url`, then adds the relevant
    /// files for the result's column mode.
    static func save(_ result: ASCIIResult, to url: URL) async throws {
        // Locate the bundled template
        guard let templateURL = Bundle.main.url(forResource: "ProDOS_2_4_3", withExtension: "po") else {
            throw DiskExportError.templateMissing
        }

        // Remove existing destination if user picked an existing file
        if FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.removeItem(at: url)
        }

        // Step 1 — copy template, rename volume to /ASCII.ART
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            ProDOSWriter.shared.createBootableDiskImage(
                at: url,
                templatePath: templateURL,
                volumeName: "ASCII.ART"
            ) { ok, msg in
                if ok { cont.resume() }
                else  { cont.resume(throwing: DiskExportError.write(msg)) }
            }
        }

        // Step 2 — tokenize and add the BASIC PRINT program (always)
        let printSource = BASICExporter.generateSource(result)
        let printTokens = ApplesoftTokenizer.tokenize(printSource)
        try await addFile(to: url, name: "ART.BAS",
                          data: printTokens, type: 0xFC, aux: 0x0801)

        // Step 3 — add the binary dump + BLOAD-based loader
        if result.columns == 40 {
            // 40-col: 1024-byte $400-format dump at $2000
            let bin = AppleIIScreenMemory.buildScreen40(grid: result.grid)
            try await addFile(to: url, name: "ART.BIN",
                              data: bin, type: 0x06, aux: 0x2000)

            let loaderTokens = ApplesoftTokenizer.tokenize(loaderSource40())
            try await addFile(to: url, name: "LOADER.BAS",
                              data: loaderTokens, type: 0xFC, aux: 0x0801)
        } else {
            // 80-col: 2048-byte combined dump (1024 AUX + 1024 MAIN) at $2000
            let bin = AppleIIScreenMemory.buildScreen80(grid: result.grid)
            try await addFile(to: url, name: "ART80.BIN",
                              data: bin, type: 0x06, aux: 0x2000)

            let loaderTokens = ApplesoftTokenizer.tokenize(loaderSource80())
            try await addFile(to: url, name: "LOADER80.BAS",
                              data: loaderTokens, type: 0xFC, aux: 0x0801)
        }
    }

    // MARK: - Loader source

    /// 40-col BASIC loader. POKEs the 30-byte copier to $0300, BLOADs
    /// ART.BIN to $2000, then CALL 768 copies $2000-$23FF to $0400-$07FF.
    private static func loaderSource40() -> String {
        let copier   = AppleIIScreenMemory.loader40
        let dataStart = 100
        let data      = AppleIIScreenMemory.dataLines(
            for: copier, startingAtLine: dataStart, lineStep: 10, bytesPerLine: 8
        )

        var src = ""
        src += "10 HOME\r"
        src += "20 FOR I = 0 TO \(copier.count - 1)\r"
        src += "30 READ B\r"
        src += "40 POKE 768 + I, B\r"
        src += "50 NEXT I\r"
        src += "60 PRINT CHR$(4);\"BLOAD ART.BIN,A$2000\"\r"
        src += "70 CALL 768\r"
        src += "80 GET A$\r"
        src += "90 HOME\r"
        src += data            // 100, 110, …
        return src.trimmingCharacters(in: .newlines)
    }

    /// 80-col BASIC loader. PR#3, POKEs the 52-byte AUX bank-switch loader to
    /// $0300, BLOADs ART80.BIN to $2000, CALL 768 splits the 2048 bytes into
    /// AUX $0400 (first 1024) and MAIN $0400 (next 1024).
    private static func loaderSource80() -> String {
        let copier    = AppleIIScreenMemory.loader80
        let dataStart = 200
        let data      = AppleIIScreenMemory.dataLines(
            for: copier, startingAtLine: dataStart, lineStep: 10, bytesPerLine: 8
        )

        var src = ""
        src += "10 PRINT CHR$(4);\"PR#3\"\r"
        src += "20 HOME\r"
        src += "30 FOR I = 0 TO \(copier.count - 1)\r"
        src += "40 READ B\r"
        src += "50 POKE 768 + I, B\r"
        src += "60 NEXT I\r"
        src += "70 PRINT CHR$(4);\"BLOAD ART80.BIN,A$2000\"\r"
        src += "80 CALL 768\r"
        src += "90 GET A$\r"
        src += "100 PRINT CHR$(4);\"PR#0\"\r"
        src += "110 TEXT\r"
        src += "120 HOME\r"
        src += data            // 200, 210, …
        return src.trimmingCharacters(in: .newlines)
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
