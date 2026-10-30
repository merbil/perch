import AppKit
import SwiftUI

/// Switches between the forms and holds the right-click menu.
struct PlayerRoot: View {
    @Environment(PanelState.self) private var state
    @Environment(Preferences.self) private var prefs
    @Environment(PlayerModel.self) private var player

    var body: some View {
        content
            .padding(Layout.insets(for: state.form))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: Layout.alignment(for: state.form))
            .contextMenu { menu }
    }

    @ViewBuilder private var content: some View {
        switch state.form {
        case .pill(let edge): PillView(edge: edge)
        case .tucked(let edge): TuckedView(edge: edge)
        case .tab(let edge): EdgeTabView(edge: edge)
        case .tile(let corner): TileView(corner: corner)
        case .card: CardView()
        case .cardMini: CardMiniView()
        case .deck: DeckView()
        }
    }

    @ViewBuilder private var menu: some View {
        @Bindable var prefs = prefs
        Picker("View", selection: $prefs.view) {
            ForEach(ViewChoice.allCases) { Text($0.title).tag($0) }
        }
        Picker("Position", selection: $prefs.position) {
            ForEach(PositionChoice.allCases) { Text($0.title).tag($0) }
        }
        Picker("Accent", selection: $prefs.accent) {
            ForEach(Accent.allCases) { Text($0.title).tag($0) }
        }
        Divider()
        if state.form != .deck {
            Button("Show Deck") { state.showDeck() }
        }
        Button("Hide Perch") { state.hide() }
        Button("Quit Perch") { NSApp.terminate(nil) }
    }
}

/// Hover tracking that snapshots can switch on.
private struct Hovering: ViewModifier {
    @Environment(PanelState.self) private var state
    @Binding var isHovering: Bool
    func body(content: Content) -> some View {
        content.onHover { isHovering = $0 }
    }
}

private extension View {
    func tracksHover(_ binding: Binding<Bool>) -> some View { modifier(Hovering(isHovering: binding)) }
}

// MARK: - A · Pill

struct PillView: View {
    @Environment(PlayerModel.self) private var player
    var edge: ScreenEdge

    var body: some View {
        HStack(spacing: 12) {
            CoverArt(size: 50, radius: 12)
            VStack(alignment: .leading, spacing: 1) {
                ScrollingLine(text: player.title, size: 15)
                ScrollingLine(text: subtitle, size: 12, isTitle: false)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: 4) {
                SkipButton(forward: false)
                PlayButton(size: 44)
                SkipButton(forward: true)
            }
        }
        .padding(.leading, edge == .left ? 14 : 10)
        .padding(.trailing, edge == .right ? 10 : 14)
        .frame(width: 372, height: 72)
        .overlay { ProgressStrip() }
        .surface(flat: [edge.side], radius: 22)
    }

    private var subtitle: String {
        guard let track = player.track, !player.isIdle else { return player.artist }
        return "\(track.artist) · \(player.position.clock) / \(track.duration.clock)"
    }
}

// MARK: - A tucked

struct TuckedView: View {
    @Environment(PanelState.self) private var state
    @State private var hovering = false
    var edge: ScreenEdge

    var body: some View {
        ZStack {
            CoverArt(size: 50, radius: 12)
            if hovering || state.forceHover {
                PlayButton(size: 36, shadow: 0).transition(.scale.combined(with: .opacity))
            }
        }
        .frame(width: 72, height: 72)
        .surface(flat: [edge.side], radius: 18)
        .tracksHover($hovering)
        .onChange(of: hovering) { _, isHovering in state.tuckedHover(isHovering) }
        .animation(.spring(duration: 0.25), value: hovering)
    }
}

// MARK: - Tab (tucked, resized taller)

struct EdgeTabView: View {
    @Environment(PanelState.self) private var state
    @Environment(PlayerModel.self) private var player
    @State private var hovering = false
    var edge: ScreenEdge

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                CoverArt(size: 34, radius: 9)
                if hovering || state.forceHover {
                    PlayButton(size: 34, shadow: 0)
                }
            }
            let textLength = state.tabHeight - 8 - 34 - 10 - 14
            ScrollingLine(text: player.title, size: 13)
                .frame(width: textLength)
                .rotationEffect(.degrees(-90))
                .frame(width: 20, height: textLength)
        }
        .padding(.top, 8)
        .frame(width: 52, height: state.tabHeight, alignment: .top)
        .overlay { ProgressStrip() }
        .surface(flat: [edge.side], radius: 18)
        .tracksHover($hovering)
    }
}

// MARK: - B · Tile

