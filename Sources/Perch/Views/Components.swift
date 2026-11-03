import AppKit
import SwiftUI

/// The things a view can ask the window to do. Set up by PanelController.
@MainActor
@Observable
final class PanelState {
    var form: Form
    /// Snapshots render hover states without a mouse.
    var forceHover = false
    /// Height of the tab, fitted to the current title.
    var tabHeight: CGFloat = 210

    /// The tucked art reports hover, so the window can slide out of the edge.
    @ObservationIgnored var tuckedHover: (Bool) -> Void = { _ in }
    @ObservationIgnored var minimise: () -> Void = {}
    @ObservationIgnored var expand: () -> Void = {}
    @ObservationIgnored var rollIn: () -> Void = {}
    @ObservationIgnored var showDeck: () -> Void = {}
    @ObservationIgnored var hide: () -> Void = {}
    @ObservationIgnored var openStage: () -> Void = {}

    init(form: Form) {
        self.form = form
    }
}

/// Paper surface with an ink outline and a hard offset shadow.
/// Flat sides run past the window edge, so the outline and rounding vanish where it's stuck.
struct Surface: ViewModifier {
    var flat: Set<Side>
    var radius: CGFloat
    var fill: Color = Palette.paper
    var shadow: Color = Palette.shadow
    var outline: Color = Palette.ink

    private var shape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(cornerRadii: RectangleCornerRadii(
            topLeading: flat.contains(.top) || flat.contains(.left) ? 0 : radius,
            bottomLeading: flat.contains(.bottom) || flat.contains(.left) ? 0 : radius,
            bottomTrailing: flat.contains(.bottom) || flat.contains(.right) ? 0 : radius,
            topTrailing: flat.contains(.top) || flat.contains(.right) ? 0 : radius
        ))
    }

    private var overflow: EdgeInsets {
        EdgeInsets(top: flat.contains(.top) ? -4 : 0, leading: flat.contains(.left) ? -4 : 0,
                   bottom: flat.contains(.bottom) ? -4 : 0, trailing: flat.contains(.right) ? -4 : 0)
    }

    private var shadowOffset: CGSize {
        CGSize(width: flat.contains(.right) ? -4 : 4, height: flat.contains(.bottom) ? 0 : 4)
    }

    func body(content: Content) -> some View {
        content
            .clipShape(shape)
            .background {
                ZStack {
                    shape.fill(shadow).offset(shadowOffset)
                    shape.fill(fill)
                }
                .padding(overflow)
            }
            .overlay {
                shape.strokeBorder(outline, lineWidth: 3).padding(overflow)
            }
    }
}

extension View {
    func surface(flat: Set<Side> = [], radius: CGFloat, fill: Color = Palette.paper, shadow: Color = Palette.shadow,
                 outline: Color = Palette.ink) -> some View {
        modifier(Surface(flat: flat, radius: radius, fill: fill, shadow: shadow, outline: outline))
    }
}

/// Album art, or Perch's own geometric cover when there's none.
struct CoverArt: View {
    @Environment(PlayerModel.self) private var player
    var size: CGFloat
    var radius: CGFloat
    var lineWidth: CGFloat = 3
    var outline: Color = Palette.ink

    var body: some View {
        ZStack {
            if let image = player.artwork {
                Image(nsImage: image).resizable().aspectRatio(contentMode: .fill)
            } else {
                PlaceholderCover()
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        .overlay {
            if lineWidth > 0 {
                RoundedRectangle(cornerRadius: radius, style: .continuous).strokeBorder(outline, lineWidth: lineWidth)
            }
        }
        .saturation(player.isIdle ? 0.2 : 1)
        .opacity(player.isIdle ? 0.7 : 1)
        .accessibilityHidden(true)
    }
}

struct PlaceholderCover: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            ZStack(alignment: .topLeading) {
                Palette.lilac
                Circle().fill(Palette.tangerine)
                    .frame(width: w * 0.5, height: w * 0.5)
                    .position(x: w * 0.625, y: h * 0.42)
                Palette.inkFixed.frame(height: h * 0.29).offset(y: h * 0.71)
                Capsule().fill(Palette.lime)
                    .frame(width: w * 0.375, height: h * 0.085)
                    .offset(x: w * 0.125, y: h * 0.79)
            }
        }
    }
}

