import SwiftUI

/// Full-area overlay that lets the user pick a crop region from the source image.
/// The crop rect (normalised 0-1, top-left origin) is written back to the VM live
/// so the ASCII converter re-runs as the user drags.
struct CropToolOverlay: View {
    @ObservedObject var vm: ConverterViewModel

    // Display state (local to this overlay session)
    @State private var zoom: CGFloat  = 1.0
    @State private var pan:  CGSize   = .zero

    // Drag-gesture start snapshots
    @State private var moveStart:   CGRect?                            = nil
    @State private var resizeStart: (corner: Corner, rect: CGRect)?   = nil

    enum Corner: CaseIterable, Hashable { case tl, tr, bl, br }

    var body: some View {
        GeometryReader { geo in
            if let img = vm.sourceImage {
                cropContent(image: img, viewSize: geo.size)
            }
        }
    }

    // MARK: - Main content

    private func cropContent(image: NSImage, viewSize: CGSize) -> some View {
        let fit  = fitRect(image.size, in: viewSize)
        let disp = displayRect(fit: fit, zoom: zoom, pan: pan, view: viewSize)
        let crop = cropViewRect(norm: vm.cropRectNorm, in: disp)

        return ZStack(alignment: .bottom) {
            // 1 — black background
            Color.black.ignoresSafeArea()

            // 2 — source image
            Image(nsImage: image)
                .resizable()
                .frame(width: disp.width, height: disp.height)
                .position(x: disp.midX, y: disp.midY)
                .allowsHitTesting(false)

            // 3 — dimming with punched-out crop hole
            DimmingCanvas(cropRect: crop)

            // 4 — crop border + rule-of-thirds lines
            CropBorderCanvas(cropRect: crop)

            // 5 — invisible move target (crop box interior)
            Color.clear
                .contentShape(Rectangle())
                .frame(width: max(crop.width  - 24, 4),
                       height: max(crop.height - 24, 4))
                .position(x: crop.midX, y: crop.midY)
                .gesture(moveGesture(disp: disp))

            // 6 — corner handles
            ForEach(Corner.allCases, id: \.self) { corner in
                Circle()
                    .fill(Color.white)
                    .shadow(color: .black.opacity(0.5), radius: 2)
                    .frame(width: 14, height: 14)
                    .position(cornerPos(corner, in: crop))
                    .gesture(resizeGesture(corner: corner, disp: disp))
            }

            // 7 — trackpad / scroll-wheel input (transparent, behind bottom bar)
            TrackpadReceiver(
                onMagnify: { delta in
                    zoom = clamp(zoom * (1 + delta), 1.0, 8.0)
                },
                onScroll: { dx, dy in
                    if zoom > 1.001 {
                        pan = CGSize(width: pan.width + dx, height: pan.height + dy)
                    }
                }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // 8 — bottom control bar
            bottomBar
        }
        .clipped()
    }

    // MARK: - Bottom bar

    private var bottomBar: some View {
        HStack {
            Button("Reset") {
                vm.resetCrop()
                zoom = 1.0
                pan  = .zero
            }
            .foregroundStyle(.white.opacity(0.85))

            Spacer()

            Button("Done") {
                vm.showCropTool = false
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.black.opacity(0.65))
    }

    // MARK: - Move gesture

    private func moveGesture(disp: CGRect) -> some Gesture {
        DragGesture(minimumDistance: 1)
            .onChanged { v in
                if moveStart == nil { moveStart = vm.cropRectNorm }
                guard let s = moveStart else { return }
                let dx = v.translation.width  / disp.width
                let dy = v.translation.height / disp.height
                vm.cropRectNorm = CGRect(
                    x: clamp(s.minX + dx, 0, 1 - s.width),
                    y: clamp(s.minY + dy, 0, 1 - s.height),
                    width:  s.width,
                    height: s.height
                )
            }
            .onEnded { _ in moveStart = nil }
    }

    // MARK: - Resize gesture (locked aspect ratio)

    private func resizeGesture(corner: Corner, disp: CGRect) -> some Gesture {
        let ar = vm.settings.platform.aspectRatio   // width / height
        return DragGesture(minimumDistance: 1)
            .onChanged { v in
                if resizeStart == nil { resizeStart = (corner, vm.cropRectNorm) }
                guard let info = resizeStart else { return }
                let s  = info.rect
                let dx = v.translation.width  / disp.width
                let dy = v.translation.height / disp.height

                // Raw width delta: positive = grow. Sign depends on which corner.
                let dxSigned: CGFloat = (corner == .tr || corner == .br) ?  dx : -dx
                let dyToW:    CGFloat = (corner == .bl || corner == .br) ?  dy : -dy
                // Average x and y contributions (dy projected via AR)
                let dw = (dxSigned + dyToW * ar) / 2

                let newW = clamp(s.width + dw, 0.05, 1.0)
                let newH = newW / ar

                // Keep opposite corner fixed
                var nx = s.minX, ny = s.minY
                switch corner {
                case .tl: nx = s.maxX - newW; ny = s.maxY - newH
                case .tr: nx = s.minX;        ny = s.maxY - newH
                case .bl: nx = s.maxX - newW; ny = s.minY
                case .br: nx = s.minX;        ny = s.minY
                }

                // Clamp so the box stays fully within the image
                let cx = clamp(nx, 0, 1 - newW)
                let cy = clamp(ny, 0, 1 - newH)
                let cw = clamp(newW, 0.05, 1 - cx)
                let ch = clamp(newH, 0.05, 1 - cy)
                vm.cropRectNorm = CGRect(x: cx, y: cy, width: cw, height: ch)
            }
            .onEnded { _ in resizeStart = nil }
    }

    // MARK: - Coordinate helpers

    private func fitRect(_ imageSize: CGSize, in view: CGSize) -> CGRect {
        let s = min(view.width / imageSize.width, view.height / imageSize.height)
        let w = imageSize.width * s, h = imageSize.height * s
        return CGRect(x: (view.width - w) / 2, y: (view.height - h) / 2,
                      width: w, height: h)
    }

    private func displayRect(fit: CGRect, zoom: CGFloat,
                              pan: CGSize, view: CGSize) -> CGRect {
        let w = fit.width * zoom, h = fit.height * zoom
        return CGRect(x: view.width  / 2 + pan.width  - w / 2,
                      y: view.height / 2 + pan.height - h / 2,
                      width: w, height: h)
    }

    private func cropViewRect(norm: CGRect, in disp: CGRect) -> CGRect {
        CGRect(x: disp.minX + norm.minX * disp.width,
               y: disp.minY + norm.minY * disp.height,
               width:  norm.width  * disp.width,
               height: norm.height * disp.height)
    }

    private func cornerPos(_ c: Corner, in r: CGRect) -> CGPoint {
        switch c {
        case .tl: return CGPoint(x: r.minX, y: r.minY)
        case .tr: return CGPoint(x: r.maxX, y: r.minY)
        case .bl: return CGPoint(x: r.minX, y: r.maxY)
        case .br: return CGPoint(x: r.maxX, y: r.maxY)
        }
    }
}

// MARK: - Dimming canvas (even-odd punch-out)

private struct DimmingCanvas: View {
    let cropRect: CGRect
    var body: some View {
        Canvas { ctx, size in
            var path = Path(CGRect(origin: .zero, size: size))
            path.addRect(cropRect)
            ctx.fill(path, with: .color(.black.opacity(0.52)),
                     style: FillStyle(eoFill: true))
        }
        .allowsHitTesting(false)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Crop border + rule-of-thirds grid

private struct CropBorderCanvas: View {
    let cropRect: CGRect
    var body: some View {
        Canvas { ctx, size in
            // Outer border
            ctx.stroke(Path(cropRect), with: .color(.white), lineWidth: 1.5)

            // Rule-of-thirds grid
            let w = cropRect.width, h = cropRect.height
            var grid = Path()
            for i in 1...2 {
                let x = cropRect.minX + CGFloat(i) * w / 3
                grid.move(to: CGPoint(x: x, y: cropRect.minY))
                grid.addLine(to: CGPoint(x: x, y: cropRect.maxY))
                let y = cropRect.minY + CGFloat(i) * h / 3
                grid.move(to: CGPoint(x: cropRect.minX, y: y))
                grid.addLine(to: CGPoint(x: cropRect.maxX, y: y))
            }
            ctx.stroke(grid, with: .color(.white.opacity(0.3)), lineWidth: 0.5)
        }
        .allowsHitTesting(false)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Trackpad / scroll-wheel NSView bridge

private struct TrackpadReceiver: NSViewRepresentable {
    var onMagnify: (CGFloat) -> Void
    var onScroll:  (CGFloat, CGFloat) -> Void

    func makeNSView(context: Context) -> Receiver { Receiver(parent: self) }
    func updateNSView(_ v: Receiver, context: Context) { v.parent = self }

    class Receiver: NSView {
        var parent: TrackpadReceiver
        init(parent: TrackpadReceiver) {
            self.parent = parent
            super.init(frame: .zero)
        }
        required init?(coder: NSCoder) { fatalError() }

        /// Only "exist" for scroll/magnify events. For mouse-down/drag/up we
        /// return nil so the events pass through to the SwiftUI gesture
        /// targets (move area + corner handles) layered on top.
        override func hitTest(_ point: NSPoint) -> NSView? {
            guard let event = NSApp.currentEvent else { return nil }
            switch event.type {
            case .scrollWheel, .magnify, .smartMagnify,
                 .beginGesture, .endGesture:
                return super.hitTest(point)
            default:
                return nil
            }
        }

        override func magnify(with event: NSEvent) {
            parent.onMagnify(event.magnification)
        }

        override func scrollWheel(with event: NSEvent) {
            if event.hasPreciseScrollingDeltas {
                // Trackpad two-finger scroll → pan
                parent.onScroll(event.scrollingDeltaX, event.scrollingDeltaY)
            } else {
                // Mouse wheel → zoom
                let delta: CGFloat = event.deltaY > 0 ? 0.1 : -0.1
                parent.onMagnify(delta)
            }
        }
    }
}

// MARK: - Clamp helper (fileprivate to avoid collisions)

fileprivate func clamp(_ v: CGFloat, _ lo: CGFloat, _ hi: CGFloat) -> CGFloat {
    Swift.max(lo, Swift.min(hi, v))
}
