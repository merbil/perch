import AppKit
import SwiftUI

extension NSImage {
    /// The cover's most colorful hue, pushed bright so it fits next to the other accents.
    /// Nil for black-and-white or very dull covers.
    func vibrantAccent() -> Color? {
        guard let (hue, saturation) = dominantHue() else { return nil }
        return Color(hue: hue, saturation: min(max(saturation, 0.55), 0.85), brightness: 0.97)
    }

    /// The same hue, deep enough to fill Stage behind light text.
    func deepBackground() -> Color? {
        guard let (hue, saturation) = dominantHue() else { return nil }
        return Color(hue: hue, saturation: min(max(saturation, 0.5), 0.8), brightness: 0.34)
    }

    private func dominantHue() -> (Double, Double)? {
        guard let cgImage = cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        let side = 24
        guard let context = CGContext(
            data: nil, width: side, height: side, bitsPerComponent: 8, bytesPerRow: side * 4,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: side, height: side))
        guard let data = context.data?.assumingMemoryBound(to: UInt8.self) else { return nil }

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
            guard saturation > 0.25, brightness > 0.25 else { continue }
            let weight = saturation * saturation * brightness
            let bucket = min(Int(hue * Double(buckets)), buckets - 1)
            score[bucket] += weight
            hueSum[bucket] += hue * weight
            saturationSum[bucket] += saturation * weight
        }

        guard let best = score.indices.max(by: { score[$0] < score[$1] }), score[best] > 2 else { return nil }
        let hue = hueSum[best] / score[best]
        return (hue, saturationSum[best] / score[best])
    }
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
