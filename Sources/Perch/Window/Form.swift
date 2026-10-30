import AppKit
import SwiftUI

enum ScreenEdge: String, Codable {
    case left, right, bottom
    var side: Side {
        switch self {
        case .left: .left
        case .right: .right
        case .bottom: .bottom
        }
    }
}

enum ScreenCorner: String, Codable {
    case topLeft, topRight, bottomLeft, bottomRight
    var sides: Set<Side> {
        switch self {
        case .topLeft: [.top, .left]
        case .topRight: [.top, .right]
        case .bottomLeft: [.bottom, .left]
        case .bottomRight: [.bottom, .right]
        }
    }
}

enum Side: Hashable { case left, right, top, bottom }

/// The player's look. Where it sits on screen picks the form (see DESIGN.md).
enum Form: Codable, Hashable {
    /// A: horizontal bar on a side or bottom edge.
    case pill(ScreenEdge)
    /// A swiped into the edge: album art only.
    case tucked(ScreenEdge)
    /// Tucked art resized taller: vertical strip on a side edge.
    case tab(ScreenEdge)
    /// B: art-first tile in a corner.
    case tile(ScreenCorner)
    /// C: free-floating card, mid-screen.
    case card
    /// C shrunk to its album art.
    case cardMini
    /// D: Winamp-style deck hanging from the menu bar.
    case deck

    /// Sides that touch the screen edge: no outline, no rounding, no shadow room.
    var flatSides: Set<Side> {
        switch self {
        case .pill(let edge), .tucked(let edge), .tab(let edge): [edge.side]
        case .tile(let corner): corner.sides
        case .card, .cardMini: []
        case .deck: [.top]
        }
    }

    /// The tab grows with its title, so its height is passed in.
    func contentSize(tabHeight: CGFloat) -> CGSize {
        switch self {
        case .pill: CGSize(width: 372, height: 72)
        case .tucked: CGSize(width: 72, height: 72)
        case .tab: CGSize(width: 52, height: tabHeight)
        case .tile: CGSize(width: 220, height: 268)
        case .card: CGSize(width: 300, height: 236)
        case .cardMini: CGSize(width: 104, height: 104)
        case .deck: CGSize(width: 340, height: 146)
        }
    }

    var edge: ScreenEdge? {
        switch self {
        case .pill(let edge), .tucked(let edge), .tab(let edge): edge
        default: nil
        }
    }
}

enum Layout {
    /// Room for the hard offset shadow on sides that don't touch the screen edge.
    static let shadowRoom: CGFloat = 6

    static func insets(for form: Form) -> EdgeInsets {
        let flat = form.flatSides
        return EdgeInsets(
            top: flat.contains(.top) ? 0 : shadowRoom,
            leading: flat.contains(.left) ? 0 : shadowRoom,
            bottom: flat.contains(.bottom) ? 0 : shadowRoom,
            trailing: flat.contains(.right) ? 0 : shadowRoom
        )
    }

    /// How much of the tucked art stays on screen until the pointer comes near.
    static let peek: CGFloat = 22

    /// Tab height for a title: art on top, then the title running up the strip.
    static func tabHeight(for title: String) -> CGFloat {
        let textWidth = (title.uppercased() as NSString).size(withAttributes: [.font: NSFont.perch(13)]).width
        return min(max(8 + 34 + 12 + textWidth + 20, 110), 320).rounded(.up)
    }

    static func windowSize(for form: Form, tabHeight: CGFloat = 210) -> CGSize {
        let size = form.contentSize(tabHeight: tabHeight)
        let insets = insets(for: form)
        return CGSize(width: size.width + insets.leading + insets.trailing,
                      height: size.height + insets.top + insets.bottom)
    }

    /// Keeps the content pinned to the edge it's stuck to while the window animates.
    static func alignment(for form: Form) -> Alignment {
        let flat = form.flatSides
        let horizontal: HorizontalAlignment = flat.contains(.left) ? .leading : flat.contains(.right) ? .trailing : .center
        let vertical: VerticalAlignment = flat.contains(.top) ? .top : flat.contains(.bottom) ? .bottom : .center
        return Alignment(horizontal: horizontal, vertical: vertical)
    }
}
