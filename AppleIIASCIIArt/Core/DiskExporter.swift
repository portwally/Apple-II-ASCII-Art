import Foundation

/// Builds an Apple II ProDOS disk image (.po) containing the ASCII art result
/// in three forms (BASIC PRINT program, raw screen-memory binary dump, and a
/// BASIC loader for the binary dump).
///
/// The base image is the bundled `ProDOS_2_4_3.po`, which carries Bitsy Bye as
/// a launcher — when booted on real hardware or in an emulator, Bitsy Bye lists
/// every program on the disk and lets the user pick one.
///
/// 40-col output produces:
///   - ART.BAS     — tokenized PRINT program
///   - ART.BIN     — 1024-byte screen-page-1 dump (aux=$0400)
///   - LOADER.BAS  — `PRINT CHR$(4);"BLOAD ART.BIN"` + GET A$
///
/// 80-col output produces:
///   - ART.BAS       — tokenized PRINT program (auto-emits PR#3)
///   - ART80.BIN     — 2048-byte combined dump (aux=$2000)
///   - ART80.LDR     — 52-byte ML aux-bank-switch loader at $0300 (aux=$0300)
///   - LOADER80.BAS  — `PR#3` + 2 BLOADs + `CALL 768` + GET A$
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

        // Step 3 — add binary dump + loader
        if result.columns == 40 {
            // 40-col: 1024-byte $400-format dump + tiny BASIC loader
            let bin    = AppleIIScreenMemory.buildScreen40(grid: result.grid)
            try await addFile(to: url, name: "ART.BIN",
                              data: bin, type: 0x06, aux: 0x0400)

            let loaderSrc =
                "10 PRINT CHR$(4);\"CLOSE\"\r"               +
                "20 HOME\r"                                   +
                "30 PRINT CHR$(4);\"BLOAD ART.BIN\"\r"        +
                "40 GET A$\r"                                 +
                "50 TEXT\r"                                   +
                "60 HOME"
            let loaderTokens = ApplesoftTokenizer.tokenize(loaderSrc)
            try await addFile(to: url, name: "LOADER.BAS",
                              data: loaderTokens, type: 0xFC, aux: 0x0801)
        } else {
            // 80-col: 2048-byte combined dump + 52-byte ML loader + BASIC driver
            let bin    = AppleIIScreenMemory.buildScreen80(grid: result.grid)
            try await addFile(to: url, name: "ART80.BIN",
                              data: bin, type: 0x06, aux: 0x2000)

            try await addFile(to: url, name: "ART80.LDR",
                              data: AppleIIScreenMemory.loader80,
                              type: 0x06, aux: 0x0300)

            let loaderSrc =
                "10 PRINT CHR$(4);\"CLOSE\"\r"               +
                "20 PRINT CHR$(4);\"PR#3\"\r"                +
                "30 PRINT CHR$(4);\"BLOAD ART80.BIN\"\r"     +
                "40 PRINT CHR$(4);\"BLOAD ART80.LDR\"\r"     +
                "50 CALL 768\r"                              +
                "60 GET A$\r"                                +
                "70 PRINT CHR$(4);\"PR#0\"\r"                +
                "80 TEXT\r"                                  +
                "90 HOME"
            let loaderTokens = ApplesoftTokenizer.tokenize(loaderSrc)
            try await addFile(to: url, name: "LOADER80.BAS",
                              data: loaderTokens, type: 0xFC, aux: 0x0801)
        }
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
