import Foundation

struct BASICExporter {

    static func save(_ result: ASCIIResult, to url: URL) throws {
        var lines: [String] = []
        var num = 10

        lines.append("\(num) HOME")
        num += 10

        if result.columns == 80 {
            // PR#3 activates the 80-column card on Apple IIe/IIc/IIgs
            lines.append("\(num) PR# 3")
            num += 10
        }

        for row in result.grid {
            let escaped = escapeForApplesoft(String(row))
            lines.append("\(num) PRINT \"\(escaped)\"")
            num += 10
        }

        lines.append("\(num) END")

        let program = lines.joined(separator: "\r")
        guard let data = program.data(using: .ascii) else {
            throw ExportError.encodingFailed
        }
        try data.write(to: url)
    }

    // Applesoft can't embed a literal " in a string — split around it
    private static func escapeForApplesoft(_ s: String) -> String {
        s.replacingOccurrences(of: "\"", with: "\"; CHR$(34); \"")
    }

    enum ExportError: Error, LocalizedError {
        case encodingFailed
        var errorDescription: String? { "Failed to encode BASIC program as ASCII." }
    }
}
