import AppKit
import SwiftUI

/// Four short steps, each shown with the real player pieces rather than described.
struct TutorialView: View {
    @Environment(Preferences.self) private var prefs
    @Environment(PlayerModel.self) private var player
    var onDone: () -> Void
    @State var step = 0

    // Each illustration gets its own state so it can sit in any form.
    @State private var pillState = PanelState(form: .pill(.right))
    @State private var tuckedState = PanelState(form: .tucked(.right))
    @State private var tabState = PanelState(form: .tab(.left))

    private let steps: [(title: String, text: String)] = [
        ("Put it anywhere",
         "Where you drop it picks the look. An edge gives you the pill, a corner the tile, the middle the card. Drag it up into the menu bar for the deck."),
        ("Tuck it away",
         "Swipe two fingers into the edge, like clearing a notification. It hides there and slides out when you point at it."),
        ("Pull it back out",
         "Grab the tucked art by its top or bottom and pull: you get the tab. Pull its outer side: the pill."),
        ("Clicks worth knowing",
         ""),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Step \(step + 1) of \(steps.count)".uppercased())
                    .font(.perch(11, .heavy)).foregroundStyle(Palette.muted).tracking(0.6)
                Spacer()
                ChipButton(symbol: "xmark", label: "Close") { onDone() }
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
                } else {
                    Text(steps[step].text).font(.perch(14, .semibold)).foregroundStyle(Palette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(height: 96, alignment: .top)

            HStack(spacing: 8) {
                ForEach(0..<steps.count, id: \.self) { index in
                    Capsule().fill(index == step ? Palette.ink : Palette.ink.opacity(0.18))
                        .frame(width: index == step ? 20 : 8, height: 8)
                }
                Spacer()
                if step > 0 {
                    TextButton(title: "Back", muted: true) { withAnimation { step -= 1 } }
                }
                Button {
                    if step == steps.count - 1 { onDone() } else { withAnimation { step += 1 } }
                } label: {
                    Text(step == steps.count - 1 ? "GOT IT" : "NEXT")
                        .font(.perch(13))
                        .foregroundStyle(Palette.ink)
                        .padding(.horizontal, 18)
                        .frame(height: 36)
                        .background(Capsule().fill(prefs.accentColor(for: player)))
                        .overlay(Capsule().strokeBorder(Palette.ink, lineWidth: 3))
                        .background(Capsule().fill(Palette.ink).offset(x: 3, y: 3))
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 428)
        .surface(radius: 22)
        .padding(.trailing, 6)
        .padding(.bottom, 6)
        .animation(.spring(duration: 0.3), value: step)
    }

    private var desktop: some View {
        Color(hex: 0xE7E1F0)
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
            clickRow("Click the bars", "this menu, with the views and colours")
            clickRow("Right-click the bars", "the deck")
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
