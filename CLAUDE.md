# Context for Claude: Togkey Pad Plus kit

You are helping a user set up a Togkey Pad Plus macropad on macOS. Read this file first. Answer in the user's language. Write files, comments and commits in U.S. English.

## Hardware and software

- Pad: RP2040 (Pro Micro form factor), 6 keys + 1 rotary encoder with a click switch, 128x64 OLED, 3 RGB LEDs. USB id `FEED:8687`.
- Key matrix is 3x3. Matrix `(0,2)` is the encoder click. `(1,0) (1,1) (1,2)` are the top key row. `(2,0) (2,1) (2,2)` are the bottom key row. The encoder has two cells per layer: counter-clockwise and clockwise.
- Firmware: [vial-qmk](https://github.com/vial-kb/vial-qmk) commit `dd43959a`, GPL-2.0-or-later. Four layers. The user edits keys in the Vial GUI. Never ask the user to edit C code for normal changes.
- This kit replaces the stock firmware with a build that keeps the OLED on, draws icons, shows a Spotify line and changes the LED color per layer. It does not change the keys. Layer colors (hue) are in `layer_hue` in `firmware/source/togkey/pad_plus/keymaps/generic/keymap.c`.
- `mac/padkeys.swift` is one small Swift program. It runs as a LaunchAgent (`com.togkey.padkeys`). It does three jobs: (1) global hotkeys F13/F16-F20 run commands, (2) a menu bar popover shows the user's layout, (3) it sends icons and the Spotify song to the pad over raw HID.

## Files

| Path | Purpose |
|---|---|
| `README.md` | Human instructions. Keep it short. |
| `firmware/togkey_pad_plus_generic.uf2` | Prebuilt firmware. |
| `firmware/BUILD.md` | How to rebuild it from source. |
| `firmware/source/togkey/pad_plus/` | Keyboard folder to copy into vial-qmk. `keymaps/generic` is the build. |
| `mac/padkeys.swift` | The app. `mac/install.sh` builds and starts it. `mac/uninstall.sh` removes it. |
| `mac/config.example.json` | Starting config. The live one is `~/.config/padkeys/config.json` (or `$PADKEYS_CONFIG`). |

## Config schema (`config.json`)

```json
{
  "nowPlaying": true,
  "hotkeys": [{ "key": "F13", "command": ["/usr/bin/open", "-a", "Spotify"] }],
  "layers": [{
    "name": "Layer 1", "layer": 0, "turn": "Volume - / +", "press": "Mute",
    "keys": [[KEY, KEY, KEY], [KEY, KEY, KEY]]
  }]
}
```

- `hotkeys[].key` is one of `F13 F16 F17 F18 F19 F20`. `command` is an argv array. No shell is involved, so no pipes, no `~` inside a word other than a leading `~`, no quoting.
- `layers[].layer` is the Vial layer number (0-3). If missing, the list position is used.
- A KEY is a plain string, or an object with `app` (path to a `.app`, used for the popover icon), `symbol` (SF Symbol name), `label` (popover text), `oled` (icon name for the pad) and `tag` (1-3 characters under the icon on the pad).
- Icon names (same order as `enum icon_id` in `keymaps/generic/icons.h`): `spotify mic_slash claude slack layers close mission reopen left right play prev next mute globe terminal mail code`.
- The popover reads the config on every click. Hotkeys are read at start-up: restart with `launchctl kickstart -k gui/$(id -u)/com.togkey.padkeys`. Icon and song updates are re-read every 2 s.

## How to work with the user

The user may not know the hardware terms. They will say things like "make the top-left key open Notion", "add a meetings layer", "the song is not showing" or "change the color of layer 2". Translate that into the tasks below.

1. Ask only what you cannot find out: which key (use "top-left", "bottom-middle"; you map it to a matrix cell), which layer, which app.
2. Do the file edits yourself (`config.json`, and `keymaps/generic/*` for firmware changes). Edit the user's live config at `~/.config/padkeys/config.json`, not the example.
3. Some steps only the user can do. Say them in one short numbered list: assign a key in Vial, hold the two unlock keys, replug the pad, accept the macOS Spotify prompt.
4. Run `launchctl kickstart -k gui/$(id -u)/com.togkey.padkeys` after hotkey changes, then say what to press to test.
5. Before anything that overwrites firmware, tell the user the keymap will reset, ask them to save a layout in Vial first, and wait for a yes.
6. If something fails, read `~/Library/Logs/padkeys.log` first. It logs bad config, unsupported keys, HID failures and Spotify permission errors.
7. Report what you changed and what you did not test.

## Typical tasks (reference)

**Add an app to a key.** (1) In Vial, set the key to an unused F-key from the list. (2) Add a `hotkeys` entry for that F-key. (3) Add the key to `layers[].keys` with `app`, and `oled` or `tag`. (4) Restart padkeys. Never use F14 or F15: macOS uses them for screen brightness.

**Add an icon.** Draw a 16x16 bitmap, append it to `icon_rows` and to `enum icon_id` in `icons.h`, append the name at the end of `iconNames` in `padkeys.swift`, rebuild the firmware, reinstall the app. The order of both lists is the protocol. Append only.

**Flash or restore firmware.** See `README.md`. The pad enters the RP2040 bootloader (`RPI-RP2` drive, or `picotool`) when a Boot keycode is pressed. The first flash resets the keymap, so ask the user to save a Vial layout first. Never flash without telling the user, and never flash while Vial is open.

**Change LED colors or OLED text.** Edit `keymaps/generic/keymap.c`, then follow `firmware/BUILD.md`.

## Pad protocol (raw HID, usage page `0xFF60`, usage `0x61`, 32-byte reports)

Custom commands, all RAM-only on the pad:

| Bytes | Meaning |
|---|---|
| `D0 01 <ascii>` | Now-playing line (up to 29 chars, NUL end). Scrolls above 21 chars. Cleared after 60 s without an update. |
| `D1 <layer 0-3> <cell 0-5> <icon id or FF> <tag up to 3 chars>` | One grid cell. Cell = row * 3 + column. A layer that never received a cell shows a big "LAYER n". |

Standard VIA/Vial commands that are useful if the user asks you to script the keymap (verified on this pad, Vial protocol 6): `0x05 L R C hi lo` sets a keycode, `0x04 L R C` reads one, `0xFE 0x04 L 0 DIR hi lo` sets an encoder direction (DIR 0 = counter-clockwise, 1 = clockwise), `0x11` returns the layer count. QMK keycodes: `QK_TO(n) = 0x5200+n`, `KC_MUTE 0xA8`, `KC_VOLU 0xA9`, `KC_VOLD 0xAA`, `F13..F20 = 0x68..0x6F`, Cmd `0x0800`, Shift `0x0200`, Ctrl `0x0100`, Alt `0x0400` (OR with the key). The Vial GUI keeps the device open exclusively on macOS, so close Vial before any script talks to it. Prefer the GUI unless the user asks for scripts.

## Pitfalls we already hit

- The first flash re-initializes the pad's EEPROM and the keys go back to the defaults. Re-apply the layout. After a flash the pad sometimes needs a replug to show up.
- `open -a Vial` can fail silently on some Macs. Start Vial from `/Applications/Vial.app/Contents/MacOS/Vial`.
- Encoder steps: `resolution` in `keyboard.json` is 4 pulses per click on this pad. With 2, one click sent two keypresses (Ctrl+Tab skipped tabs). If a click does nothing or needs two turns, try 2. Changing it needs a rebuild and a flash.
- The encoder direction is easy to get backwards. If the volume goes the wrong way, swap the two cells in Vial.
- The Spotify line needs a one-time macOS permission ("allow padkeys to control Spotify"). If it never appears, look at System Settings > Privacy & Security > Automation.
- This generic build was tested on one pad only. If the OLED or LEDs look wrong, flash the stock backup and report back.

## Do not

- Do not write passwords, tokens or personal data into the config.
- Do not add AI attribution (Co-Authored-By, "generated by") to commits or PRs unless the user asks.
- Do not change the firmware's USB ids or the Vial UID, so layouts saved from the stock firmware keep loading.