struct PlayButton: View {
    @Environment(PlayerModel.self) private var player
    @Environment(Preferences.self) private var prefs
    var size: CGFloat
    var shadow: CGFloat = 2

    var body: some View {
        Button { player.playPause() } label: {
            Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                .font(.system(size: size * 0.36, weight: .black))
                .foregroundStyle(Palette.onAccent)
                .frame(width: size, height: size)
                .background(Circle().fill(prefs.accentColor(for: player)))
                .overlay(Circle().strokeBorder(Palette.ink, lineWidth: 3))
                .background(Circle().fill(Palette.shadow).offset(x: shadow, y: shadow))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(player.isPlaying ? "Pause" : "Play")
    }
}

struct SkipButton: View {
    @Environment(PlayerModel.self) private var player
    var forward: Bool
    var size: CGFloat = 17
    var color: Color = Palette.ink

    var body: some View {
        Button { forward ? player.next() : player.previous() } label: {
            Image(systemName: forward ? "forward.end.fill" : "backward.end.fill")
                .font(.system(size: size, weight: .black))
                .foregroundStyle(color)
                .frame(width: 32, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(player.isIdle)
        .opacity(player.isIdle ? 0.35 : 1)
        .accessibilityLabel(forward ? "Next" : "Previous")
    }
}

/// Accent strip along the bottom showing how far into the song we are, over a faint track.
/// `lift` keeps it clear of the outline when the bottom isn't against the screen edge.
struct ProgressStrip: View {
    @Environment(PlayerModel.self) private var player
    @Environment(Preferences.self) private var prefs
    var height: CGFloat = 6
    var lift: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle().fill(Palette.ink.opacity(0.1))
                Rectangle().fill(prefs.accentColor(for: player))
                    .frame(width: geo.size.width * player.progress)
            }
            .frame(height: height)
            .frame(maxHeight: .infinity, alignment: .bottom)
            .padding(.bottom, lift)
        }
        .allowsHitTesting(false)
        .animation(.linear(duration: 1), value: player.progress)
    }
}

/// Arcade-style press: lifts a little on hover, sinks into its shadow when pressed.
struct ArcadeButtonStyle: ButtonStyle {
    var shape: AnyShape = AnyShape(Capsule())
    var shadow: CGFloat = 3

    func makeBody(configuration: Configuration) -> some View {
        ArcadeButtonBody(configuration: configuration, shape: shape, shadow: shadow)
    }

    private struct ArcadeButtonBody: View {
        @Environment(Preferences.self) private var prefs
        @State private var hovering = false
        let configuration: Configuration
        let shape: AnyShape
        let shadow: CGFloat

        var body: some View {
            let lift: CGFloat = configuration.isPressed ? shadow : (hovering ? -1.5 : 0)
            configuration.label
                .offset(x: lift, y: lift)
                .background(shape.fill(Palette.shadow).offset(x: shadow, y: shadow))
                .scaleEffect(hovering && !configuration.isPressed && !prefs.reduceMotion ? 1.04 : 1)
                .onHover { hovering = $0 }
                .animation(prefs.reduceMotion ? nil : .spring(duration: 0.2, bounce: 0.5), value: hovering)
                .animation(prefs.reduceMotion ? nil : .spring(duration: 0.12), value: configuration.isPressed)
        }
    }
}

/// Small outlined square button with an icon, for minimise / expand / roll in.
struct ChipButton: View {
    var symbol: String
    var label: String
    var fill: Color = Palette.paper
    var tint: Color = Palette.ink
    var shadow = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .black))
                .foregroundStyle(tint)
                .frame(width: 26, height: 26)
                .background(RoundedRectangle(cornerRadius: 8).fill(fill))
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Palette.ink, lineWidth: 2))
                .background(RoundedRectangle(cornerRadius: 8).fill(Palette.shadow).offset(x: shadow ? 2 : 0, y: shadow ? 2 : 0))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .help(label)
    }
}

