import AppKit
import SwiftUI

/// What the menu can ask for. Set up by AppDelegate.
struct MenuActions {
    var toggleShown: () -> Void = {}
    var showTutorial: () -> Void = {}
    var showAbout: () -> Void = {}
    var quit: () -> Void = { NSApp.terminate(nil) }
}

/// The menu under the menu bar icon: show/hide, view, position, accent, source, tutorial.
struct MenuView: View {
    @Environment(Preferences.self) private var prefs
    @Environment(PlayerModel.self) private var player
    var actions: MenuActions

    static let width: CGFloat = 288

    var body: some View {
        @Bindable var prefs = prefs
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                HStack(spacing: 8) {
                    LogoMark(bird: prefs.accentColor(for: player)).frame(width: 30, height: 30)
                    Text("Perch").titleStyle(20)
                }
                Spacer()
                ArcadeSwitch(isOn: prefs.isShown, accent: prefs.accentColor(for: player), label: "Show Perch") {
                    actions.toggleShown()
                }
            }

            section("View") {
                FlowGrid(columns: 4) {
                    ForEach(ViewChoice.allCases) { choice in
                        Chip(title: choice.title, selected: prefs.view == choice, accent: prefs.accentColor(for: player)) {
                            prefs.view = choice
                        }
                    }
                }
                Text(viewHint).font(.perch(11, .bold)).foregroundStyle(Palette.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            section("Appearance") {
                FlowGrid(columns: 3) {
                    ForEach(AppearanceChoice.allCases) { choice in
                        Chip(title: choice.title, selected: prefs.appearance == choice, accent: prefs.accentColor(for: player)) {
                            prefs.appearance = choice
                        }
                    }
                }
            }

            section("Position") {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(PositionChoice.allCases) { choice in
                        RadioRow(title: choice.title, selected: prefs.position == choice) { prefs.position = choice }
                    }
                }
            }

            section("Tucked away") {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(TuckedStyle.allCases) { style in
                        RadioRow(title: style.title, selected: prefs.tuckedStyle == style) { prefs.tuckedStyle = style }
                    }
                }
            }

            section("Accent") {
                LazyVGrid(columns: Array(repeating: GridItem(.fixed(30), spacing: 10), count: 6), alignment: .leading, spacing: 10) {
                    ForEach(Accent.allCases) { accent in
                        Swatch(accent: accent, selected: prefs.accent == accent) { prefs.accent = accent }
                    }
                }
            }

            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Reduce motion").font(.perch(13, .bold)).foregroundStyle(Palette.ink)
                    Text("Still bars, titles and windows").font(.perch(11, .bold)).foregroundStyle(Palette.muted)
                }
                Spacer()
                ArcadeSwitch(isOn: prefs.reduceMotion, accent: prefs.accentColor(for: player), label: "Reduce motion") {
                    prefs.reduceMotion.toggle()
                }
            }

            section("Music") {
                HStack(spacing: 8) {
                    Text("Spotify")
                        .font(.perch(12))
                        .foregroundStyle(Palette.paper)
                        .padding(.horizontal, 9).padding(.vertical, 4)
                        .background(RoundedRectangle(cornerRadius: 7).fill(Palette.ink))
                    Text("Apple Music · soon")
                        .font(.perch(12, .bold))
                        .foregroundStyle(Palette.muted)
                }
            }

            Rectangle().fill(Palette.ink.opacity(0.12)).frame(height: 2)

            UpdateRow()

            HStack(spacing: 8) {
                FooterButton(symbol: "questionmark.circle.fill", title: "Tutorial", action: actions.showTutorial)
                FooterButton(symbol: "info.circle.fill", title: "About", action: actions.showAbout)
                FooterButton(symbol: "power", title: nil, action: actions.quit)
                    .frame(width: 40)
                    .accessibilityLabel("Quit Perch")
                    .help("Quit Perch")
            }
        }
        .padding(16)
        .frame(width: Self.width)
        .surface(radius: 18)
        .padding(.trailing, 6)
        .padding(.bottom, 6)
    }

    private var viewHint: String {
        switch prefs.view {
        case .auto: "Changes with where you drop it."
        case .pill: "A bar on the closest edge."
        case .tab: "A slim strip on the closest side."
        case .tile: "Album art in the closest corner."
        case .card: "The full player, wherever you put it."
        case .art: "Just the album art."
        case .deck: "Hangs from the menu bar."
        }
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased()).font(.perch(11, .heavy)).foregroundStyle(Palette.muted).tracking(0.6)
            content()
        }
    }
}

private struct FlowGrid<Content: View>: View {
    var columns: Int
    @ViewBuilder var content: Content
    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: columns), alignment: .leading, spacing: 6) {
            content
        }
    }
}

/// Skim-style segmented chip: ink pill with accent text when selected.
private struct Chip: View {
    var title: String
    var selected: Bool
    var accent: Color
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title.uppercased())
                .font(.perch(11))
                .foregroundStyle(selected ? accent : Palette.ink)
                .frame(maxWidth: .infinity)
                .frame(height: 28)
                .background(RoundedRectangle(cornerRadius: 8).fill(selected ? Palette.selected : Palette.field))
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Palette.ink, lineWidth: 2))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

private struct RadioRow: View {
    var title: String
    var selected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Circle().strokeBorder(Palette.ink, lineWidth: 2)
                    .background(Circle().fill(Palette.field))
                    .overlay(Circle().fill(Palette.ink).padding(5).opacity(selected ? 1 : 0))
                    .frame(width: 18, height: 18)
                Text(title).font(.perch(13, .bold)).foregroundStyle(Palette.ink)
                Spacer(minLength: 0)
            }
            .frame(height: 26)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// Round color swatch. The cover swatch shows the current album art.
