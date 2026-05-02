import Foundation

struct ASCIIResult {
    let columns: Int
    let rows: Int
    let grid: [[Character]]
    let sourceName: String

    // CR line endings for Apple II
    func asAppleIIText() -> String {
        grid.map { String($0) }.joined(separator: "\r")
    }

    // LF line endings for Mac
    func asPlainText() -> String {
        grid.map { String($0) }.joined(separator: "\n")
    }
}
