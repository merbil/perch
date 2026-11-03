import SwiftUI

/// Shown when macOS blocks Perch from talking to Spotify: what happened and the one switch that fixes it.
struct PermissionView: View {
    @Environment(Preferences.self) private var prefs
    @Environment(PlayerModel.self) private var player
    var openSettings: () -> Void
    var onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                LogoMark(bird: prefs.accentColor(for: player)).frame(width: 40, height: 40)
                Text("Can't reach Spotify").titleStyle(18)
            }
            Text("macOS is blocking Perch from controlling Spotify, so it can't show the song or play and pause.")
                .font(.perch(13, .semibold)).foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
            Text("In System Settings, open Privacy & Security, then Automation, and turn on Spotify under Perch.")
                .font(.perch(12, .bold)).foregroundStyle(Palette.muted)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 10) {
                Spacer()
                Button(action: onClose) {
                    Text("NOT NOW").font(.perch(12)).foregroundStyle(Palette.ink)
                        .padding(.horizontal, 14).frame(height: 34)
                        .background(Capsule().fill(Palette.paper))
                        .overlay(Capsule().strokeBorder(Palette.ink, lineWidth: 2))
                }
                .buttonStyle(ArcadeButtonStyle(shadow: 2))
                .keyboardShortcut(.cancelAction)
                Button(action: openSettings) {
                    Text("OPEN SETTINGS").font(.perch(12)).foregroundStyle(Palette.onAccent)
                        .padding(.horizontal, 16).frame(height: 34)
                        .background(Capsule().fill(prefs.accentColor(for: player)))
                        .overlay(Capsule().strokeBorder(Palette.ink, lineWidth: 3))
                }
                .buttonStyle(ArcadeButtonStyle(shadow: 3))
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 360)
        .surface(radius: 20)
        .padding(.trailing, 6)
        .padding(.bottom, 6)
    }
}

/// First launch: a little note under the menu bar icon, so Perch's home is easy to find.
struct MenuBarHintView: View {
    @Environment(Preferences.self) private var prefs
    @Environment(PlayerModel.self) private var player

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Image(systemName: "arrowtriangle.up.fill")
                .font(.system(size: 12))
                .foregroundStyle(Palette.ink)
                .padding(.leading, 14)
                .offset(y: 3)
            VStack(alignment: .leading, spacing: 3) {
                Text("Perch lives up here").titleStyle(14)
                Text("Click the bars for settings, right-click to hide or show Perch.")
                    .font(.perch(12, .bold)).foregroundStyle(Palette.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(14)
            .frame(width: 250, alignment: .leading)
            .surface(radius: 16)
        }
        .padding(.trailing, 6)
        .padding(.bottom, 6)
    }
}
