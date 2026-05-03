import SwiftUI
import Combine
import UniformTypeIdentifiers

@MainActor
class ConverterViewModel: ObservableObject {

    @Published var sourceImage: NSImage? = nil
    @Published var sourceImageName: String = ""
    @Published var settings: ConversionSettings = ConversionSettings()
    @Published var customRampText: String = " .:-=+*#%@"
    @Published var useCustomRamp: Bool = false
    @Published var result: ASCIIResult? = nil
    @Published var isConverting: Bool = false
    @Published var showExportSheet: Bool = false
    @Published var errorMessage: String? = nil

    private var conversionTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()

    init() {
        // Debounce settings changes before triggering conversion
        $settings
            .debounce(for: .milliseconds(150), scheduler: RunLoop.main)
            .dropFirst()
            .sink { [weak self] _ in self?.convert() }
            .store(in: &cancellables)

        $customRampText
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .dropFirst()
            .sink { [weak self] _ in
                if self?.useCustomRamp == true { self?.convert() }
            }
            .store(in: &cancellables)

        $useCustomRamp
            .dropFirst()
            .sink { [weak self] _ in self?.convert() }
            .store(in: &cancellables)
    }

    var effectiveRamp: CharacterRamp {
        if useCustomRamp {
            let chars = Array(customRampText).filter { $0.asciiValue != nil }
            return CharacterRamp(id: "custom", displayName: "Custom", characters: chars.isEmpty ? [" "] : chars)
        }
        return settings.ramp
    }

    // MARK: - Image loading

    func openImageFilePicker() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.png, .jpeg, .tiff, .gif, .bmp, .heic]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            Task { @MainActor in
                self?.loadImage(from: url)
            }
        }
    }

    func loadImage(from url: URL) {
        guard let image = NSImage(contentsOf: url) else {
            errorMessage = "Could not load image from \(url.lastPathComponent)."
            return
        }
        sourceImage = image
        sourceImageName = url.deletingPathExtension().lastPathComponent
        convert()
    }

    func loadDroppedProviders(_ providers: [NSItemProvider]) {
        guard let provider = providers.first else { return }

        if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier) { [weak self] item, _ in
                let url: URL? = {
                    if let directURL = item as? URL { return directURL }
                    if let data = item as? Data {
                        return URL(dataRepresentation: data, relativeTo: nil)
                    }
                    if let str = item as? String { return URL(string: str) }
                    return nil
                }()
                guard let url else { return }
                Task { @MainActor in self?.loadImage(from: url) }
            }
            return
        }

        if provider.canLoadObject(ofClass: NSImage.self) {
            _ = provider.loadObject(ofClass: NSImage.self) { [weak self] obj, _ in
                guard let image = obj as? NSImage else { return }
                Task { @MainActor in
                    self?.sourceImage = image
                    self?.sourceImageName = "dropped"
                    self?.convert()
                }
            }
        }
    }

    // MARK: - Conversion

    func convert() {
        guard let image = sourceImage else { return }
        conversionTask?.cancel()
        isConverting = true
        let snap = settings
        let ramp = effectiveRamp

        conversionTask = Task {
            let r = await Task.detached(priority: .userInitiated) {
                ASCIIConverter.convert(image: image, settings: snap, customRamp: ramp)
            }.value
            guard !Task.isCancelled else { return }
            self.result = r
            self.isConverting = false
        }
    }

    // MARK: - Export

    func exportText(appleII: Bool) {
        guard let result else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = "\(sourceImageName.isEmpty ? "ascii_art" : sourceImageName).txt"
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            do {
                if appleII {
                    try TextExporter.saveAppleIIText(result, to: url)
                } else {
                    try TextExporter.saveMacText(result, to: url)
                }
            } catch {
                Task { @MainActor in self.errorMessage = error.localizedDescription }
            }
        }
    }

    func exportBASIC() {
        guard let result else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "bas") ?? .plainText]
        panel.nameFieldStringValue = "\(sourceImageName.isEmpty ? "ascii_art" : sourceImageName).bas"
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            do {
                try BASICExporter.save(result, to: url)
            } catch {
                Task { @MainActor in self.errorMessage = error.localizedDescription }
            }
        }
    }

    func copyToClipboard() {
        guard let result else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(result.asPlainText(), forType: .string)
    }

    func exportProDOSDisk() {
        guard let result else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "po") ?? .data]
        panel.nameFieldStringValue = "\(sourceImageName.isEmpty ? "ascii_art" : sourceImageName).po"
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            Task {
                do {
                    try await DiskExporter.save(result, to: url)
                } catch {
                    await MainActor.run { self.errorMessage = error.localizedDescription }
                }
            }
        }
    }
}
