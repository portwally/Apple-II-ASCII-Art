import Foundation

/// 6502 machine-language players that stream ASCII-art video frames from a
/// ProDOS sequential file into Apple II text page 1. Both players are loaded
/// at `$0900` via `BRUN`. `BRUN` jumps to the load address, so the first three
/// bytes MUST be a JMP — otherwise the CPU executes the patched frame count
/// as opcodes (which manifests as the disk hanging after the BASIC wrapper
/// prints the BRUN command). The byte layout is:
///
///     $0900: JMP $0906     (4C 06 09 — entry point)
///     $0903: FRAME_LO      (total frame count, low byte)   [patched]
///     $0904: FRAME_HI      (total frame count, high byte)  [patched]
///     $0905: FPS_DLY       (outer delay-loop iterations)   [patched]
///     $0906: INIT          (the real code)
///
/// The 40-col player opens `FRAMES40`, reads 1 KB chunks into `$2000`, then
/// linearly copies them to text page 1 at `$0400-$07FF`. The 80-col player
/// opens `FRAMES80`, reads 2 KB chunks into `$4000`, splits them between
/// AUX `$0400` (via PAGE2 ON) and MAIN `$0400` (PAGE2 OFF). Both use ProDOS
/// MLI calls (`$BF00`) for file I/O.
///
/// Linear copies to `$0400` are correct because
/// `AppleIIScreenMemory.buildScreen40/80()` pre-scrambles each frame into the
/// non-contiguous text-page layout — the same trick `LOADER40/80` already use.
enum VideoMLPlayer {