/// Title that scrolls when it doesn't fit, like Winamp's.
/// The loop is timed from the text's real drawn width, so wrapping around is seamless.
struct Marquee: View {
    @Environment(Preferences.self) private var prefs
    /// Each new text starts scrolling from its beginning.
    @State private var startedAt = Date()
    @State private var textWidth: CGFloat = 0
    var text: String
    var font: Font
    var nsFont: NSFont
    var color: Color = Palette.ink
    var gap: CGFloat = 40
    var speed: CGFloat = 28

    var body: some View {
        GeometryReader { geo in
            if textWidth <= geo.size.width + 0.5 {
                label
            } else if prefs.reduceMotion {
                // Still: the end fades out instead of moving (and never turns into "…").
                label
                    .frame(width: geo.size.width, alignment: .leading)
                    .clipped()
                    .mask(LinearGradient(stops: [.init(color: .black, location: 0), .init(color: .black, location: 0.8),
                                                 .init(color: .clear, location: 1)],
                                         startPoint: .leading, endPoint: .trailing))
            } else {
                TimelineView(.animation) { timeline in
                    // Scroll one full loop, then rest at the start so the beginning is readable.
                    let cycle = textWidth + gap
                    let pause: Double = 1.6
                    let loop = Double(cycle / speed) + pause
                    let elapsed = max(0, timeline.date.timeIntervalSince(startedAt)).truncatingRemainder(dividingBy: loop)
                    let offset = CGFloat(max(0, elapsed - pause)) * speed
                    HStack(spacing: gap) { label; label }
                        .offset(x: -offset)
                        .transaction { $0.animation = nil }
                }
            }
        }
        .frame(height: nsFont.boundingRectForFont.height)
        .clipped()
        // The width as SwiftUI draws it (an NSFont estimate was a few points off, which made it jump).
        .background(alignment: .leading) {
            label.hidden().background(GeometryReader { proxy in
                Color.clear
                    .onAppear { textWidth = proxy.size.width }
                    .onChange(of: proxy.size.width) { _, width in textWidth = width }
            })
        }
        .onChange(of: text) { startedAt = Date() }
        .accessibilityLabel(text)
    }

    private var label: some View {
        Text(text).font(font).foregroundStyle(color).lineLimit(1).fixedSize()
    }
}

/// Bouncing equaliser bars, still when paused.
struct EQBars: View {
    var playing: Bool
    var color: Color
    var count = 7
    var barWidth: CGFloat = 5
    var height: CGFloat = 28

    var body: some View {
        TimelineView(.animation(paused: !playing)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            HStack(alignment: .bottom, spacing: 3) {
                ForEach(0..<count, id: \.self) { i in
                    Rectangle().fill(color)
                        .frame(width: barWidth, height: height * EQBars.level(i, t: t, playing: playing))
                }
            }
            .frame(height: height, alignment: .bottom)
        }
        .accessibilityHidden(true)
    }

    static func level(_ i: Int, t: Double, playing: Bool) -> Double {
        let resting = [0.35, 0.6, 0.45, 0.7, 0.4, 0.55, 0.3]
        guard playing else { return resting[i % resting.count] }
        let speed = 6.0 + Double(i % 3)
        return 0.3 + 0.7 * (0.5 + 0.5 * sin(t * speed + Double(i) * 1.7))
    }
}

/// One line of player text that scrolls when it's too long, never cut off with "…".
struct ScrollingLine: View {
    var text: String
    var size: CGFloat
    /// Titles are black-weight capitals; secondary lines are bold and muted.
    var isTitle = true

    var body: some View {
        Marquee(text: isTitle ? text.uppercased() : text,
                font: .perch(size, isTitle ? .black : .bold),
                nsFont: .perch(size, weight: isTitle ? .black : .bold),
                color: isTitle ? Palette.ink : Palette.muted)
    }
}

/// Uppercase label used for titles.
extension Text {
    func titleStyle(_ size: CGFloat) -> some View {
        self.font(.perch(size)).textCase(.uppercase).foregroundStyle(Palette.ink).lineLimit(1)
    }
}
