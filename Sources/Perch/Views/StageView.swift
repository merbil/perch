import SwiftUI

/// What the Stage window shows around the player: whether the controls are out, and how big it is.
@MainActor
@Observable
final class StageState {
    /// Controls and traffic lights; they fade out a few seconds after the mouse stops.
    var controlsShown = true
    var isFullScreen = false
    /// Opened by "Start when idle": no controls at all, any input closes it.
    var isScreensaver = false
}

/// The big window: art, song, album, seek bar and controls, laid out by the window's shape.
/// Small shows only the art, wide puts the text beside it, tall stacks it, big goes dark.
struct StageView: View {
    @Environment(StageState.self) private var stage
    @Environment(PlayerModel.self) private var player
    @Environment(Preferences.self) private var prefs

    private enum Shape { case small, wide, tall }

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            let shape: Shape = min(size.width, size.height) < 300 ? .small
                : size.width > size.height * 1.15 ? .wide : .tall
            let dark = stage.isFullScreen || stage.isScreensaver || (size.width >= 1000 && size.height >= 620)
            ZStack {
                background(dark: dark)
                switch shape {
                case .small: small(size: size, dark: dark)
                case .wide: wide(size: size, dark: dark)
                case .tall: tall(size: size, dark: dark)
                }
            }
            .environment(\.colorScheme, dark ? .dark : .light)
        }
        .ignoresSafeArea()
    }

    @ViewBuilder private func background(dark: Bool) -> some View {
        if dark {
            ZStack {
                Color(hex: 0x221C2B)
                prefs.accentColor(for: player).opacity(0.18)
            }
            .animation(.easeInOut(duration: 1.2), value: player.track?.id)
        } else {
            Palette.paperFixed
        }
    }

    // MARK: Shapes

    private func small(size: CGSize, dark: Bool) -> some View {
        let side = min(size.width, size.height) - 24
        return StageArt(side: side, dark: dark)
            .overlay(alignment: .bottom) {
                StageControls(scale: min(side / 300, 1), dark: true, compact: true)
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(Capsule().fill(Color(hex: 0x17131F).opacity(0.85)))
                    .padding(.bottom, 12)
                    .opacity(stage.controlsShown && !stage.isScreensaver ? 1 : 0)
            }
    }

    private func wide(size: CGSize, dark: Bool) -> some View {
        let side = min(size.height * 0.68, size.width * 0.42)
        let scale = side / 300
        return HStack(spacing: 28 * scale) {
            StageArt(side: side, dark: dark)
            StageInfo(scale: scale, dark: dark, alignment: .leading)
                .frame(maxWidth: min(size.width - side - 120 * scale, 720 * scale), alignment: .leading)
        }
        .padding(.horizontal, 40 * scale)
        .padding(.top, 20)
    }

    private func tall(size: CGSize, dark: Bool) -> some View {
        let side = min(size.width * 0.72, size.height * 0.5)
        let scale = side / 300
        return VStack(spacing: 22 * scale) {
            StageArt(side: side, dark: dark)
            StageInfo(scale: scale, dark: dark, alignment: .center)
                .frame(width: max(side, min(size.width - 48, side * 1.3)))
        }
        .padding(.top, 20)
    }
}


/// The cover, with Perch's hard shadow. In the dark look it drifts slowly so nothing burns in.
private struct StageArt: View {
    @Environment(Preferences.self) private var prefs
    var side: CGFloat
    var dark: Bool

    var body: some View {
        let radius = max(14, side * 0.07)
        let line = max(3, side * 0.012)
        let shadow = max(4, side * 0.025)
        TimelineView(.periodic(from: .now, by: 2)) { context in
            let drift = dark && !prefs.reduceMotion ? Self.drift(at: context.date, side: side) : .zero
            CoverArt(size: side, radius: radius, lineWidth: line, outline: dark ? Palette.paperFixed : Palette.inkFixed)
                .background(
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .fill(dark ? Color.black : Palette.inkFixed)
                        .offset(x: shadow, y: shadow)
                )
                .offset(drift)
                .animation(.linear(duration: 2), value: drift)
        }
    }

    /// A slow loop of a few percent of the art's size, about four minutes round.
    static func drift(at date: Date, side: CGFloat) -> CGSize {
        let t = date.timeIntervalSinceReferenceDate / 240 * 2 * .pi
        let amount = side * 0.04
        return CGSize(width: cos(t) * amount, height: sin(t * 2) * amount * 0.5)
    }
}

/// Title, artist, album, seek bar and the controls.
private struct StageInfo: View {
    @Environment(StageState.self) private var stage
    @Environment(PlayerModel.self) private var player
    var scale: CGFloat
    var dark: Bool
    var alignment: HorizontalAlignment

