import SwiftUI

struct ExportSheet: View {
    @ObservedObject var vm: ConverterViewModel
    @Environment(\.dismiss) private var dismiss

    private var isAppleII: Bool { vm.settings.platform.isAppleII }

    @State private var format: ExportFormat = .macText

    enum ExportFormat: String, CaseIterable, Identifiable {
        case prodosDisk    = "Apple II Disk Image (.po)"
        case appleIIText   = "Apple II Text (.txt, CR endings)"
        case applesoftBASIC = "Applesoft BASIC (.bas)"
        case macText       = "Mac Text (.txt, LF endings)"
        var id: String { rawValue }
    }

    /// Formats available for the current platform.
    private var availableFormats: [ExportFormat] {
        if isAppleII {
            return ExportFormat.allCases
        } else {
            return [.macText]
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Export ASCII Art")
                .chromeFont(.headline)
                .chromeForeground(.primary)

            Picker("Format", selection: $format) {
                ForEach(availableFormats) { f in
                    Text(f.rawValue).tag(f)
                }
            }
            .pickerStyle(.radioGroup)
            .onAppear {
                // If current format isn't available (e.g. switched from Apple II),
                // reset to mac text.
                if !availableFormats.contains(format) {
                    format = .macText
                }
            }
            .onChange(of: vm.settings.platform) { _, _ in
                if !availableFormats.contains(format) {
                    format = .macText
                }
            }

            Group {
                switch format {
                case .prodosDisk:
                    Text("Bootable ProDOS disk. Boot the disk and a STARTUP menu auto-runs, letting you pick between four programs: ART40 / LOADER40 (40-col) and ART80 / LOADER80 (80-col). The ART files are the slow PRINT-based path; the LOADER files use an embedded ML copier + BLOAD for fast display. Mount in any Apple II emulator (Virtual II, OpenEmu, AppleWin) or write to a real disk.")
                case .appleIIText:
                    Text("Plain text with CR (0x0D) line endings. Transfer to Apple II via ADT Pro or similar and TYPE the file.")
                case .applesoftBASIC:
                    Text("Applesoft BASIC program using PRINT statements. RUN it on your Apple IIe/IIc/IIgs. Use PR#3 for 80-col output (included automatically).")
                case .macText:
                    Text("Plain text with LF line endings for editing on Mac or transferring to any system.")
                }
            }
            .chromeFont(.caption)
            .chromeForeground(.secondary)
            .fixedSize(horizontal: false, vertical: true)

            Spacer()

            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Export…") {
                    dismiss()
                    switch format {
                    case .prodosDisk:     vm.exportProDOSDisk()
                    case .appleIIText:    vm.exportText(appleII: true)
                    case .applesoftBASIC: vm.exportBASIC()
                    case .macText:        vm.exportText(appleII: false)
                    }
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(width: 460, height: 320)
        .chromeBackground(.main)
    }
}
