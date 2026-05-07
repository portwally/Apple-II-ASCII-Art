import SwiftUI

struct SettingsPanel: View {
    @ObservedObject var vm: ConverterViewModel
    @ObservedObject private var appSettings = AppSettings.shared
    @State private var showCharacterPicker = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                platformSection
                rowCountSection
                rampSection
                adjustmentsSection
                flipSection
                screenColorSection
            }
            .padding(16)
            .padding(.trailing, 5)
        }
        .frame(minWidth: 230, maxWidth: 270)
        .background(sidebarBackgroundColor)
    }

    private var sidebarBackgroundColor: Color {
        ChromeStyle(theme: appSettings.theme).sidebarBackground
            ?? Color(NSColor.controlBackgroundColor)
    }

    // MARK: - Platform

    private var platformSection: some View {
        section(title: "Computer") {
            Picker("", selection: $vm.settings.platform) {
                ForEach(ComputerPlatform.allCases) { platform in
                    Text(platform.rawValue).tag(platform)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .onChange(of: vm.settings.platform) { _, newPlatform in
                // Restore this platform's remembered settings (or defaults).
                // applyPlatform also resets rowCount and ramp.
                vm.settings.applyPlatform(newPlatform)
                vm.useCustomRamp = false
                // Drop any custom-ramp characters the new platform's font
                // can't render (they'd otherwise show as '?' boxes).
                vm.pruneCustomRampToFont(newPlatform.fontName)
            }
        }
    }

    // MARK: - Row count

    private var rowCountSection: some View {
        let nativeRows = vm.settings.platform.rows
        return section(title: "Rows") {
            Picker("", selection: $vm.settings.rowCount) {
                Text("\(nativeRows) rows (1 screen)").tag(nativeRows)
                Text("\(nativeRows * 2) rows (2 screens)").tag(nativeRows * 2)
            }
            .pickerStyle(.radioGroup)
            .labelsHidden()
        }
    }

    // MARK: - Character ramp

    private var rampSection: some View {
        section(title: "Character Ramp") {
            Picker("", selection: $vm.settings.selectedRampID) {
                ForEach(CharacterRamp.allPresets) { ramp in
                    Text(ramp.displayName).tag(ramp.id)
                }
                Text("Custom").tag("custom")
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .onChange(of: vm.settings.selectedRampID) { _, newVal in
                vm.useCustomRamp = (newVal == "custom")
            }

            if vm.useCustomRamp {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Characters (dark → light):")
                        .chromeFont(.caption)
                        .chromeForeground(.secondary)
                    HStack(spacing: 4) {
                        TextField("e.g.  .:-=+*#%@", text: $vm.customRampText)
                            .font(.custom(vm.settings.platform.fontName, size: 13))
                            .textFieldStyle(.roundedBorder)
                        Button {
                            showCharacterPicker.toggle()
                        } label: {
                            Image(systemName: "rectangle.grid.3x2")
                                .imageScale(.medium)
                        }
                        .buttonStyle(.borderless)
                        .help("Browse font characters")
                        .popover(isPresented: $showCharacterPicker, arrowEdge: .trailing) {
                            CharacterPickerPopover(
                                fontName: vm.settings.platform.fontName,
                                rampText: $vm.customRampText
                            )
                        }
                    }
                }
            } else {
                Text(vm.settings.ramp.characters.map(String.init).joined())
                    .font(.custom(vm.settings.platform.fontName, size: 11))
                    .lineLimit(2)
                    .truncationMode(.tail)
                    .chromeForeground(.secondary)
            }
        }
    }

    // MARK: - Brightness / contrast / invert

    private var adjustmentsSection: some View {
        section(title: "Adjustments") {
            sliderRow(
                label: "Brightness",
                value: $vm.settings.brightness,
                range: -1.0...1.0,
                minIcon: "sun.min",
                maxIcon: "sun.max"
            )
            sliderRow(
                label: "Contrast",
                value: $vm.settings.contrast,
                range: -1.0...1.0,
                minIcon: "circle.lefthalf.filled",
                maxIcon: "circle.righthalf.filled"
            )
            Toggle("Invert", isOn: $vm.settings.invert)
                .toggleStyle(.checkbox)
        }
    }

    // MARK: - Flip

    private var flipSection: some View {
        section(title: "Flip") {
            HStack(spacing: 8) {
                Button {
                    vm.settings.flipHorizontal.toggle()
                } label: {
                    Label("Horizontal", systemImage: "arrow.left.and.right.righttriangle.left.righttriangle.right.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(vm.settings.flipHorizontal ? Color.accentColor.opacity(0.25) : Color.clear)
                )
                .help("Flip horizontally")

                Button {
                    vm.settings.flipVertical.toggle()
                } label: {
                    Label("Vertical", systemImage: "arrow.up.and.down.righttriangle.up.righttriangle.down.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(vm.settings.flipVertical ? Color.accentColor.opacity(0.25) : Color.clear)
                )
                .help("Flip vertically")
            }
        }
    }

    // MARK: - Screen color

    @ViewBuilder
    private var screenColorSection: some View {
        switch vm.settings.platform.colorMode {
        case .phosphor:
            phosphorSection
        case .palette(let name, let colors):
            paletteSection(name: name, colors: colors)
        }
    }

    private var phosphorSection: some View {
        section(title: "Screen Color") {
            Picker("", selection: phosphorBinding) {
                ForEach(ConversionSettings.ScreenColor.allCases) { color in
                    Label {
                        Text(color.rawValue)
                    } icon: {
                        Circle()
                            .fill(color.foregroundColor)
                            .frame(width: 12, height: 12)
                    }
                    .tag(color)
                }
            }
            .pickerStyle(.radioGroup)
            .labelsHidden()
        }
    }

    private func paletteSection(name: String, colors: [PaletteColor]) -> some View {
        section(title: "Screen Color") {
            VStack(alignment: .leading, spacing: 10) {
                Text("\(name) palette")
                    .chromeFont(.caption)
                    .chromeForeground(.secondary)

                Text("Foreground")
                    .chromeFont(.caption)
                    .chromeForeground(.secondary)
                ColorSwatchGrid(colors: colors, selection: fgBinding)

                Text("Background")
                    .chromeFont(.caption)
                    .chromeForeground(.secondary)
                ColorSwatchGrid(colors: colors, selection: bgBinding)
            }
        }
    }

    // MARK: - Bindings into ConversionSettings's per-platform color memory

    private var phosphorBinding: Binding<ConversionSettings.ScreenColor> {
        Binding(
            get: { vm.settings.currentPhosphor },
            set: { vm.settings.currentPhosphor = $0 }
        )
    }

    private var fgBinding: Binding<Int> {
        Binding(
            get: { vm.settings.paletteFGIndex },
            set: { vm.settings.paletteFGIndex = $0 }
        )
    }

    private var bgBinding: Binding<Int> {
        Binding(
            get: { vm.settings.paletteBGIndex },
            set: { vm.settings.paletteBGIndex = $0 }
        )
    }

    // MARK: - Helpers

    @ViewBuilder
    private func section<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .chromeFont(.headline)
                .chromeForeground(.primary)
            content()
        }
    }

    @ViewBuilder
    private func sliderRow(
        label: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        minIcon: String,
        maxIcon: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(label)
                    .chromeFont(.caption)
                    .chromeForeground(.secondary)
                Spacer()
                Text(String(format: "%+.0f%%", value.wrappedValue * 100))
                    .font(.system(size: 11, design: .monospaced))
                    .chromeForeground(.secondary)
                    .frame(width: 44, alignment: .trailing)
            }
            HStack(spacing: 4) {
                Image(systemName: minIcon)
                    .font(.system(size: 11))
                    .chromeForeground(.secondary)
                Slider(value: value, in: range)
                Image(systemName: maxIcon)
                    .font(.system(size: 11))
                    .chromeForeground(.secondary)
            }
        }
    }
}