    // MARK: - 40-column player
    //
    // Total size: 155 bytes ($0900-$099A).
    // Code path:
    //   • INIT — copy FRAME counter to REMAIN; MLI OPEN FRAMES40; HOME.
    //   • LOOP — if REMAIN==0, jump to DONE. MLI READ 1024 → $2000.
    //            Unrolled 4-page copy to $0400. Delay loop. Decrement
    //            REMAIN. Repeat.
    //   • DONE — MLI CLOSE, RTS to BASIC.
    static let play40Bytes: [UInt8] = [
        // --- Header: JMP to ENTRY_STUB, then the patchable data bytes ---
        // BRUN lands at $0900, so $0900-$0902 must be executable.
        // Entry goes via a diagnostic stub at $0977 (in the padding
        // area) that writes 'A' to $0400 and then falls into the
        // real INIT at $0906 — gives us proof-of-life on screen.
        0x4C, 0x77, 0x09,       // $0900 JMP $0977   (ENTRY_STUB)
        0x00,                   // $0903 FRAME_LO   [patched at file offset 3]
        0x00,                   // $0904 FRAME_HI   [patched at file offset 4]
        0x00,                   // $0905 FPS_DLY    [patched at file offset 5]

        // --- INIT at $0906: REMAIN ← FRAME ---
        0xAD, 0x03, 0x09,       // $0906 LDA $0903    (FRAME_LO)
        0x8D, 0x80, 0x09,       // $0909 STA $0980    (REMAIN_LO)
        0xAD, 0x04, 0x09,       // $090C LDA $0904    (FRAME_HI)
        0x8D, 0x81, 0x09,       // $090F STA $0981    (REMAIN_HI)

        // --- MLI OPEN ---
        0x20, 0x00, 0xBF,       // $0912 JSR $BF00
        0xC8,                   // $0915 .BYTE $C8    (OPEN)
        0x82, 0x09,             // $0916 .WORD $0982  (OPARMS)
        0xD0, 0x59,             // $0918 BNE +89 → $0973 (ERROR_STUB)

        // --- Copy file_ref_num into RPARMS+1 and CPARMS+1 ---
        0xAD, 0x87, 0x09,       // $091A LDA $0987    (OPARMS+5 = ref_num)
        0x8D, 0x89, 0x09,       // $091D STA $0989    (RPARMS+1)
        0x8D, 0x91, 0x09,       // $0920 STA $0991    (CPARMS+1)

        // --- HOME ($FC58 clears the 40-col text screen) ---
        0x20, 0x58, 0xFC,       // $0923 JSR $FC58

        // --- LOOP at $0926: check REMAIN ---
        0xAD, 0x80, 0x09,       // $0926 LDA $0980    (REMAIN_LO)
        0x0D, 0x81, 0x09,       // $0929 ORA $0981    (REMAIN_HI)
        0xF0, 0x3E,             // $092C BEQ +62 → $096C (DONE)

        // --- MLI READ 1024 bytes → $2000 ---
        0x20, 0x00, 0xBF,       // $092E JSR $BF00
        0xCA,                   // $0931 .BYTE $CA    (READ)
        0x88, 0x09,             // $0932 .WORD $0988  (RPARMS)
        0xD0, 0x36,             // $0934 BNE +54 → $096C (DONE on EOF/err)

        // --- Copy $2000-$23FF → $0400-$07FF (unrolled, 4 pages) ---
        0xA2, 0x00,             // $0936 LDX #$00
        // COPY at $0938:
        0xBD, 0x00, 0x20,       // $0938 LDA $2000,X
        0x9D, 0x00, 0x04,       // $093B STA $0400,X
        0xBD, 0x00, 0x21,       // $093E LDA $2100,X
        0x9D, 0x00, 0x05,       // $0941 STA $0500,X
        0xBD, 0x00, 0x22,       // $0944 LDA $2200,X
        0x9D, 0x00, 0x06,       // $0947 STA $0600,X
        0xBD, 0x00, 0x23,       // $094A LDA $2300,X
        0x9D, 0x00, 0x07,       // $094D STA $0700,X
        0xE8,                   // $0950 INX
        0xD0, 0xE5,             // $0951 BNE -27 → $0938 (COPY)

        // --- Delay (FPS pacing) ---
        0xAC, 0x05, 0x09,       // $0953 LDY $0905    (FPS_DLY)
        // DOUT at $0956:
        0xA2, 0x00,             // $0956 LDX #$00
        // DIN at $0958:
        0xCA,                   // $0958 DEX
        0xD0, 0xFD,             // $0959 BNE -3 → $0958
        0x88,                   // $095B DEY
        0xD0, 0xF8,             // $095C BNE -8 → $0956

        // --- Decrement REMAIN (16-bit) ---
        0xAD, 0x80, 0x09,       // $095E LDA $0980    (REMAIN_LO)
        0xD0, 0x03,             // $0961 BNE +3 → $0966 (SKIP_HI)
        0xCE, 0x81, 0x09,       // $0963 DEC $0981    (REMAIN_HI)
        // SKIP_HI at $0966:
        0xCE, 0x80, 0x09,       // $0966 DEC $0980    (REMAIN_LO)
        0x4C, 0x26, 0x09,       // $0969 JMP $0926    (LOOP)

        // --- DONE at $096C: MLI CLOSE, RTS ---
        0x20, 0x00, 0xBF,       // $096C JSR $BF00
        0xCC,                   // $096F .BYTE $CC    (CLOSE)
        0x90, 0x09,             // $0970 .WORD $0990  (CPARMS)
        // QUIT at $0972:
        0x60,                   // $0972 RTS

        // --- ERROR_STUB at $0973 (jumped to from BNE QUIT) ---
        // A holds the MLI error code (e.g. $46 = file not found).
        // Write it verbatim to the top-left of the screen so the user
        // sees a flashing letter on failure instead of a blank prompt.
        0x8D, 0x00, 0x04,       // $0973 STA $0400   (display error code)
        0x60,                   // $0976 RTS
        // --- ENTRY_STUB at $0977 (jumped to from JMP at $0900) ---
        // Write a normal-video 'A' at $0400 as proof the player ran,
        // then fall into the real INIT at $0906.
        0xA9, 0xC1,             // $0977 LDA #$C1    ('A', high-bit-set = normal video)
        0x8D, 0x00, 0x04,       // $0979 STA $0400   (top-left of text page 1)
        0x4C, 0x06, 0x09,       // $097C JMP $0906   (real INIT)
        0x00,                   // $097F padding

        // --- Data at $0980 ---
        0x00,                   // $0980 REMAIN_LO
        0x00,                   // $0981 REMAIN_HI

        // OPARMS at $0982 (6 bytes):
        0x03,                   // $0982 param_count = 3
        0x92, 0x09,             // $0983 pathname    = $0992 (FNAME)
        0x00, 0x10,             // $0985 io_buffer   = $1000
        0x00,                   // $0987 ref_num     (output)

        // RPARMS at $0988 (8 bytes):
        0x04,                   // $0988 param_count = 4
        0x00,                   // $0989 ref_num     (patched at runtime)
        0x00, 0x20,             // $098A data_buffer = $2000
        0x00, 0x04,             // $098C request_cnt = 1024 ($0400)
        0x00, 0x00,             // $098E trans_cnt   (output)

        // CPARMS at $0990 (2 bytes):
        0x01,                   // $0990 param_count = 1
        0x00,                   // $0991 ref_num     (patched at runtime)

        // FNAME at $0992 — **absolute** path "/VIDEO/FRAMES40".
        //
        // Relative paths like just "FRAMES40" resolve against ProDOS's
        // current prefix, which isn't always set when a BIN file is
        // BRUNned from BASIC.SYSTEM on an HDV — MLI then returns $40
        // (invalid pathname syntax). Absolute paths bypass the prefix.
        0x0F,                                                       // $0992 length = 15
        0x2F, 0x56, 0x49, 0x44, 0x45, 0x4F, 0x2F,                   // "/VIDEO/"
        0x46, 0x52, 0x41, 0x4D, 0x45, 0x53, 0x34, 0x30,             // "FRAMES40"
    ]

