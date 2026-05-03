import Foundation

struct BASICExporter {

    /// Generates the Applesoft source text for the PRINT program.
    /// Used both for the .bas file export and for tokenizing onto a ProDOS disk.
    static func generateSource(_ result: ASCIIResult) -> String {
        var lines: [String] = []
        var num = 10

        lines.append("\(num) HOME")
        num += 10

        if result.columns == 80 {
            lines.append("\(num) PR# 3")
            num += 10
        }

        for row in result.grid {
            let escaped = escapeForApplesoft(String(row))
            lines.append("\(num) PRINT \"\(escaped)\"")
            num += 10
        }

        lines.append("\(num) END")

        return lines.joined(separator: "\r")
    }

    static func save(_ result: ASCIIResult, to url: URL) throws {
        let source = generateSource(result)
        guard let data = source.data(using: .ascii) else {
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
