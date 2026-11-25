# Building the firmware from source

The firmware is [vial-qmk](https://github.com/vial-kb/vial-qmk) (GPL-2.0-or-later) plus the keyboard folder in `source/togkey/pad_plus`.
Prebuilt file: `togkey_pad_plus_generic.uf2`. Base commit: `dd43959ae5c08d8a28d38a1acf7b04e86b14a344` (branch `vial`).

1. Install an Arm GCC toolchain (`arm-none-eabi-gcc`) and Python 3. On macOS: `brew install --cask gcc-arm-embedded`.
2. Get the sources:

```bash
git clone https://github.com/vial-kb/vial-qmk.git
cd vial-qmk
git checkout dd43959ae5c08d8a28d38a1acf7b04e86b14a344
git submodule update --init --recursive
python3 -m venv venv && . venv/bin/activate && pip install -r requirements.txt
```

3. Copy the keyboard folder into the tree (the Vial fork does not ship `togkey/pad_plus`):

```bash
mkdir -p keyboards/togkey
cp -R /path/to/kit/firmware/source/togkey/pad_plus keyboards/togkey/pad_plus
```

4. Build. The result is `togkey_pad_plus_generic.uf2` in the repo root:

```bash
export QMK_HOME=$PWD
make togkey/pad_plus:generic
```

To change the layer colors, edit the `layer_hue` table in `keymaps/generic/keymap.c` (hue 0-255, one value per layer).
To change the OLED text, edit `oled_task_user()` in the same file.
The licenses of vial-qmk are in `source/` (`LICENSE`, `license_GPLv2.md`, `license_GPLv3.md`).
