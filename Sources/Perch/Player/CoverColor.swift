import AppKit
import SwiftUI

/// The colors behind Stage's cover look, and whether the text on it should be light.
struct CoverBackground {
    var colors: (Color, Color)?
    var isDark: Bool
}

extension NSImage {
    /// The cover's most colorful hue, pushed bright so it fits next to the other accents.
    /// Nil for black-and-white or very dull covers.
    func vibrantAccent() -> Color? {
        guard let (hue, saturation) = coverHues().first else { return nil }
        return Color(hue: hue, saturation: min(max(saturation, 0.55), 0.85), brightness: 0.97)
    }

    /// Stage's cover look follows the cover: light covers get two pastel colors from it, dark covers two deep ones.
    /// When the cover has only one hue, the second is a neighbour of it, so the background still shifts a little.
    /// Black-and-white covers get no colors, just light or dark.
    func stageBackground() -> CoverBackground {
        let isDark = darkShare() > 0.55
        // Dark colors count here too: on a navy cover the navy is the color you notice. On a dark cover,
        // the color that covers the most wins, and the second is its neighbour: a deep yellow turns olive.
        let hues = coverHues(minBrightness: 0.1, byArea: isDark)
        guard let main = hues.first else { return CoverBackground(colors: nil, isDark: isDark) }
        let neighbour = ((main.0 + 0.07).truncatingRemainder(dividingBy: 1), main.1)
        let second = isDark ? neighbour : hues.dropFirst().first { circularDistance($0.0, main.0) > 0.15 } ?? neighbour
        func tone(_ h: (Double, Double)) -> Color {
            isDark ? Color(hue: h.0, saturation: min(max(h.1 * 0.8, 0.45), 0.7), brightness: 0.4)
                : Color(hue: h.0, saturation: min(max(h.1 * 0.45, 0.22), 0.36), brightness: 0.96)
        }
        return CoverBackground(colors: (tone(main), tone(second)), isDark: isDark)
    }

    /// How much of the cover is dark, from 0 to 1. Counting pixels rather than averaging them,
    /// so a dark cover with a bright spot on it still counts as dark.
    private func darkShare() -> Double {
        let side = 24
        guard let cgImage = cgImage(forProposedRect: nil, context: nil, hints: nil),
              let context = CGContext(data: nil, width: side, height: side, bitsPerComponent: 8, bytesPerRow: side * 4,
                                      space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return 0 }
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: side, height: side))
        guard let data = context.data?.assumingMemoryBound(to: UInt8.self) else { return 0 }
        var dark = 0
        for i in 0..<(side * side) {
            let luminance = (0.299 * Double(data[i * 4]) + 0.587 * Double(data[i * 4 + 1]) + 0.114 * Double(data[i * 4 + 2])) / 255
            if luminance < 0.35 { dark += 1 }
        }
        return Double(dark) / Double(side * side)
    }

    /// The cover's hues with their saturation, strongest first. Empty for black-and-white or very dull covers.
    private func coverHues(minBrightness: Double = 0.25, byArea: Bool = false) -> [(Double, Double)] {
        guard let cgImage = cgImage(forProposedRect: nil, context: nil, hints: nil) else { return [] }
        let side = 24
        guard let context = CGContext(
            data: nil, width: side, height: side, bitsPerComponent: 8, bytesPerRow: side * 4,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return [] }
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: side, height: side))
        guard let data = context.data?.assumingMemoryBound(to: UInt8.self) else { return [] }

        // Weight each hue bucket by how saturated and bright its pixels are.
        let buckets = 18
        var score = [Double](repeating: 0, count: buckets)
        var hueSum = [Double](repeating: 0, count: buckets)
        var saturationSum = [Double](repeating: 0, count: buckets)

        for i in 0..<(side * side) {
            let r = Double(data[i * 4]) / 255
            let g = Double(data[i * 4 + 1]) / 255
            let b = Double(data[i * 4 + 2]) / 255
            let (hue, saturation, brightness) = hsb(r, g, b)
            guard saturation > 0.25, brightness > minBrightness else { continue }
            let weight = saturation * saturation * (byArea ? 1 : brightness)
            let bucket = min(Int(hue * Double(buckets)), buckets - 1)
            score[bucket] += weight
            hueSum[bucket] += hue * weight
            saturationSum[bucket] += saturation * weight
        }

        guard let top = score.max(), top > 2 else { return [] }
        return score.indices
            .filter { score[$0] > top * 0.12 }
            .sorted { score[$0] > score[$1] }
            .map { (hueSum[$0] / score[$0], saturationSum[$0] / score[$0]) }
    }
}

/// How far apart two hues are on the color wheel, from 0 to 0.5.
private func circularDistance(_ a: Double, _ b: Double) -> Double {
    let d = abs(a - b).truncatingRemainder(dividingBy: 1)
    return min(d, 1 - d)
}

private func hsb(_ r: Double, _ g: Double, _ b: Double) -> (Double, Double, Double) {
    let maxValue = max(r, g, b), minValue = min(r, g, b)
    let delta = maxValue - minValue
    let saturation = maxValue == 0 ? 0 : delta / maxValue
    var hue: Double = 0
    if delta > 0 {
        if maxValue == r { hue = (g - b) / delta }
        else if maxValue == g { hue = 2 + (b - r) / delta }
        else { hue = 4 + (r - g) / delta }
        hue /= 6
        if hue < 0 { hue += 1 }
    }
    return (hue, saturation, maxValue)
}
