import AppKit
import SwiftUI

/// Five short steps, each shown with the real player pieces rather than described.
/// The last one asks for the Spotify permission right away.
struct TutorialView: View {
    @Environment(Preferences.self) private var prefs
    @Environment(PlayerModel.self) private var player
    var onDone: () -> Void
    @State var step = 0

    // Each illustration gets its own state so it can sit in any form.
    @State private var pillState = PanelState(form: .pill(.right))
    @State private var tuckedState = PanelState(form: .tucked(.right))
    @State private var tabState = PanelState(form: .tab(.left))
    @State private var permission = SpotifyPermission()

    private let steps: [(title: String, text: String)] = [
        ("Put it anywhere",
         "Where you drop it picks the look. An edge gives you the pill, a corner the tile, the middle the card. Drag it up into the menu bar for the deck."),
        ("Tuck it away",
         "Swipe two fingers into the edge, like clearing a notification. It hides there and slides out when you point at it."),
        ("Pull it back out",
         "Grab the tucked art by its top or bottom and pull: you get the tab. Pull its outer side: the pill."),
        ("Clicks worth knowing",
         ""),
        ("Let Perch reach Spotify",
         "macOS asks once whether Perch may control Spotify. That's how it reads the song and presses play for you."),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Step \(step + 1) of \(steps.count)".uppercased())
                    .font(.perch(11, .heavy)).foregroundStyle(Palette.muted).tracking(0.6)
                Spacer()
                Button { onDone() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .black))
                        .foregroundStyle(Palette.ink)
                        .frame(width: 26, height: 26)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Palette.paper))
                        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Palette.ink, lineWidth: 2))
                        .contentShape(Rectangle())
                }
                .buttonStyle(ArcadeButtonStyle(shape: AnyShape(RoundedRectangle(cornerRadius: 8)), shadow: 2))
                .accessibilityLabel("Close")
            }

            illustration
                .frame(width: 388, height: 210)
                .background(desktop)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Palette.ink, lineWidth: 3))

            VStack(alignment: .leading, spacing: 6) {
                Text(steps[step].title).titleStyle(20)
                if step == 3 {
                    clicksList
                } else if step == 4 {
                    Text(steps[step].text).font(.perch(14, .semibold)).foregroundStyle(Palette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    permissionButton
                } else {
                    Text(steps[step].text).font(.perch(14, .semibold)).foregroundStyle(Palette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(height: 112, alignment: .top)

            HStack(spacing: 8) {
                ForEach(0..<steps.count, id: \.self) { index in
                    Capsule().fill(index == step ? Palette.ink : Palette.ink.opacity(0.18))
                        .frame(width: index == step ? 20 : 8, height: 8)
                }
                Spacer()
                if step > 0 {
                    Button { withAnimation { step -= 1 } } label: {
                        Text("BACK")
                            .font(.perch(13))
                            .foregroundStyle(Palette.ink)
                            .padding(.horizontal, 16)
                            .frame(height: 36)
                            .background(Capsule().fill(Palette.paper))
                            .overlay(Capsule().strokeBorder(Palette.ink, lineWidth: 3))
                            .contentShape(Capsule())
                    }
                    .buttonStyle(ArcadeButtonStyle())
                }
                Button {
                    if step == steps.count - 1 { onDone() } else { withAnimation { step += 1 } }
                } label: {
                    Text(step == steps.count - 1 ? "GOT IT" : "NEXT")
                        .font(.perch(13))
                        .foregroundStyle(Palette.onAccent)
                        .padding(.horizontal, 18)
                        .frame(height: 36)
                        .background(Capsule().fill(prefs.accentColor(for: player)))
                        .overlay(Capsule().strokeBorder(Palette.ink, lineWidth: 3))
                        .contentShape(Capsule())
                }
                .buttonStyle(ArcadeButtonStyle())
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 428)
        .surface(radius: 22)
        .padding(.trailing, 6)
        .padding(.bottom, 6)
        .animation(prefs.reduceMotion ? nil : .spring(duration: 0.3), value: step)
        .onAppear { permission.refresh() }
    }

    @ViewBuilder private var permissionButton: some View {
        switch permission.status {
        case .allowed:
            Label("Perch can control Spotify", systemImage: "checkmark.circle.fill")
                .font(.perch(13)).foregroundStyle(Palette.ink)
        case .asking:
            Text("Waiting for your answer…").font(.perch(13, .bold)).foregroundStyle(Palette.muted)
        case .denied:
            HStack(spacing: 10) {
                Text("Not allowed.").font(.perch(13, .bold)).foregroundStyle(Palette.ink)
                smallButton("Open System Settings") { permission.openSystemSettings() }
            }
        case .notInstalled:
            Text("Spotify isn't installed on this Mac.").font(.perch(13, .bold)).foregroundStyle(Palette.muted)
        case .unknown:
            smallButton("Allow Spotify access") { permission.request() }
        }
    }

    private func smallButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title.uppercased())
                .font(.perch(12))
                .foregroundStyle(Palette.onAccent)
                .padding(.horizontal, 14)
                .frame(height: 30)
                .background(Capsule().fill(Palette.sun))
                .overlay(Capsule().strokeBorder(Palette.ink, lineWidth: 2.5))
                .contentShape(Capsule())
        }
        .buttonStyle(ArcadeButtonStyle(shadow: 2))
        .padding(.top, 4)
    }

    private var desktop: some View {
        Palette.desktop
    }

    @ViewBuilder private var illustration: some View {
        switch step {
        case 0: ScreenMap(accent: prefs.accentColor(for: player))
        case 1:
            HStack(spacing: 14) {
                PillView(edge: .right).environment(pillState).scaleEffect(0.62).frame(width: 236, height: 50)
                arrow("into the edge")
                // Tucked art peeking out of the right edge.
                TuckedView(edge: .right).environment(tuckedState)
                    .padding(.vertical, 6).padding(.leading, 6)
                    .frame(width: 26, alignment: .leading)
                    .clipped()
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        case 2:
            HStack(alignment: .center, spacing: 18) {
                TuckedView(edge: .left).environment(tuckedState)
                    .padding([.vertical, .trailing], 6)
                VStack(alignment: .leading, spacing: 16) {
                    arrow("taller: tab")
                    arrow("wider: pill")
                }
                EdgeTabView(edge: .left).environment(tabState).scaleEffect(0.8).frame(width: 44, height: 170)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        case 4:
            HStack(spacing: 22) {
                LogoMark(bird: prefs.accentColor(for: player)).frame(width: 96, height: 96)
                Image(systemName: "arrow.left.arrow.right").font(.system(size: 26, weight: .black)).foregroundStyle(Palette.ink)
                Image(systemName: "music.note")
                    .font(.system(size: 40, weight: .black))
                    .foregroundStyle(Palette.ink)
                    .frame(width: 88, height: 88)
                    .background(Circle().fill(Palette.paper))
                    .overlay(Circle().strokeBorder(Palette.ink, lineWidth: 3))
                    .background(Circle().fill(Palette.shadow).offset(x: 4, y: 4))
            }
        default:
            VStack(spacing: 14) {
                HStack(spacing: 2) {
                    ForEach(0..<4, id: \.self) { i in
                        RoundedRectangle(cornerRadius: 2).fill(Palette.ink)
                            .frame(width: 6, height: [12, 22, 16, 26][i])
                    }
                }
                .frame(height: 28, alignment: .bottom)
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 8).fill(.white.opacity(0.8)))
                Text("THE BARS IN YOUR MENU BAR").font(.perch(12, .heavy)).foregroundStyle(Palette.muted)
            }
        }
    }

    private var clicksList: some View {
        VStack(alignment: .leading, spacing: 3) {
            clickRow("Click the bars", "this menu, with the views and colors")
            clickRow("Right-click the bars", "hide or show Perch")
            clickRow("Right-click the player", "quick settings")
        }
    }

    private func clickRow(_ what: String, _ result: String) -> some View {
        (Text(what).font(.perch(14)) + Text(": \(result)").font(.perch(14, .semibold)))
            .foregroundStyle(Palette.ink)
    }

    private func arrow(_ label: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "arrow.right").font(.system(size: 14, weight: .black))
            Text(label.uppercased()).font(.perch(11, .heavy))
        }
        .foregroundStyle(Palette.ink)
    }
}

