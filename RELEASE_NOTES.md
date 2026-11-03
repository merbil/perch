# Perch release notes

## Next (unreleased)

### Added
- Stage, a big Perch window. Turn it on under Stage in the menu, or with the screen button on the card. Make it any size, tile it next to another app, or go full screen with the green button. The layout follows the window: just the art when it's small, art and song side by side when it's wide, stacked when it's tall, and dark with the cover's color behind it when it's big.
- In Stage, click or drag the bar to jump around in the song, and turn shuffle and repeat on or off. Click the album name to open the song in Spotify.
- The controls and the window buttons fade out when you stop moving the mouse, and come back when you move it.
- In Auto, a frosted shape shows where Perch will land while you drag it, like macOS's own window tiling.
- Shift-Command-9 opens and closes Stage from any app.
- Open at login: a switch in the menu starts Perch with your Mac.
- If macOS blocks Perch from controlling Spotify, a popup says so and opens the right page in System Settings, instead of Perch just showing nothing.
- The first time you finish the tutorial, a note under the menu bar icon shows where Perch lives.
- Start when idle: pick 5, 10 or 20 minutes, and Stage fills the screen like a screensaver once your Mac sits untouched that long while music plays. Any mouse or keyboard input closes it again.

### Removed
- Pinching. macOS doesn't pass a pinch to an app that isn't in front, and Perch almost never is. Pull the edges or use the shrink and expand buttons instead.

## 0.2.7 (build 9): 2026-11-03

### Changed
- The power button in the menu asks "Quit Perch?" first, so you don't quit it by accident.
- The menu bar icon moves more smoothly and uses less effort. Its bars animate in place instead of being redrawn many times a second.
- When Perch can't update itself, it says why. Usually you need admin rights to change apps in the Applications folder. It suggests downloading instead, or moving Perch to the Applications folder in your home folder.

### Fixed
- Another go at pinching while another app is in front. macOS doesn't send Perch a pinch then, so Perch now follows your two fingers on the trackpad itself.

## 0.2.6 (build 8): 2026-11-03

### Fixed
- Scrolling titles and artist names move smoothly now. Perch asked Spotify for the current song once a second in a way that paused everything for a moment, which made the text stop and go. It asks in the background now.

## 0.2.5 (build 7): 2026-11-03

### Added
- The pill and the tab have resize grips too. Push the pill's outer end back into the edge to tuck it, or pull its top or bottom to get the tab. On the tab, pull the outer side for the pill, or push the top or bottom back in to tuck it.

### Fixed
- Scrolling titles and artist names don't jump any more. Perch now times the scroll from the text as it's actually drawn, and in the pill the time sits next to the artist on its own, so the name isn't restarted every second.
- Long titles start scrolling from the beginning when the song changes.

## 0.2.4 (build 6): 2026-11-02

### Fixed
- Pinching works now, also when another app is in front. Before, macOS only sent the pinch to Perch while Perch itself was the active app, which it almost never is.
- The resize arrows on the tucked art show up every time you point at its edges, not only now and then.
- Swiping the pill into the edge and back out looks right. The old look slides into the edge and the new one slides back out, instead of the content jumping while the window changed size.

## 0.2.3 (build 5): 2026-10-30

### Added
- An About button at the bottom of the menu. It shows your version, these release notes, links to the website, the story behind Perch and GitHub, and a Ko-fi button.

### Fixed
- The update box no longer says Perch can't replace itself. It always offers Update now, and Download only shows up if an update really fails.

## 0.2.2 (build 4): 2026-10-30

### Changed
- The bottom of the menu is tidier. Your version and whether it's up to date sit in their own box with a small check button, and How it works and Quit are proper buttons now.

## 0.2.1 (build 3): 2026-10-30

### Added
- Dark mode. Perch follows your Mac, or you can pick Light or Dark in the menu. In dark mode the paper turns plum-black with cream outlines, and the deck keeps its dark look.
- Right-click the bars in the menu bar to hide Perch completely, and again to bring it back. While it's hidden the bird leaves the icon.
- Pinch to switch between the card and just the album art. Pinch out on tucked art to get the tab, and pinch in on the pill or tab to tuck it away.
- A setting for the tucked art. It can peek out of the edge until you point at it, or always show the album art.
- Reduce motion in the menu. The bars stop moving, long titles fade out instead of scrolling, and windows move without sliding.
- The tutorial's last step asks for the Spotify permission right away, so macOS doesn't ask later out of nowhere.
- Resize arrows on the tucked art's edges, so it's clear you can pull them.

### Changed
- You can pull the deck down off the menu bar and drop it anywhere.
- In light mode the deck is light and papery like the other looks.
- Tutorial buttons bounce a little when you point at them.
- The version line in the menu is shorter and scrolls when it doesn't fit.

### Fixed
- Changing the view no longer flips the Show switch off and on.

## 0.2.0 (build 2): 2026-10-30

The first public version.

### Added
- A small player for Spotify that stays on top of your other windows and lives in the menu bar.
- Where you drop it picks how it looks. On a side or the bottom edge it's a pill, in a corner it's a tile with the album art, in the middle it's a card, and dragged up into the menu bar it hangs there as a deck that looks a bit like Winamp.
- Swipe two fingers into the edge to tuck the pill away, like clearing a notification. Only a sliver of the album art stays out, and it slides out when you point at it.
- Pull the tucked art taller and you get a slim tab with the song title running up it. Pull it wider and the pill comes back.
- The card has a small button that shrinks it to just the album art and back.
- Long titles scroll instead of getting cut off.
- Click the bars in the menu bar for the menu. You can pick a fixed look instead of Auto, have it stick to the closest wall or stay where you drop it, and choose from 11 accent colors. There's also one that takes its color from the album art.
- Right-click the bars to open the deck. Right-click the player for quick settings.
- A short tutorial on first launch, and again from the menu any time.
- One-click updates. Perch checks GitHub once a day, and Update in the menu swaps in the new version. It keeps the same signature, so macOS doesn't ask for the Spotify permission again.
