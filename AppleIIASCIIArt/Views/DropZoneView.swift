import SwiftUI
import UniformTypeIdentifiers

struct DropZoneView: View {
    let onOpenFile: () -> Void
    let onDropProviders: ([NSItemProvider]) -> Void

    /// Drop-zone heading (e.g. "DROP IMAGE HERE" / "DROP VIDEO HERE").
    var title: String = "DROP IMAGE HERE"
    /// Optional second line — typically a "supported formats" hint.
    var subtitle: String? = nil
    /// Primary-action button label.
    var buttonLabel: String = "Open Image…"
    /// SF Symbol shown above the title.
    var iconName: String = "photo.badge.plus"
    /// UTTypes accepted for drag-and-drop. The default covers still images;
    /// pass an explicit list for video / other content.
    var acceptedTypes: [UTType] = [.fileURL, .image, .png, .jpeg, .tiff]

    @State private var isTargeted = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(
                    style: StrokeStyle(lineWidth: 2, dash: [10, 6])
                )
                .foregroundColor(isTargeted ? .accentColor : Color.secondary.opacity(0.4))
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isTargeted ? Color.accentColor.opacity(0.05) : Color.clear)
                )

            VStack(spacing: 20) {
                Image(systemName: iconName)
                    .font(.system(size: 52))
                    .chromeForeground(.secondary)

                VStack(spacing: 6) {
                    // Keep PrintChar21 here as a brand element regardless of theme.
                    Text(title)
                        .font(.custom("PrintChar21", size: 18))
                        .chromeForeground(.secondary)

                    if let subtitle {
                        Text(subtitle)
                            .chromeFont(.caption)
                            .chromeForeground(.secondary)
                    }
                }

                Button(buttonLabel) { onOpenFile() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
            }
        }
        .onDrop(of: acceptedTypes, isTargeted: $isTargeted) { providers in
            onDropProviders(providers)
            return true
        }
    }
}
