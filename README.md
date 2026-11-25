# padkeys: Togkey Pad Plus kit

Optional extras for the Togkey Pad Plus macropad (Vial firmware), for macOS:

- **Custom firmware** (`firmware/`): the OLED stays on, shows app icons for each key and the song playing on Spotify, and the LEDs change color per layer.
- **padkeys** (`mac/`): menu bar icon with a mini layout of your pad, hotkeys that open apps, and the feed for the OLED.

Keys are still assigned in [Vial](https://get.vial.today/). Want Claude to do it for you? See "Ask Claude" below.

## Why a custom firmware

The stock firmware turns the OLED off, cannot show anything we choose, and cannot follow your layer with the LEDs. This one can. Everything else is stock behavior (same keys, unlock combo, 4 layers). It is GPL-2.0-or-later, built on [vial-qmk](https://github.com/vial-kb/vial-qmk); the source is in `firmware/source/`.

## Install (about 15 minutes)

1. **Firmware (optional).** Quit Vial. Save your layout in Vial (File > Save current layout). Put the pad in bootloader mode: assign the **Boot** keycode to a key in Vial and press it. A drive named `RPI-RP2` appears. Copy `firmware/togkey_pad_plus_generic.uf2` onto it. The pad reboots. **Your keymap resets**: set your keys again in Vial. To go back to stock, flash a backup made with `picotool save -a stock.uf2` (`brew install picotool`) before you start.
2. **App.** Needs `xcode-select --install`. Then:

   ```bash
   cd mac && ./install.sh
   ```

   A keyboard icon appears in the menu bar. Remove with `./uninstall.sh`.
3. **Keys.** In Vial give a key one of `F13 F16 F17 F18 F19 F20` (type `KC_F13` in the Any box). Then edit `~/.config/padkeys/config.json` (see `mac/config.example.json`) to say what each F-key opens and which icon the OLED shows. Restart the app after editing hotkeys:

   ```bash
   launchctl kickstart -k gui/$(id -u)/com.togkey.padkeys
   ```

Icons: `spotify mic_slash claude slack layers close mission reopen left right play prev next mute globe terminal mail code`. A key without an icon can show a 1-3 letter `tag`. The song line needs `"nowPlaying": true` and a one-time macOS "allow control of Spotify" prompt.

## Ask Claude

Open this folder in Claude Code (or Claude Desktop with a Code session here). It reads `CLAUDE.md` by itself, so it already knows the pad. If your Claude does not load it, start with: "Read CLAUDE.md in this folder." Then ask in plain words. Examples:

- "Install padkeys and set up my pad."
- "Make the top-left key open Notion and show a globe icon on the screen."
- "Add a second layer for meetings: mute, camera, share screen. Mark them on the OLED."
- "Change layer 2's LED color to blue."
- "The song is not showing on the pad. Find out why."
- "Draw a new icon for Figma and add it to the firmware." (needs a rebuild: Claude will walk you through it)
- "Flash the firmware." (Claude will warn you first: the keymap resets.)

Tell Claude what you want, not how. It edits `config.json` and the files in this folder, and tells you when you need to do something in Vial.

## Limits

- Not for F14/F15 (macOS uses them for brightness). Only macOS is covered.
- Icons and tags live in the pad's RAM. padkeys resends them every 20 s, so they come back after a replug as long as the app runs.
- Status: tested on one pad (OLED, icons from padkeys, encoder steps). Layer LED colors, other units and the Spotify song line on other Macs are untested. Tell us if something looks wrong.

## Contributing

PRs and issues welcome. See [CONTRIBUTING.md](CONTRIBUTING.md). Licenses: MIT outside `firmware/`, GPL-2.0-or-later for `firmware/`.