/// A tiny screen with each look where it lives.
private struct ScreenMap: View {
    var accent: Color

    var body: some View {
        ZStack(alignment: .topLeading) {
            Rectangle().fill(.white.opacity(0.8)).frame(height: 16)
            // Deck under the menu bar
            block(Palette.ink, width: 92, height: 34, flat: [.top]).offset(x: 260, y: 16)
            label("DECK", color: Palette.paper).offset(x: 290, y: 26)
            // Pill on the right edge
            block(Palette.paper, width: 96, height: 30, flat: [.right]).offset(x: 292, y: 96)
            label("PILL").offset(x: 318, y: 104)
            // Tile in the bottom-left corner
            block(Palette.paper, width: 70, height: 80, flat: [.left, .bottom]).offset(x: 0, y: 130)
            label("TILE").offset(x: 20, y: 172)
            // Card in the middle
            block(Palette.paper, width: 96, height: 70, flat: []).offset(x: 140, y: 66)
            label("CARD").offset(x: 168, y: 92)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func block(_ fill: Color, width: CGFloat, height: CGFloat, flat: Set<Side>) -> some View {
        Rectangle().fill(.clear)
            .frame(width: width, height: height)
            .overlay(alignment: .bottomLeading) {
                Rectangle().fill(accent).frame(width: width * 0.5, height: 3)
            }
            .surface(flat: flat, radius: 10, fill: fill)
    }

    private func label(_ text: String, color: Color = Palette.ink) -> some View {
        Text(text).font(.perch(11)).foregroundStyle(color)
    }
}
