import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var vm = ConverterViewModel()

    var body: some View {
        HSplitView {
            SettingsPanel(vm: vm)

            VStack(spacing: 0) {
                PreviewView(vm: vm)

                // Status bar
                HStack(spacing: 12) {
                    if vm.isConverting {
                        ProgressView().scaleEffect(0.6)
                    }
                    if let result = vm.result {
                        Text("\(result.columns) × \(result.rows) characters")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.secondary)
                    } else {
                        Text("No image loaded")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color(NSColor.windowBackgroundColor))
                .overlay(Divider(), alignment: .top)
            }
        }
        .frame(minWidth: 820, minHeight: 560)
        .toolbar { toolbarContent }
        .sheet(isPresented: $vm.showExportSheet) {
            ExportSheet(vm: vm)
        }
        .alert("Error", isPresented: Binding(
            get: { vm.errorMessage != nil },
            set: { if !$0 { vm.errorMessage = nil } }
        )) {
            Button("OK") { vm.errorMessage = nil }
        } message: {
            Text(vm.errorMessage ?? "")
        }
        // Full-window drag & drop
        .onDrop(
            of: [.fileURL, .image, .png, .jpeg, .tiff, .gif, .bmp, .heic],
            isTargeted: nil
        ) { providers in
            vm.loadDroppedProviders(providers)
            return true
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button {
                vm.showExportSheet = true
            } label: {
                Label("Export", systemImage: "square.and.arrow.up")
            }
            .disabled(vm.result == nil)
            .keyboardShortcut("e", modifiers: .command)
            .help("Export ASCII art")
        }

        ToolbarItem(placement: .primaryAction) {
            Button {
                vm.copyToClipboard()
            } label: {
                Label("Copy", systemImage: "doc.on.doc")
            }
            .disabled(vm.result == nil)
            .keyboardShortcut("c", modifiers: [.command, .shift])
            .help("Copy to clipboard")
        }

        ToolbarItem(placement: .primaryAction) {
            Button {
                vm.openImageFilePicker()
            } label: {
                Label("Open Image", systemImage: "photo")
            }
            .keyboardShortcut("o", modifiers: .command)
            .help("Open image file")
        }
    }
}