    // MARK: - 80-column player
    //
    // Total size: 190 bytes ($0900-$09BD).
    // Differences from the 40-col player:
    //   • Reads 2048 bytes into $4000 (HIRES page 2 — RAMWRT-switched, not
    //     80STORE-switched, so PAGE2 won't redirect $4000 reads to AUX).
    //   • Splits the chunk: first 1024 → AUX $0400 (PAGE2 ON), second 1024
    //     → MAIN $0400 (PAGE2 OFF).
    //   • Switches to 80-col internally via `JSR $C300` (the slot-3
    //     firmware entry — same code path `PR# 3` invokes).  Doing this
    //     from inside the player lets the BASIC wrapper BRUN us while
    //     still in 40-col mode, avoiding the well-known BASIC.SYSTEM
    //     ordering bug where `PR# 3` before a Ctrl-D command leaves
    //     COUT redirected to the 80-col card and the BRUN never reaches
    //     BASIC.SYSTEM.
    //   • FNAME = "FRAMES80".
    static let play80Bytes: [UInt8] = [
        // --- Header: JMP to ENTRY_STUB, then the patchable data bytes ---
        // Entry goes via a diagnostic stub at $099A (in the padding
        // area between code and data) that beeps and falls into the
        // real INIT — gives us audible proof-of-life.
        0x4C, 0x9A, 0x09,       // $0900 JMP $099A   (ENTRY_STUB)
        0x00,                   // $0903 FRAME_LO   [patched at file offset 3]
        0x00,                   // $0904 FRAME_HI   [patched at file offset 4]
        0x00,                   // $0905 FPS_DLY    [patched at file offset 5]

        // --- INIT at $0906 ---
        0xAD, 0x03, 0x09,       // $0906 LDA $0903    (FRAME_LO)
        0x8D, 0xA0, 0x09,       // $0909 STA $09A0    (REMAIN_LO)
        0xAD, 0x04, 0x09,       // $090C LDA $0904    (FRAME_HI)
        0x8D, 0xA1, 0x09,       // $090F STA $09A1    (REMAIN_HI)

        // --- MLI OPEN (still in 40-col mode, BASIC.SYSTEM hooked) ---
        0x20, 0x00, 0xBF,       // $0912 JSR $BF00
        0xC8,                   // $0915 .BYTE $C8    (OPEN)
        0xA2, 0x09,             // $0916 .WORD $09A2  (OPARMS)
        0xD0, 0x7C,             // $0918 BNE +124 → $0996 (ERROR_STUB)

        // --- Copy file_ref_num ---
        0xAD, 0xA7, 0x09,       // $091A LDA $09A7    (OPARMS+5)
        0x8D, 0xA9, 0x09,       // $091D STA $09A9    (RPARMS+1)
        0x8D, 0xB1, 0x09,       // $0920 STA $09B1    (CPARMS+1)

        // --- Activate 80-col mode (equivalent to `PR# 3`) ---
        0x20, 0x00, 0xC3,       // $0923 JSR $C300

        // --- LOOP at $0926 ---
        0xAD, 0xA0, 0x09,       // $0926 LDA $09A0    (REMAIN_LO)
        0x0D, 0xA1, 0x09,       // $0929 ORA $09A1    (REMAIN_HI)
        0xF0, 0x61,             // $092C BEQ +97 → $098F (DONE)

        // --- MLI READ 2048 bytes → $4000 ---
        0x20, 0x00, 0xBF,       // $092E JSR $BF00
        0xCA,                   // $0931 .BYTE $CA    (READ)
        0xA8, 0x09,             // $0932 .WORD $09A8  (RPARMS)
        0xD0, 0x59,             // $0934 BNE +89 → $098F (DONE)

        // --- PAGE2 ON: $0400 writes redirect to AUX (80STORE is on) ---
        0x8D, 0x55, 0xC0,       // $0936 STA $C055

        // --- Copy $4000-$43FF → $0400 (lands in AUX bank) ---
        0xA2, 0x00,             // $0939 LDX #$00
        // COPY_AUX at $093B:
        0xBD, 0x00, 0x40,       // $093B LDA $4000,X
        0x9D, 0x00, 0x04,       // $093E STA $0400,X
        0xBD, 0x00, 0x41,       // $0941 LDA $4100,X
        0x9D, 0x00, 0x05,       // $0944 STA $0500,X
        0xBD, 0x00, 0x42,       // $0947 LDA $4200,X
        0x9D, 0x00, 0x06,       // $094A STA $0600,X
        0xBD, 0x00, 0x43,       // $094D LDA $4300,X
        0x9D, 0x00, 0x07,       // $0950 STA $0700,X
        0xE8,                   // $0953 INX
        0xD0, 0xE5,             // $0954 BNE -27 → $093B (COPY_AUX)

        // --- PAGE2 OFF: back to MAIN ---
        0x8D, 0x54, 0xC0,       // $0956 STA $C054

        // --- Copy $4400-$47FF → $0400 (lands in MAIN bank) ---
        0xA2, 0x00,             // $0959 LDX #$00
        // COPY_MAIN at $095B:
        0xBD, 0x00, 0x44,       // $095B LDA $4400,X
        0x9D, 0x00, 0x04,       // $095E STA $0400,X
        0xBD, 0x00, 0x45,       // $0961 LDA $4500,X
        0x9D, 0x00, 0x05,       // $0964 STA $0500,X
        0xBD, 0x00, 0x46,       // $0967 LDA $4600,X
        0x9D, 0x00, 0x06,       // $096A STA $0600,X
        0xBD, 0x00, 0x47,       // $096D LDA $4700,X
        0x9D, 0x00, 0x07,       // $0970 STA $0700,X
        0xE8,                   // $0973 INX
        0xD0, 0xE5,             // $0974 BNE -27 → $095B (COPY_MAIN)

        // --- Delay ---
        0xAC, 0x05, 0x09,       // $0976 LDY $0905    (FPS_DLY)
        // DOUT at $0979:
        0xA2, 0x00,             // $0979 LDX #$00
        // DIN at $097B:
        0xCA,                   // $097B DEX
        0xD0, 0xFD,             // $097C BNE -3
        0x88,                   // $097E DEY
        0xD0, 0xF8,             // $097F BNE -8

        // --- Decrement REMAIN ---
        0xAD, 0xA0, 0x09,       // $0981 LDA $09A0
        0xD0, 0x03,             // $0984 BNE +3 → $0989 (SKIP_HI)
        0xCE, 0xA1, 0x09,       // $0986 DEC $09A1
        // SKIP_HI at $0989:
        0xCE, 0xA0, 0x09,       // $0989 DEC $09A0
        0x4C, 0x26, 0x09,       // $098C JMP $0926    (LOOP)

        // --- DONE at $098F ---
        0x20, 0x00, 0xBF,       // $098F JSR $BF00
        0xCC,                   // $0992 .BYTE $CC    (CLOSE)
        0xB0, 0x09,             // $0993 .WORD $09B0  (CPARMS)
        // QUIT at $0995:
        0x60,                   // $0995 RTS

        // --- ERROR_STUB at $0996 (jumped to from BNE QUIT) ---
        // A holds the MLI error code; write it to $0400 so the user
        // sees a flashing letter at top-left on failure. We're still
        // in 40-col mode (OPEN fails before JSR $C300), so $0400 is
        // the standard 40-col text page visible to the user.
        0x8D, 0x00, 0x04,       // $0996 STA $0400   (display error code)
        0x60,                   // $0999 RTS
        // --- ENTRY_STUB at $099A (jumped to from JMP at $0900) ---
        // Beep audibly to prove the player ran, then fall into INIT.
        0x20, 0xDD, 0xFB,       // $099A JSR $FBDD   (BELL1 — beep)
        0x4C, 0x06, 0x09,       // $099D JMP $0906   (real INIT)

        // --- Data at $09A0 ---
        0x00,                   // $09A0 REMAIN_LO
        0x00,                   // $09A1 REMAIN_HI

        // OPARMS at $09A2 (6 bytes):
        0x03,                   // $09A2 param_count = 3
        0xB2, 0x09,             // $09A3 pathname    = $09B2 (FNAME)
        0x00, 0x10,             // $09A5 io_buffer   = $1000
        0x00,                   // $09A7 ref_num

        // RPARMS at $09A8 (8 bytes):
        0x04,                   // $09A8 param_count = 4
        0x00,                   // $09A9 ref_num
        0x00, 0x40,             // $09AA data_buffer = $4000
        0x00, 0x08,             // $09AC request_cnt = 2048 ($0800)
        0x00, 0x00,             // $09AE trans_cnt

        // CPARMS at $09B0 (2 bytes):
        0x01,                   // $09B0 param_count = 1
        0x00,                   // $09B1 ref_num

        // FNAME at $09B2 — **absolute** path "/VIDEO/FRAMES80".
        // Same rationale as 40-col player above.
        0x0F,                                                       // $09B2 length = 15
        0x2F, 0x56, 0x49, 0x44, 0x45, 0x4F, 0x2F,                   // "/VIDEO/"
        0x46, 0x52, 0x41, 0x4D, 0x45, 0x53, 0x38, 0x30,             // "FRAMES80"
    ]

