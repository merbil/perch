import AppKit
import SwiftUI

/// Perch's mark: four equaliser bars with a bird on the tallest one.
/// Drawn on a 160-point grid, the same as the logo board on the design canvas.
struct LogoMark: View {
    var bird: Color = Palette.tangerine
    var beak: Color = Palette.sun

    var body: some View {
        Canvas { context, size in
            let s = size.width / 160
            func rect(_ x: Double, _ y: Double, _ w: Double, _ h: Double) -> CGRect {
                CGRect(x: x * s, y: y * s, width: w * s, height: h * s)
            }
            let ink = GraphicsContext.Shading.color(Palette.ink)

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
struct AppIconView: View {
    /// Full canvas size; the tile follows Apple's 824-in-1024 icon grid.
    var size: CGFloat = 1024

    var body: some View {
        let tile = size * 824 / 1024
        let radius = tile * 0.23
        let line = tile * 0.03
        let shadow = tile * 0.04
        ZStack {
            RoundedRectangle(cornerRadius: radius, style: .continuous).fill(Palette.ink)
                .frame(width: tile, height: tile)
                .offset(x: shadow, y: shadow)
            RoundedRectangle(cornerRadius: radius, style: .continuous).fill(Palette.paper)
                .frame(width: tile, height: tile)
            RoundedRectangle(cornerRadius: radius, style: .continuous).strokeBorder(Palette.ink, lineWidth: line)
                .frame(width: tile, height: tile)
            // The mark's drawing sits a little right of its grid's centre; nudge it back.
            LogoMark().frame(width: tile * 0.84, height: tile * 0.84)
                .offset(x: -tile * 0.84 * 5 / 160, y: tile * 0.84 * 1.5 / 160)
        }
        .offset(x: -shadow / 2, y: -shadow / 2)
        .frame(width: size, height: size)
    }
}
