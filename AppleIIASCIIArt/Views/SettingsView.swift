import SwiftUI

/// Settings window content. Wired into the macOS Settings… menu (Cmd+,) by
/// the `Settings { SettingsView() }` scene in `AppleIIASCIIArtApp`.
struct SettingsView: View {
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        Form {
            Section {
                Picker("UI Theme", selection: $settings.theme) {
                    ForEach(UITheme.allCases) { theme in
                        Text(theme.rawValue).tag(theme)
                    }
                }
                .pickerStyle(.radioGroup)
                .labelsHidden()
            } header: {
                Text("Appearance")
                    .chromeFont(.headline)
                    .chromeForeground(.primary)
            } footer: {
                Text("The selected theme re-skins the app's sidebar, dialogs, and help window. The ASCII-art preview always follows the column-mode and screen-color settings.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(20)
        .frame(width: 440, height: 320)
        .chromeBackground(.main)
    }
}
