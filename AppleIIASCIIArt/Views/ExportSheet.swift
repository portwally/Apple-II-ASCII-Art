import SwiftUI

struct ExportSheet: View {
    @ObservedObject var vm: ConverterViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var format: ExportFormat = .appleIIText

    enum ExportFormat: String, CaseIterable, Identifiable {
        case appleIIText = "Apple II Text (.txt, CR endings)"
        case macText = "Mac Text (.txt, LF endings)"
        case applesoftBASIC = "Applesoft BASIC (.bas)"
        var id: String { rawValue }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Export ASCII Art")
                .font(.headline)

            Picker("Format", selection: $format) {
                ForEach(ExportFormat.allCases) { f in
                    Text(f.rawValue).tag(f)
                }
            }
            .pickerStyle(.radioGroup)

            Group {
                switch format {
                case .appleIIText:
                    Text("Plain text with CR (0x0D) line endings. Transfer to Apple II via ADT Pro or similar and TYPE the file.")
                case .macText:
                    Text("Plain text with LF line endings for editing on Mac.")
                case .applesoftBASIC:
                    Text("Applesoft BASIC program using PRINT statements. RUN it on your Apple IIe/IIc/IIgs. Use PR#3 for 80-col output (included automatically).")
                }
            }
            .font(.caption)
            .foregroundColor(.secondary)
            .fixedSize(horizontal: false, vertical: true)

            Spacer()

            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Export…") {
                    dismiss()
                    switch format {
                    case .appleIIText:   vm.exportText(appleII: true)
                    case .macText:       vm.exportText(appleII: false)
                    case .applesoftBASIC: vm.exportBASIC()
                    }
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(width: 420, height: 260)
    }
}