    var body: some View {
        let ink = dark ? Palette.paperFixed : Palette.inkFixed
        let muted = dark ? Color(hex: 0xB9B0C6) : Color(hex: 0x5B5466)
        let text: TextAlignment = alignment == .center ? .center : .leading
        VStack(alignment: alignment, spacing: 8 * scale) {
            Text(player.title)
                .font(.perch(34 * scale))
                .textCase(.uppercase)
                .foregroundStyle(ink)
                .lineLimit(2)
                .minimumScaleFactor(0.6)
                .multilineTextAlignment(text)
            Text(player.artist)
                .font(.perch(17 * scale, .heavy))
                .foregroundStyle(muted)
                .lineLimit(1)
            if let album = player.track?.album, !album.isEmpty {
                Button { player.openInPlayer() } label: {
                    Text(album)
                        .font(.perch(13 * scale, .bold))
                        .foregroundStyle(muted.opacity(0.85))
                        .lineLimit(1)
                }
                .buttonStyle(.plain)
                .help("Open in \(player.source.name)")
            }
            StageSeekBar(scale: scale, dark: dark)
                .padding(.top, 8 * scale)
            StageControls(scale: scale, dark: dark)
                .padding(.top, 4 * scale)
                .opacity(stage.controlsShown && !stage.isScreensaver ? 1 : 0)
                .allowsHitTesting(stage.controlsShown)
        }
    }
}

/// Click or drag anywhere on it to jump in the song. The times sit underneath.
private struct StageSeekBar: View {
    @Environment(StageState.self) private var stage
    @Environment(PlayerModel.self) private var player
    @Environment(Preferences.self) private var prefs
    var scale: CGFloat
    var dark: Bool
    @State private var dragging: Double?

    var body: some View {
        let progress = dragging ?? player.progress
        let height = max(8, 10 * scale)
        let knob = height * 1.6
        let duration = player.track?.duration ?? 0
        VStack(spacing: 5 * scale) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(dark ? Color(hex: 0x2E2738) : .white)
                    Capsule().fill(prefs.accentColor(for: player))
                        .frame(width: max(height, geo.size.width * progress))
                    if !dark { Capsule().strokeBorder(Palette.inkFixed, lineWidth: 2) }
                    Circle()
                        .fill(Palette.paperFixed)
                        .overlay(Circle().strokeBorder(Palette.inkFixed, lineWidth: dark ? 0 : 2))
                        .frame(width: knob, height: knob)
                        .offset(x: geo.size.width * progress - knob / 2)
                        .opacity(stage.controlsShown && !stage.isScreensaver ? 1 : 0)
                }
                .frame(height: height)
                .frame(maxHeight: .infinity)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in dragging = min(max(value.location.x / geo.size.width, 0), 1) }
                        .onEnded { value in
                            player.seek(to: min(max(value.location.x / geo.size.width, 0), 1))
                            dragging = nil
                        }
                )
                .disabled(player.isIdle)
            }
            .frame(height: knob + 6)
            .animation(dragging == nil ? .linear(duration: 1) : nil, value: progress)
            HStack {
                Text((progress * duration).clock)
                Spacer()
                Text(duration.clock)
            }
            .font(.perch(12 * scale, .heavy))
            .foregroundStyle(dark ? Color(hex: 0xB9B0C6) : Color(hex: 0x5B5466))
            .monospacedDigit()
        }
    }
}

/// Shuffle, previous, play, next, repeat. Shuffle and repeat light up in the accent when on.
private struct StageControls: View {
    @Environment(PlayerModel.self) private var player
    @Environment(Preferences.self) private var prefs
    var scale: CGFloat
    var dark: Bool
    /// Only previous, play and next, for the art-only window.
    var compact = false

    var body: some View {
        let ink = dark ? Palette.paperFixed : Palette.inkFixed
        let off = dark ? Color(hex: 0x8E85A0) : Color(hex: 0x9A8FB0)
        let accent = prefs.accentColor(for: player)
        HStack(spacing: (compact ? 12 : 22) * scale) {
            if !compact {
                toggle("shuffle", on: player.shuffling, label: "Shuffle", on: accent, off: off) { player.toggleShuffling() }
            }
            SkipButton(forward: false, size: 20 * scale, color: ink)
            PlayButton(size: 58 * scale, shadow: 3)
            SkipButton(forward: true, size: 20 * scale, color: ink)
            if !compact {
                toggle("repeat", on: player.repeating, label: "Repeat", on: accent, off: off) { player.toggleRepeating() }
            }
        }
    }

    private func toggle(_ symbol: String, on isOn: Bool, label: String, on onColor: Color, off offColor: Color,
                        action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 17 * scale, weight: .black))
                .foregroundStyle(isOn ? onColor : offColor)
                .frame(width: 34 * scale, height: 44 * scale)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(player.isIdle)
        .accessibilityLabel(label)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}
