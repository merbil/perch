# Perch status

## 2026-10-30: 0.2.1 released (dark mode, right-click hides, pinch, reduce motion)

First real test of the in-app update: Mert clicks Update in installed 0.2.0.

## 2026-10-30: 0.2.0, first public release

Public at github.com/merbil/perch, DMG attached to release v0.2.0. Adds the in-app updater (copied from Glow), the logo and app icon, and scrolling titles everywhere. To release: bump the version in Resources/Info.plist, run `scripts/make-dmg.sh`, then `gh release create v<version>` with the DMG attached.

## 2026-10-30, round 2

- The tab's height now follows the song title.
- Tucked art peeks 22 px out of the edge and slides out on hover.
- Left-click on the menu bar icon opens the new Perch menu: show switch, View (Auto, Pill, Tab, Tile, Card, Art, Deck), Position (stick to the closest wall / stay where I drop it), 12 accents including From Cover Art, Music, How Perch works, Quit.
- Tutorial: 4 steps, shown on first launch and from the menu.
- Snapshots of the menu and each tutorial step are in design/snapshots.

Not tried by hand yet: the menu closing on outside clicks, the peek timing, view switching while the deck is out, the cover-art color against real Spotify art.


## 2026-10-30, overnight: v0.1 first build

Built, not tried by hand yet. Nothing committed (git is set up, no commits).

### Try it

Demo mode uses a fake player. It doesn't touch Spotify and doesn't ask for permission:

```bash
open -n "build/Perch.app" --args --demo
```

The real thing, controlling Spotify. macOS asks once for permission to control Spotify:

```bash
open -n "build/Perch.app"
```

Rebuild with `scripts/build-app.sh` (add `--install` to copy it to /Applications). It's signed with the Glow Local Signing certificate, so the Spotify permission survives rebuilds.

To see every form as an image without running the app: `.build/debug/Perch --snapshot design/snapshots`. The overview is in `design/snapshots/sheet.png`.

### What's in

- Menu bar icon: four equaliser bars, moving while music plays, low and flat when Spotify is closed.
  - Left-click: show / hide.
  - Right-click: deck.
  - Option-click: small menu with Quit.
- Forms, all from DESIGN.md:
  - Pill on the left, right and bottom edges. Swipe two fingers into the edge to tuck it; swipe out to bring it back.
  - Tucked art: hover shows play/pause. Grab its free outer side and pull to get the pill; grab its top or bottom and pull to get the tab.
  - Tab on the side edges.
  - Tile in any corner, with controls on hover.
  - Card mid-screen. Its corner button shrinks it to album art; the art's corner button expands it again.
  - Deck: opens under the menu bar icon, can be dragged along the menu bar only, and closes only with its ⌃ button. When it closes, the player you had before comes back.
- Where you drop the player picks the form: into the menu bar → deck, a corner → tile, an edge → pill (a tucked or tab player keeps its kind), anywhere else → card.
- Right-click on the player: source (Spotify; Apple Music marked "soon"), snap to edges, snap to corners, accent color, show deck, hide, quit.
- Slides in and out from its edge; the card fades.
- Visible on every Space and over full-screen apps.
- Remembers the form, position and settings.
- Spotify closed: shows the last track dimmed, and Play opens Spotify and starts it.
- Spotify's own album art. When there is none, it uses Perch's geometric cover.

### Not checked yet

- Nothing was tried with a real mouse or trackpad: dragging, snapping, swipe-to-tuck, the resize grips, hover.
- Not tested against real Spotify (it would have asked for permission and played music overnight). The demo app opened and ran for 5 seconds without crashing.
- The tucked-art resize grips are invisible 16 px strips, with no resize cursor yet.

### Decisions I made (easy to change)

- Left-click on the menu bar icon does nothing while the deck is out, because only the ⌃ button rolls it in. Option-click still has Hide.
- The deck opens under the icon every time. A position you drag it to lasts until it rolls in.
- On the bottom edge there's no tab: pulling the tucked art either way gives the pill.
- One accent color for all forms (default tangerine). The deck's screen is always lime.
- The deck uses the system monospaced font, not a pixel font.

### Next

- Try it, then fix what feels off.
- App icon.
- First commit after your OK.
- Backlog in DESIGN.md: keyboard shortcuts, Apple Music.
