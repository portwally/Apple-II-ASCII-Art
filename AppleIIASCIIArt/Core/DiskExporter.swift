import Foundation

/// Builds an Apple II ProDOS disk image (.po) containing the ASCII art result
/// as a tokenized Applesoft BASIC program.
///
/// The base image is the bundled `ProDOS_2_4_3.po`, which carries Bitsy Bye as
/// a launcher — when booted on real hardware or in an emulator, Bitsy Bye lists
/// every program on the disk and lets the user pick one.
///
/// Output:
///   - ART.BAS — tokenized PRINT program. Auto-emits `PR#3` for 80-col mode.
///
/// (BLOAD-based fast loaders were tried but ProDOS reports
/// "NO BUFFERS AVAILABLE" under Bitsy Bye, and there is no portable BASIC
/// command to release the buffer pool — `MAXFILES` is DOS 3.3, not ProDOS.
/// The PRINT-based program is slower but rock-solid.)
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

    /// Async — copies the bundled template to `url`, then adds ART.BAS.
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

        // Step 2 — tokenize and add the BASIC PRINT program
        let printSource = BASICExporter.generateSource(result)
        let printTokens = ApplesoftTokenizer.tokenize(printSource)
        try await addFile(to: url, name: "ART.BAS",
                          data: printTokens, type: 0xFC, aux: 0x0801)
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
