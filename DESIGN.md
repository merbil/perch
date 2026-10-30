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

## Menu bar

- Icon: equaliser bars like D's, moving while music plays, still when paused.
- Left-click: show / hide Perch.
- Right-click: open D.

## Behaviour

- Controls: previous, play/pause, next. No seek, like or volume.
- Nothing playing or Spotify closed: last track dimmed; play opens Spotify.
- Visible on all Spaces, including full-screen apps. Stays on the display it was put on.
- First run triggers macOS's "Perch wants to control Spotify" permission prompt.

## Sources

1. Spotify (v0.1)
2. Apple Music (later, same source switch)

## Shipping

Like Glow: public GitHub repo, notarised builds.

## Backlog

- Keyboard shortcuts for every form (jump to tile, deck, card, tuck/untuck).
- Apple Music source.