private struct Swatch: View {
    var accent: Accent
    var selected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                if accent == .cover {
                    CoverArt(size: 30, radius: 15, lineWidth: 0)
                    Image(systemName: "sparkles")
                        .font(.system(size: 11, weight: .black))
                        .foregroundStyle(Palette.ink)
                        .padding(3)
                        .background(Circle().fill(Palette.paper))
                } else {
                    Circle().fill(accent.color)
                }
            }
            .frame(width: 30, height: 30)
            .clipShape(Circle())
            .overlay(Circle().strokeBorder(Palette.ink, lineWidth: 2))
            .padding(3)
            .overlay(Circle().strokeBorder(Palette.ink, lineWidth: 2).opacity(selected ? 1 : 0))
            .frame(width: 30, height: 30)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accent.title)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .help(accent.title)
    }
}

/// On/off switch from Skim's Arcade skin: accent when on, white when off, ink outlines.
struct ArcadeSwitch: View {
    var isOn: Bool
    var accent: Color
    var label: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack(alignment: isOn ? .trailing : .leading) {
                Capsule().fill(isOn ? accent : Palette.field)
                Circle().fill(isOn ? Palette.paperFixed : Palette.sun)
                    .overlay(Circle().strokeBorder(Palette.inkFixed, lineWidth: 2))
                    .frame(width: 22, height: 22)
                    .padding(2)
            }
            .frame(width: 46, height: 26)
            .overlay(Capsule().strokeBorder(Palette.ink, lineWidth: 2))
            .contentShape(Capsule())
            .animation(.spring(duration: 0.25), value: isOn)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityValue(isOn ? "On" : "Off")
    }
}

struct TextButton: View {
    var title: String
    var muted = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title.uppercased())
                .font(.perch(12))
                .foregroundStyle(muted ? Palette.muted : Palette.ink)
                .frame(minHeight: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// New version from GitHub, or the current version with a check button.
private struct UpdateRow: View {
    private let updater = Updater.shared

    var body: some View {
        if let release = updater.available {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Perch \(release.version) is out").font(.perch(13)).foregroundStyle(Palette.ink)
                    Spacer()
                    if let progress = updater.state.progressText {
                        Text(progress).font(.perch(12, .bold)).foregroundStyle(Palette.muted)
                    } else if updater.offersInstall {
                        PillButton(title: "Update") { Task { await updater.install() } }
                    } else {
                        PillButton(title: "Download") { updater.download() }
                    }
                }
                if let notice = updater.notice {
                    Text(notice).font(.perch(11, .bold)).foregroundStyle(Palette.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 10).fill(Palette.sun.opacity(0.4)))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Palette.ink, lineWidth: 2))
        } else {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Perch \(updater.currentVersion)").font(.perch(13)).foregroundStyle(Palette.ink)
                    HStack(spacing: 5) {
                        Circle().fill(statusColor).frame(width: 7, height: 7)
                        Text(statusText).font(.perch(11, .bold)).foregroundStyle(Palette.muted)
                    }
                }
                Spacer()
                Button {
                    Task { await updater.check() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12, weight: .black))
                        .foregroundStyle(Palette.ink)
                        .frame(width: 30, height: 30)
                        .background(RoundedRectangle(cornerRadius: 9).fill(Palette.paper))
                        .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(Palette.ink, lineWidth: 2))
                        .contentShape(Rectangle())
                }
                .buttonStyle(ArcadeButtonStyle(shape: AnyShape(RoundedRectangle(cornerRadius: 9)), shadow: 2))
                .disabled(updater.state == .checking)
                .opacity(updater.state == .checking ? 0.5 : 1)
                .help("Check for updates")
                .accessibilityLabel("Check for updates")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: 12).fill(Palette.field))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Palette.ink, lineWidth: 2))
        }
    }

    private var statusText: String {
        switch updater.state {
        case .checking: "Checking for updates…"
        case .upToDate: "Up to date"
        case .failed: "Couldn't check for updates"
        default: "Checks GitHub once a day"
        }
    }

    private var statusColor: Color {
        switch updater.state {
        case .upToDate: Color(hex: 0x3DBE6B)
        case .failed: Palette.coral
        default: Palette.muted
        }
    }
}

/// One of the two buttons at the bottom of the menu.
private struct FooterButton: View {
    var symbol: String
    /// Nil: icon only.
    var title: String?
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: symbol).font(.system(size: 10, weight: .black))
                if let title { Text(title.uppercased()).font(.perch(11)).lineLimit(1).fixedSize() }
            }
            .foregroundStyle(Palette.ink)
            .frame(maxWidth: .infinity)
            .frame(height: 34)
            .background(RoundedRectangle(cornerRadius: 10).fill(Palette.paper))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Palette.ink, lineWidth: 2))
            .contentShape(Rectangle())
        }
        .buttonStyle(ArcadeButtonStyle(shape: AnyShape(RoundedRectangle(cornerRadius: 10)), shadow: 2))
    }
}

private struct PillButton: View {
    var title: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title.uppercased())
                .font(.perch(12))
                .foregroundStyle(Palette.ink)
                .padding(.horizontal, 12)
                .frame(height: 28)
                .background(Capsule().fill(Palette.paper))
                .overlay(Capsule().strokeBorder(Palette.ink, lineWidth: 2))
                .contentShape(Capsule())
        }
        .buttonStyle(ArcadeButtonStyle(shadow: 2))
    }
}