    // MARK: - FPS delay calibration

    /// Inner delay loop (256 × DEX + DEY/BNE) costs ≈ 1.25 ms per outer
    /// iteration on a 1 MHz 6502. After accounting for the ~125 ms disk
    /// read for a 40-col frame (~250 ms for 80-col), we choose the smallest
    /// outer-loop count that pads each frame up to the target period.
    ///
    /// The result is clamped to 1…255 — the byte is stored at offset 0x02
    /// of the player and read by `LDY FPS_DLY`.
    static func fpsDelayValue(fps: Double, twoKBFrame: Bool = false) -> UInt8 {
        guard fps > 0 else { return 1 }
        let periodMs    = 1000.0 / fps
        let readMs      = twoKBFrame ? 250.0 : 125.0    // ProDOS ≈ 8 KB/s
        let budgetMs    = max(0, periodMs - readMs)
        let outerMsCost = 1.25                          // inner loop cost
        let count       = max(1, Int((budgetMs / outerMsCost).rounded()))
        return UInt8(min(count, 255))
    }

    /// Patch the three data bytes that follow the entry JMP with the
    /// actual frame count and FPS delay. Bytes 0-2 of the binary are the
    /// JMP itself and must never change; the patchable header is at
    /// file offsets 3 (FRAME_LO), 4 (FRAME_HI), 5 (FPS_DLY).
    static func patched(_ bytes: [UInt8], frameCount: Int, fps: Double, twoKBFrame: Bool) -> Data {
        var out = bytes
        out[3] = UInt8(frameCount & 0xFF)
        out[4] = UInt8((frameCount >> 8) & 0xFF)
        out[5] = fpsDelayValue(fps: fps, twoKBFrame: twoKBFrame)
        return Data(out)
    }
}
