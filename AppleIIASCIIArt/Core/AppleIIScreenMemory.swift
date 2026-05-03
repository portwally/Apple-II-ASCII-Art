import Foundation

/// Builds raw text-screen-memory dumps suitable for `BLOAD` on an Apple II.
///
/// The Apple II text page 1 lives at $0400-$07FF (1024 bytes). The 24 rows are not
/// stored linearly — they are grouped in 3 blocks of 8 rows each. For row R:
///
///     group  g = R / 8           (0, 1, or 2)
///     line   l = R % 8           (0..7)
///     offset   = g * 0x28 + l * 0x80
///
/// The 8 bytes between offset 40 (`$28`) and offset 48 (`$30`) of each line slot
/// are "screen holes" — not displayed. We leave them as $00.
///
/// Characters are stored as ASCII with the high bit set (e.g. 'A' = 0xC1) so they
/// render as normal video. Spaces use 0xA0.
enum AppleIIScreenMemory {

    private static let rowsPerScreen = 24
    private static let pageSize = 1024  // bytes

    // MARK: - 40-column

    /// Build a 1024-byte $400-format dump for 40-col mode. Load with `BLOAD ART.BIN`.
    static func buildScreen40(grid: [[Character]]) -> Data {
        var buffer = Data(count: pageSize)
        let rows = min(grid.count, rowsPerScreen)
        for row in 0..<rows {
            let cells = grid[row]
            let lineBase = lineOffset(forRow: row)
            // Initialize the visible 40 bytes of this row to space (0xA0)
            for i in 0..<40 { buffer[lineBase + i] = 0xA0 }
            let cols = min(cells.count, 40)
            for col in 0..<cols {
                buffer[lineBase + col] = byte(for: cells[col])
            }
        }
        return buffer
    }

    // MARK: - 80-column

    /// Build a 2048-byte combined dump for 80-col mode.
    /// First 1024 bytes  → AUX  $0400 (even columns 0, 2, 4, …, 78)
    /// Next  1024 bytes  → MAIN $0400 (odd  columns 1, 3, 5, …, 79)
    /// Use together with `loader80` (a small ML routine that BLOADs into AUX).
    static func buildScreen80(grid: [[Character]]) -> Data {
        var aux  = Data(count: pageSize)
        var main = Data(count: pageSize)
        let rows = min(grid.count, rowsPerScreen)
        for row in 0..<rows {
            let cells = grid[row]
            let lineBase = lineOffset(forRow: row)
            // Initialize visible 40 bytes of each bank to space
            for i in 0..<40 {
                aux[lineBase + i]  = 0xA0
                main[lineBase + i] = 0xA0
            }
            let cols = min(cells.count, 80)
            for col in 0..<cols {
                let halfCol = col / 2
                if col % 2 == 0 {
                    aux[lineBase + halfCol]  = byte(for: cells[col])
                } else {
                    main[lineBase + halfCol] = byte(for: cells[col])
                }
            }
        }
        return aux + main
    }

    /// 6502 machine-code loader for 80-col mode.
    ///
    /// Loads at $0300 (52 bytes). Expects the 2048-byte combined dump to already
    /// be present at $2000 (BLOAD'd before calling). Then:
    ///
    ///   1. STA $C005 — switch to AUX RAM write
    ///   2. Copy 1024 bytes from $2000 → $0400 (now in AUX)
    ///   3. STA $C004 — switch back to MAIN RAM write
    ///   4. Copy 1024 bytes from $2400 → $0400 (in MAIN)
    ///
    /// CALL 768 from BASIC to invoke.
    static let loader80: Data = Data([
        // setup pointers
        0xA9, 0x00,        // LDA #$00
        0x85, 0x40,        // STA $40    ; src low
        0xA9, 0x20,        // LDA #$20
        0x85, 0x41,        // STA $41    ; src high  ($2000)
        0xA9, 0x00,        // LDA #$00
        0x85, 0x42,        // STA $42    ; dst low
        0xA9, 0x04,        // LDA #$04
        0x85, 0x43,        // STA $43    ; dst high  ($0400)
        // copy first 1024 bytes to AUX $400
        0x8D, 0x05, 0xC0,  // STA $C005  ; RAMWRTON
        0x20, 0x21, 0x03,  // JSR $0321  ; copy 1024
        0x8D, 0x04, 0xC0,  // STA $C004  ; RAMWRTOFF
        // reset dst high to $04 ($43 was incremented to $08)
        0xA9, 0x04,        // LDA #$04
        0x85, 0x43,        // STA $43
        0x20, 0x21, 0x03,  // JSR $0321  ; copy next 1024 to MAIN $400
        0x60,              // RTS
        // COPY routine at $0321
        0xA2, 0x04,        // LDX #$04   ; 4 pages
        0xA0, 0x00,        // LDY #$00
        0xB1, 0x40,        // LDA ($40),Y
        0x91, 0x42,        // STA ($42),Y
        0xC8,              // INY
        0xD0, 0xF9,        // BNE -7     ; back to LDA ($40),Y
        0xE6, 0x41,        // INC $41
        0xE6, 0x43,        // INC $43
        0xCA,              // DEX
        0xD0, 0xF0,        // BNE -16    ; back to LDY #$00
        0x60               // RTS
    ])

    // MARK: - Helpers

    private static func lineOffset(forRow row: Int) -> Int {
        let group = row / 8
        let line  = row % 8
        return group * 0x28 + line * 0x80
    }

    /// ASCII char → screen memory byte (high-bit set for normal video).
    /// Non-printable / out-of-range characters fall back to space.
    private static func byte(for ch: Character) -> UInt8 {
        guard let ascii = ch.asciiValue, ascii >= 0x20 && ascii < 0x7F else {
            return 0xA0
        }
        return ascii | 0x80
    }
}