struct TileView: View {
    @Environment(PanelState.self) private var state
    @Environment(PlayerModel.self) private var player
    @State private var hovering = false
    var corner: ScreenCorner

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .bottom) {
                CoverArt(size: 220, radius: 0, lineWidth: 0)
                    .frame(width: 220, height: 196)
                    .clipped()
                if hovering || state.forceHover {
                    HStack {
                        SkipButton(forward: false)
                        Spacer()
                        PlayButton(size: 40, shadow: 0)
                        Spacer()
                        SkipButton(forward: true)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .surface(radius: 24)
                    .padding(12)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .frame(width: 220, height: 196)
            Rectangle().fill(Palette.ink).frame(height: 3)
            VStack(alignment: .leading, spacing: 2) {
                ScrollingLine(text: player.title, size: 15)
                ScrollingLine(text: player.artist, size: 12, isTitle: false)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            Spacer(minLength: 0)
        }
        .frame(width: 220, height: 268)
        .overlay { ProgressStrip() }
        .surface(flat: corner.sides, radius: 22)
        .tracksHover($hovering)
        .animation(.spring(duration: 0.25), value: hovering)
    }
}

// MARK: - C · Card

struct CardView: View {
    @Environment(PanelState.self) private var state
    @Environment(PlayerModel.self) private var player
    @Environment(Preferences.self) private var prefs

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                CoverArt(size: 72, radius: 14)
                VStack(alignment: .leading, spacing: 2) {
                    ScrollingLine(text: player.title, size: 16)
                    ScrollingLine(text: player.artist, size: 13, isTitle: false)
                    Text(player.source.name.uppercased())
                        .font(.perch(11))
                        .foregroundStyle(Palette.paper)
                        .padding(.horizontal, 7).padding(.vertical, 2)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Palette.ink))
                        .padding(.top, 4)
                }
                .padding(.trailing, 24)
                Spacer(minLength: 0)
            }
            VStack(spacing: 4) {
                GeometryReader { geo in
                    Capsule().fill(Palette.field)
                        .overlay(alignment: .leading) {
                            Rectangle().fill(prefs.accentColor(for: player)).frame(width: geo.size.width * player.progress)
                        }
                        .clipShape(Capsule())
                        .overlay(Capsule().strokeBorder(Palette.ink, lineWidth: 2))
                }
                .frame(height: 10)
                HStack {
                    Text(player.position.clock)
                    Spacer()
                    Text((player.track?.duration ?? 0).clock)
                }
                .font(.perch(11, .heavy))
                .foregroundStyle(Palette.muted)
                .monospacedDigit()
            }
            HStack(spacing: 18) {
                SkipButton(forward: false, size: 20)
                PlayButton(size: 52, shadow: 3)
                SkipButton(forward: true, size: 20)
            }
        }
        .padding(14)
        .frame(width: 300, height: 236)
        .overlay(alignment: .topTrailing) {
            ChipButton(symbol: "arrow.down.right.and.arrow.up.left", label: "Shrink to album art") { state.minimise() }
                .padding(10)
        }
        .surface(radius: 22)
    }
}

struct CardMiniView: View {
    @Environment(PanelState.self) private var state
    @State private var hovering = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            ZStack {
                CoverArt(size: 96, radius: 18)
                if hovering || state.forceHover {
                    PlayButton(size: 40, shadow: 0)
                }
            }
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Palette.shadow).offset(x: 4, y: 4))
            .frame(width: 104, height: 104, alignment: .bottomLeading)
            ChipButton(symbol: "arrow.up.left.and.arrow.down.right", label: "Expand to the card", shadow: true) { state.expand() }
        }
        .frame(width: 104, height: 104)
        .tracksHover($hovering)
    }
}

// MARK: - D · Deck

struct DeckView: View {
    @Environment(PanelState.self) private var state
    @Environment(PlayerModel.self) private var player
    @Environment(Preferences.self) private var prefs

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                CoverArt(size: 74, radius: 8, lineWidth: 2, outline: Palette.lime)
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .bottom) {
                        Text(lcdClock).font(.lcd(30)).foregroundStyle(Palette.lime)
                        Spacer(minLength: 4)
                        EQBars(playing: player.isPlaying && !prefs.reduceMotion, color: Palette.lime)
                    }
                    Marquee(text: marqueeText, font: .lcd(13),
                            nsFont: .monospacedSystemFont(ofSize: 13, weight: .bold),
                            color: Palette.lime, gap: 24)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(RoundedRectangle(cornerRadius: 8).fill(Palette.lcd))
            }
            .frame(height: 74)
            GeometryReader { geo in
                Capsule().fill(Palette.deckTrack)
                    .overlay(alignment: .leading) {
                        Rectangle().fill(Palette.lime).frame(width: geo.size.width * player.progress)
                    }
                    .clipShape(Capsule())
            }
            .frame(height: 8)
            HStack(spacing: 6) {
                DeckKey(symbol: "backward.end.fill", label: "Previous", width: 48) { player.previous() }
                DeckKey(symbol: player.isPlaying ? "pause.fill" : "play.fill", label: player.isPlaying ? "Pause" : "Play",
                        width: 64, fill: prefs.accentColor(for: player)) { player.playPause() }
                DeckKey(symbol: "forward.end.fill", label: "Next", width: 48) { player.next() }
                Spacer()
                DeckKey(symbol: "chevron.up", label: "Roll in", width: 44, fill: Palette.deckTrack, tint: Palette.paperFixed) {
                    state.rollIn()
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 10)
        .padding(.bottom, 12)
        .frame(width: 340, height: 146)
        .surface(flat: [.top], radius: 20, fill: Palette.deckBody, shadow: Palette.deckShadow, outline: Palette.inkFixed)
    }

    private var lcdClock: String {
        let total = Int(player.position)
        return String(format: "%02d:%02d", total / 60, total % 60)
    }

    private var marqueeText: String {
        guard let track = player.track else { return "*** PERCH - NOTHING PLAYING ***" }
        return "*** \(track.artist.uppercased()) - \(track.title.uppercased()) (\(track.duration.clock)) ***"
    }
}

private struct DeckKey: View {
    var symbol: String
    var label: String
    var width: CGFloat
    var fill: Color = Palette.paperFixed
    var tint: Color = Palette.inkFixed
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .black))
                .foregroundStyle(tint)
                .frame(width: width, height: 34)
                .background(RoundedRectangle(cornerRadius: 8).fill(fill))
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Palette.inkFixed, lineWidth: 2))
                .overlay(alignment: .bottom) {
                    RoundedRectangle(cornerRadius: 8).fill(.black.opacity(0.18)).frame(height: 3)
                }
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .help(label)
    }
}
