import SwiftUI

/// SwiftUI Canvas that renders a LORES / Double-LORES frame as a grid
/// of solid-colored rectangles, one per pixel of the source
/// `LoresFrameResult`. Used in the video preview pane when the user
/// has selected `lores40`, `dlores80`, or `bothLores` modes.
///
/// The canvas mimics the Apple II display proportions (40 × 48 cells
/// for LORES, 80 × 48 for DLORES) inside whatever rectangle the parent
/// gives us. Drawing 40×48 = 1 920 rects or 80×48 = 3 840 rects each
/// frame is well within SwiftUI Canvas's budget — no Metal needed for
/// the *preview* rendering itself (the heavy lifting is the quantization
/// upstream, which is already on the GPU).
struct LoresCanvas: View {
    let frame: LoresFrameResult

    var body: some View {
        GeometryReader { geo in
            let size  = geo.size
            let cellW = size.width  / CGFloat(frame.cols)
            let cellH = size.height / CGFloat(frame.rows)
            Canvas(
                opaque: true,
                colorMode: .linear,
                rendersAsynchronously: false
            ) { context, _ in
                context.fill(Path(CGRect(origin: .zero, size: size)),
                             with: .color(.black))
                // Sub-pixel rounding can leave 1-pixel gaps between
                // adjacent cells when cellW / cellH aren't integers.
                // Expanding each rect by half a pixel on each side
                // closes them without overdrawing more than necessary.
                let pad: CGFloat = 0.5
                for row in 0..<frame.rows {
                    for col in 0..<frame.cols {
                        let idx = Int(frame.indices[row][col])
                        guard idx >= 0 && idx < 16 else { continue }
                        let rect = CGRect(
                            x: CGFloat(col) * cellW - pad,
                            y: CGFloat(row) * cellH - pad,
                            width:  cellW + pad * 2,
                            height: cellH + pad * 2
                        )
                        context.fill(Path(rect),
                                     with: .color(AppleIILoresPalette.swiftColors[idx]))
                    }
                }
            }
            .frame(width: size.width, height: size.height)
        }
    }
}
