# Perch

A small Spotify player for the Mac that stays on top of everything, lives in the menu bar and sticks to the edges of your screen.

Where you drop it picks how it looks. On an edge it's a pill, in a corner a tile with the album art, in the middle a card, and up in the menu bar a deck that looks a bit like Winamp. Swipe it into the edge and it tucks away until you point at it.

## Install

1. Download the DMG from the [latest release](https://github.com/merbil/perch/releases/latest).
2. Drag Perch onto the Applications folder and open it.
3. macOS says Perch can't be opened because it isn't from an identified developer. Open System Settings, go to Privacy & Security, and click "Open Anyway". You only do this once.
4. Play something in Spotify and let Perch control it when macOS asks.

After that Perch updates itself from the menu.

## Build

```bash
scripts/build-app.sh
```

This builds `build/Perch.app`. Run it with `--demo` to try it with a fake player, without Spotify.

Needs macOS 14 or later. Apple Music support is on the way.

## License

MIT
