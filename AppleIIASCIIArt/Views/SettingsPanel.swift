import SwiftUI

struct SettingsPanel: View {
    @ObservedObject var vm: ConverterViewModel
    @ObservedObject private var appSettings = AppSettings.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                columnModeSection
                rowCountSection
                rampSection
                adjustmentsSection
                flipSection
                phosphorSection
            }
            .padding(16)
            .padding(.trailing, 5)
        }
        .frame(minWidth: 230, maxWidth: 270)
        .background(sidebarBackgroundColor)
    }

    /// Themed sidebar fill — falls back to the system control background under
    /// the System theme so the modern look is preserved exactly.
    private var sidebarBackgroundColor: Color {
        ChromeStyle(theme: appSettings.theme).sidebarBackground
            ?? Color(NSColor.controlBackgroundColor)
    }

    // MARK: - Column mode

    private var columnModeSection: some View {
        section(title: "Column Mode") {
            Picker("", selection: $vm.settings.columnMode) {
                ForEach(ConversionSettings.ColumnMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        }
    }

    // MARK: - Row count

    private var rowCountSection: some View {
        section(title: "Rows") {
            Picker("", selection: $vm.settings.rowCount) {
                Text("24 rows (1 screen)").tag(24)
                Text("48 rows (2 screens)").tag(48)
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
                    TextField("e.g.  .:-=+*#%@", text: $vm.customRampText)
                        .font(.system(size: 13, design: .monospaced))
                        .textFieldStyle(.roundedBorder)
                }
            } else {
                Text(vm.settings.ramp.characters.map(String.init).joined())
                    .font(.system(size: 10, design: .monospaced))
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

    // MARK: - Phosphor color

    private var phosphorSection: some View {
        section(title: "Screen Color") {
            Picker("", selection: $vm.settings.phosphorColor) {
                ForEach(ConversionSettings.PhosphorColor.allCases) { color in
                    Label {
                        Text(color.rawValue)
                    } icon: {
                        Circle()
                            .fill(color.color)
                            .frame(width: 12, height: 12)
                    }
                    .tag(color)
                }
            }
            .pickerStyle(.radioGroup)
            .labelsHidden()
        }
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
                    .font(.system(size: 11, design: .monospaced))   // keep monospaced for column alignment
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
