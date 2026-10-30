# Perch

Always-on-top mini music player for macOS. Lives in the menu bar, snaps to screen edges, controls Spotify (Apple Music later).

Concepts canvas: https://claude.ai/artifact/Hh5bZSKXiCuZPauwrfz2Z3

## Look

Skim's Arcade building blocks (thick ink outlines, hard offset shadows, rounded black caps) with its own palette.

| Token | Hex |
|---|---|
| Paper | `#FFF4E6` |
| Ink | `#17131F` |
| Muted text | `#5B5466` |
| Tangerine | `#FF7A3D` |
| Lilac | `#B9A4FF` |
| Lime | `#C6F36B` |
| Pink | `#FF5FA2` |

The side touching a screen edge has no outline and no rounding, so the player reads as stuck to it.

## Forms

Where the player sits picks the form. No manual "look" switch needed.

| Form | Gets there by | Notes |
|---|---|---|
| A · Pill | Dropped on a side or bottom edge, or the tucked art resized wider | Opens and closes with an animation. Swipe it into the edge to tuck (like notifications). Tucked = album art only; hover shows play/pause. Right-click opens the menu. Stays above the Dock. |
| Tab | The tucked art resized taller | Vertical strip stuck to the edge: small art on top, title running vertically. |
| B · Tile | Dropped into a corner | Art first, controls on hover. |
| C · Card | Dropped mid-screen | The main free-floating version. A small corner button shrinks it to album art only; the same button on the art expands it back. |
| D · Deck | Dragged up to the menu bar, or right-click the menu bar icon | Opens right under the menu bar icon by default; can be dragged anywhere along the menu bar. Stays out until its own roll-in button. |

Tucked art stays mostly inside the edge (22 px showing) and slides out when the pointer comes near; it slides back after a short pause. The tab's height follows the song title.

## Logo

Four equaliser bars with a round bird sitting on the tallest one, beak pointing right (no tail). Drawn in code in `Views/Logo.swift`; `scripts/make-icon.sh` renders the app icon from it. App icon: the mark on a paper tile with an ink outline and a hard shadow. The bird is tangerine with a sun-yellow beak; in the menu header it takes the accent.

## Menu bar

- Icon: the logo in one colour. The bars move while music plays and the bird rides the last bar; still when paused, low and flat when Spotify is closed.
- Left-click: the Perch menu.
- Right-click: open D.

## Menu

In Perch's own style, dropping from the icon:

- Show switch (Skim's Arcade switch).
- View: Auto, Pill, Tab, Tile, Card, Art, Deck. Auto lets the drop position pick; any other view keeps its look and only moves.
- Position: "Stick to the closest wall" or "Stay where I drop it" (default). Pill, tab, tile and deck always sit on a wall; this decides what card and art do, and what Auto does mid-screen (stick = pill on the closest wall).
- Accent: 11 bright colours (tangerine, coral, pink, magenta, lilac, periwinkle, sky, mint, lime, sun, peach) plus "From Cover Art", which takes the most colourful hue of the album art.
- Music: Spotify; Apple Music marked soon.
- How Perch works (tutorial, also shown on first launch), Quit.

The player's right-click menu has the same View, Position and Accent pickers.

## Behaviour

- Controls: previous, play/pause, next. No seek, like or volume.
- Nothing playing or Spotify closed: last track dimmed; play opens Spotify.
- Visible on all Spaces, including full-screen apps. Stays on the display it was put on.
- First run triggers macOS's "Perch wants to control Spotify" permission prompt.

## Updates

Same as Glow. Once a day Perch asks GitHub for the latest release of merbil/perch (one request, no personal data). The menu shows "Perch x.y is out" with an Update button. Update downloads the release DMG and checks it before touching anything: signed with the same certificate, same bundle ID, the announced version, newer than this one. Then it swaps the app in place and relaunches. Because the path and signature stay the same, macOS keeps the "control Spotify" permission, so updating never asks again. Where Perch can't replace itself (run from the DMG, a read-only folder), the menu offers Download instead.

Releases: `scripts/make-dmg.sh` builds build/Perch-<version>.dmg, signed with the Glow Local Signing certificate. Publish it as a GitHub release tagged v<version>.

## Sources

1. Spotify (v0.1)
2. Apple Music (later, same source switch)

## Shipping

Like Glow: public GitHub repo, notarised builds.

## Backlog

- Keyboard shortcuts for every form (jump to tile, deck, card, tuck/untuck).
- Apple Music source.
