import SwiftUI

struct HelpView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {

                // MARK: - Header

                Text("1977")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                Text("Apple II ASCII art studio")
                    .font(.title3)
                    .foregroundStyle(.secondary)

                Divider().padding(.vertical, 4)

                // MARK: - Getting started

                section("Getting Started") {
                    Text("Drag any image into the window — PNG, JPEG, TIFF, GIF, BMP, or HEIC. Or click the icon in the toolbar to pick a file. The phosphor preview updates live as you adjust settings.")
                }

                // MARK: - Column mode

                section("Column Mode") {
                    Text("**40-col** uses the standard Apple II text screen (40 characters wide, PrintChar21 font).")
                    Text("**80-col** uses the 80-column card output (80 characters wide, PRNumber3 font). On real hardware this requires `PR# 3` — the exporter inserts that for you automatically.")
                }

                // MARK: - Rows

                section("Rows") {
                    Text("**24 rows** fits exactly one Apple II text screen. **48 rows** is two screens stacked vertically — taller subjects gain detail, but on a real Apple II you'd need to scroll to see all of it.")
                }

                // MARK: - Ramps

                section("Character Ramp") {
                    Text("Each cell's brightness maps to a character from the chosen ramp (dark → light).")
                    Text("**Apple II Classic** uses characters that render well in PrintChar21. **Standard ASCII** is the classic `\" .:-=+*#%@\"` ramp. **Simple** and **Dense** offer different visual densities. Tick **Custom** to type your own character set — order matters (darkest first).")
                }

                // MARK: - Adjustments

                section("Adjustments") {
                    Text("**Brightness** shifts overall tone. **Contrast** stretches or compresses the brightness range. **Invert** flips dark and light — useful for white-on-black originals.")
                    Text("**Flip Horizontal / Vertical** mirrors the source image before sampling.")
                }

                // MARK: - Phosphor

                section("Phosphor Color") {
                    Text("Pick the simulated CRT phosphor — green (#33FF00), amber (#FFB000), or white. Affects only the on-screen preview; exports are plain text.")
                }

                // MARK: - Export

                section("Exporting") {
                    Text("Click **Export…** in the toolbar and choose a format:")

                    bullet("**Apple II Disk Image (.po)**",
                           "Bootable ProDOS disk with a STARTUP launcher and four ready-to-run programs (40-col & 80-col, slow PRINT versions and fast BLOAD versions). Mount in Virtual ][, OpenEmu, or AppleWin, or write to a real floppy with ADT Pro.")

                    bullet("**Apple II Text (.txt, CR endings)**",
                           "Plain ASCII with carriage-return line endings — the format the Apple II expects. Drop onto a ProDOS disk and `TYPE` it.")

                    bullet("**Mac Text (.txt, LF endings)**",
                           "For editing the output in any modern Mac editor.")

                    bullet("**Applesoft BASIC (.bas)**",
                           "A runnable `PRINT` program. Auto-inserts `PR# 3` for 80-col output.")
                }

                // MARK: - Disk launcher

                section("Booting the Disk") {
                    Text("Mount the `.po` disk image in any Apple II emulator and boot it. A STARTUP launcher auto-runs and shows four options:")

                    bullet("1) ART40", "Slow `PRINT`-based 40-col art. `LIST` it to see the actual source.")
                    bullet("2) LOADER40", "Fast 40-col version. POKEs a tiny 6502 routine, BLOADs a screen-memory dump, copies it straight to text page 1.")
                    bullet("3) ART80", "Slow 80-col `PRINT` version (auto-emits `PR# 3`).")
                    bullet("4) LOADER80", "Fast 80-col version. Uses an embedded ML routine to bank-switch into AUX RAM via `PAGE2`.")

                    Text("Press a key when the art is displayed to return to the BASIC `]` prompt. Reboot the disk to bring the menu back.")
                }

                // MARK: - Tips

                section("Tips") {
                    bullet("**Composition**", "Crop your source image to the same aspect ratio as the Apple II screen (≈ 280×192 ≈ 1.46:1) before importing for best results.")
                    bullet("**High-contrast subjects**", "Faces, logos, and silhouettes work best. Photos with subtle gradations may need extra contrast.")
                    bullet("**Custom ramp tricks**", "Try a ramp of just two characters (`\" #\"`) for a stark threshold look. Or use letters from a word for hidden-message effects.")
                }

                Divider().padding(.vertical, 4)

                // MARK: - Footer

                Text("© 2026 Walter Tengler")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(32)
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(minWidth: 720, idealWidth: 760, minHeight: 600, idealHeight: 760)
    }

    // MARK: - Helpers

    @ViewBuilder
    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.title2.bold())
            content()
        }
        .padding(.bottom, 4)
    }

    private func bullet(_ heading: LocalizedStringKey, _ body: LocalizedStringKey) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("•").foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(heading)
                Text(body)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.leading, 4)
    }
}

#Preview {
    HelpView()
}
