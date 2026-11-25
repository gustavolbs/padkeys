// SPDX-License-Identifier: GPL-2.0-or-later
#pragma once

#define VIAL_KEYBOARD_UID {0x77, 0xF7, 0x14, 0xBB, 0x74, 0x32, 0x66, 0xE9}

// Unlock combo: (row1,col0) + (row2,col0)
#define VIAL_UNLOCK_COMBO_ROWS {1, 2}
#define VIAL_UNLOCK_COMBO_COLS {0, 0}

// Same limits the stock firmware reports (4 layers is also the QMK default)
#define DYNAMIC_KEYMAP_LAYER_COUNT 4
#define DYNAMIC_KEYMAP_MACRO_COUNT 32

// OLED: always on, no fade
#define OLED_TIMEOUT 0
#undef OLED_FADE_OUT
