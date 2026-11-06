import AppKit
import SwiftUI

/// Perch's mark: four equaliser bars with a bird on the tallest one.
/// Drawn on a 160-point grid, the same as the logo board on the design canvas.
struct LogoMark: View {
    var bird: Color = Palette.tangerine
    var beak: Color = Palette.sun
    var ink: Color = Palette.ink

    var body: some View {
        Canvas { context, size in
            let s = size.width / 160
            func rect(_ x: Double, _ y: Double, _ w: Double, _ h: Double) -> CGRect {
                CGRect(x: x * s, y: y * s, width: w * s, height: h * s)
            }
            let ink = GraphicsContext.Shading.color(self.ink)

            for (x, y) in [(30.0, 92.0), (54, 66), (78, 80), (102, 62)] {
                context.fill(Path(roundedRect: rect(x, y, 18, 128 - y), cornerRadius: 5 * s), with: ink)
            }

            let body = Path(ellipseIn: rect(94, 29, 34, 30))
            context.fill(body, with: .color(bird))
            context.stroke(body, with: ink, lineWidth: 5 * s)

            var beakPath = Path()
            beakPath.move(to: CGPoint(x: 127 * s, y: 39 * s))
            beakPath.addLine(to: CGPoint(x: 140 * s, y: 44 * s))
            beakPath.addLine(to: CGPoint(x: 127 * s, y: 49 * s))
            beakPath.closeSubpath()
            context.fill(beakPath, with: .color(beak))
            context.stroke(beakPath, with: ink, style: StrokeStyle(lineWidth: 3.5 * s, lineJoin: .round))

            context.fill(Path(ellipseIn: rect(113.8, 35.8, 6.4, 6.4)), with: ink)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityLabel("Perch")
    }
}

/// The app icon: the mark on a paper tile with an ink outline and a hard shadow.
/// Everything stays inside the tile's rounded square: macOS 26 and later shrink an icon
/// that pokes out of it onto a grey plate.
struct AppIconView: View {
    /// Full canvas size; the tile follows Apple's 824-in-1024 icon grid.
    var size: CGFloat = 1024

    var body: some View {
        let tile = size * 824 / 1024
        let shape = RoundedRectangle(cornerRadius: tile * 0.225, style: .continuous)
        let line = tile * 0.03
        let shadow = tile * 0.035
        ZStack {
            // The shadow is the ink showing below and right of the paper.
            shape.fill(Palette.inkFixed)
            shape.fill(Palette.paperFixed).padding([.trailing, .bottom], shadow)
            shape.inset(by: line / 2).stroke(Palette.inkFixed, lineWidth: line).padding([.trailing, .bottom], shadow)
            // The mark's drawing sits a little right of its grid's centre; nudge it back.
            LogoMark(ink: Palette.inkFixed).frame(width: tile * 0.84, height: tile * 0.84)
                .offset(x: -tile * 0.84 * 5 / 160 - shadow / 2, y: tile * 0.84 * 1.5 / 160 - shadow / 2)
        }
        .frame(width: tile, height: tile)
        .clipShape(shape)
        .frame(width: size, height: size)
    }
}
