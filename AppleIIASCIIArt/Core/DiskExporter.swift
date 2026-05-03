import Foundation

/// Builds an Apple II ProDOS disk image (.po) carrying BOTH 40-col and 80-col
/// renderings of the same image.
///
/// The base image is the bundled `ProDOS_2_4_3.po`, which carries Bitsy Bye as
/// a launcher — when booted on real hardware or in an emulator, Bitsy Bye lists
/// every program on the disk and lets the user pick one.
///
/// Disk contents:
///   - ART40.BAS    — tokenized 40-col PRINT program
///   - ART40.BIN    — 1024-byte text-page-1 dump (aux=$2000)
///   - LOADER40.BAS — POKEs a 30-byte 6502 copier to $0300, BLOADs ART40.BIN
///                    to $2000, CALL 768 copies it to text page 1
///   - ART80.BAS    — tokenized 80-col PRINT program (auto-emits PR#3)
///   - ART80.BIN    — 2048-byte combined dump (aux=$2000)
///   - LOADER80.BAS — POKEs a 58-byte AUX-bank-switch loader to $0300, PR#3,
///                    BLOADs ART80.BIN to $2000, CALL 768 splits the 2048
///                    bytes into AUX/MAIN $0400
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

    /// Async — copies the bundled template to `url`, then adds both the 40-col
    /// and 80-col renderings of the image.
    static func save(result40: ASCIIResult,
                     result80: ASCIIResult,
                     to url: URL) async throws {
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

        // Step 2 — 40-col files
        let print40Tokens = ApplesoftTokenizer.tokenize(BASICExporter.generateSource(result40))
        try await addFile(to: url, name: "ART40.BAS",
                          data: print40Tokens, type: 0xFC, aux: 0x0801)

        let bin40 = AppleIIScreenMemory.buildScreen40(grid: result40.grid)
        try await addFile(to: url, name: "ART40.BIN",
                          data: bin40, type: 0x06, aux: 0x2000)

        let loader40Tokens = ApplesoftTokenizer.tokenize(loaderSource40())
        try await addFile(to: url, name: "LOADER40.BAS",
                          data: loader40Tokens, type: 0xFC, aux: 0x0801)

        // Step 3 — 80-col files
        let print80Tokens = ApplesoftTokenizer.tokenize(BASICExporter.generateSource(result80))
        try await addFile(to: url, name: "ART80.BAS",
                          data: print80Tokens, type: 0xFC, aux: 0x0801)

        let bin80 = AppleIIScreenMemory.buildScreen80(grid: result80.grid)
        try await addFile(to: url, name: "ART80.BIN",
                          data: bin80, type: 0x06, aux: 0x4000)

        let loader80Tokens = ApplesoftTokenizer.tokenize(loaderSource80())
        try await addFile(to: url, name: "LOADER80.BAS",
                          data: loader80Tokens, type: 0xFC, aux: 0x0801)
    }

    // MARK: - Loader source

    /// 40-col BASIC loader. POKEs the 30-byte copier to $0300, BLOADs
    /// ART40.BIN to $2000, then CALL 768 copies $2000-$23FF to $0400-$07FF.
    private static func loaderSource40() -> String {
        let copier    = AppleIIScreenMemory.loader40
        let dataStart = 100
        let data      = AppleIIScreenMemory.dataLines(
            for: copier, startingAtLine: dataStart, lineStep: 10, bytesPerLine: 8
        )

        var src = ""
        src += "5 NOTRACE\r"   // Bitsy Bye on this template leaves TRACE on
        src += "10 HOME\r"
        src += "20 FOR I = 0 TO \(copier.count - 1)\r"
        src += "30 READ B\r"
        src += "40 POKE 768 + I, B\r"
        src += "50 NEXT I\r"
        src += "60 PRINT CHR$(4);\"BLOAD ART40.BIN,A$2000\"\r"
        src += "70 CALL 768\r"
        src += "80 GET A$\r"
        src += "90 HOME\r"
        src += data            // 100, 110, …
        return src.trimmingCharacters(in: .newlines)
    }

    /// 80-col BASIC loader. POKEs the 52-byte loader to $0300 in 40-col mode
    /// FIRST, then PR# 3 (Applesoft token) switches to 80-col, BLOADs
    /// ART80.BIN to $4000, CALL 768 splits the 2048 bytes into AUX $0400 /
    /// MAIN $0400.
    private static func loaderSource80() -> String {
        let copier    = AppleIIScreenMemory.loader80
        let dataStart = 200
        let data      = AppleIIScreenMemory.dataLines(
            for: copier, startingAtLine: dataStart, lineStep: 10, bytesPerLine: 8
        )

        var src = ""
        src += "5 NOTRACE\r"   // Bitsy Bye on this template leaves TRACE on
        src += "10 HOME\r"
        src += "20 FOR I = 0 TO \(copier.count - 1)\r"
        src += "30 READ B\r"
        src += "40 POKE 768 + I, B\r"
        src += "50 NEXT I\r"
        src += "60 PR# 3\r"
        src += "70 HOME\r"
        src += "80 PRINT CHR$(4);\"BLOAD ART80.BIN,A$4000\"\r"
        src += "90 CALL 768\r"
        src += "100 GET A$\r"
        src += "110 PR# 0\r"
        src += "120 TEXT\r"
        src += "130 HOME\r"
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
