import SwiftUI
import UniformTypeIdentifiers

struct DropZoneView: View {
    let onOpenFile: () -> Void
    let onDropProviders: ([NSItemProvider]) -> Void
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
                Image(systemName: "photo.badge.plus")
                    .font(.system(size: 52))
                    .foregroundColor(.secondary)

                Text("DROP IMAGE HERE")
                    .font(.custom("PrintChar21", size: 18))
                    .foregroundColor(.secondary)

                Button("Open Image…") { onOpenFile() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
            }
        }
        .onDrop(of: [.fileURL, .image, .png, .jpeg, .tiff], isTargeted: $isTargeted) { providers in
            onDropProviders(providers)
            return true
        }
    }
}
