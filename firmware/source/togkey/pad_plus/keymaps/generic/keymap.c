// SPDX-License-Identifier: GPL-2.0-or-later

#include QMK_KEYBOARD_H
#include OLED_FONT_H // static copy of the 6x8 font, used to draw the 2x title

// Matches customKeycodes[0] "TOGLAY" in vial.json
enum custom_keycodes { TOGLAY = QK_KB_0 };

const uint16_t PROGMEM keymaps[][MATRIX_ROWS][MATRIX_COLS] = {
    [0] = LAYOUT(
        TO(1),
        KC_VOLD, KC_MUTE, KC_VOLU,
        KC_MPRV, KC_MPLY, KC_MNXT
    ),
    [1] = LAYOUT(
        TO(2),
        KC_1, KC_2, KC_3,
        KC_4, KC_5, KC_6
    ),
    [2] = LAYOUT(
        TO(3),
        KC_A, KC_B, KC_C,
        KC_D, KC_E, KC_F
    ),
    [3] = LAYOUT(
        TO(0),
        KC_J, KC_K, KC_L,
        KC_M, KC_N, KC_O
    )
};

const uint16_t PROGMEM encoder_map[][NUM_ENCODERS][NUM_DIRECTIONS] = {
    [0] = {ENCODER_CCW_CW(KC_VOLD, KC_VOLU)},
    [1] = {ENCODER_CCW_CW(KC_TRNS, KC_TRNS)},
    [2] = {ENCODER_CCW_CW(KC_TRNS, KC_TRNS)},
    [3] = {ENCODER_CCW_CW(KC_TRNS, KC_TRNS)},
};

bool process_record_user(uint16_t keycode, keyrecord_t *record) {
    if (keycode == TOGLAY && record->event.pressed) {
        layer_move((get_highest_layer(layer_state) + 1) % DYNAMIC_KEYMAP_LAYER_COUNT); // same as TO(next)
    }
    return true;
}

// ---- RGB: static color per layer (hue 0-255), never written to EEPROM. Edit the table to taste. ----
static const uint8_t layer_hue[DYNAMIC_KEYMAP_LAYER_COUNT] = {21, 190, 213, 85}; // orange, violet, magenta, green
static void set_layer_rgb(uint8_t layer) {
    rgblight_mode_noeeprom(RGBLIGHT_MODE_STATIC_LIGHT);
    rgblight_sethsv_noeeprom(layer_hue[layer], 255, 110);
}

// ---- OLED: top line = Spotify now playing, below it a 3x2 grid of 16x16 icons per layer. ----
// Everything is sent by the Mac app (padkeys) over raw HID and lives in RAM only:
//   0xD0 0x01 <ascii text>                 now-playing line (cleared after 60 s without an update)
//   0xD1 <layer 0-3> <cell 0-5> <icon id or 0xFF> <tag, up to 3 chars>   one grid cell (cell = row * 3 + column)
// A layer that never received a cell shows a big "LAYER n" instead.
#ifdef OLED_ENABLE
#include "icons.h"

#define NP_MAX 29            // max text bytes in one 0xD0 report (32-byte report - 2 header - NUL)
#define NP_COLS 21           // 21 chars * 6 px = 126 px
#define NP_STALE_MS 60000    // padkeys resends every 20 s; clear the line if it goes quiet
#define NP_SCROLL_MS 350
#define NO_ICON 0xFF

static bool     oled_dirty_layer = true;
static char     np_text[NP_MAX + 1];
static uint8_t  np_len;
static uint8_t  np_off;
static bool     np_dirty;
static uint32_t np_rx_at, np_scroll_at;

static uint8_t cell_icon[DYNAMIC_KEYMAP_LAYER_COUNT][6];
static char    cell_tag[DYNAMIC_KEYMAP_LAYER_COUNT][6][4];
static uint8_t layer_configured; // bit n set once layer n received a cell

// Host -> pad. 0xD0 and 0xD1 are not VIA/Vial command ids, so via.c hands them to us.
void raw_hid_receive_kb(uint8_t *data, uint8_t length) {
    if (length >= 3 && data[0] == 0xD0 && data[1] == 0x01) {
        char    tmp[NP_MAX + 1];
        uint8_t n = 0;
        for (uint8_t i = 2; i < length && n < NP_MAX && data[i] != 0; i++) {
            tmp[n++] = (data[i] >= 32 && data[i] < 127) ? (char)data[i] : '?';
        }
        tmp[n] = 0;
        if (n != np_len || memcmp(tmp, np_text, n) != 0) { // same text again: keep the scroll position
            memcpy(np_text, tmp, n + 1);
            np_len   = n;
            np_off   = 0;
            np_dirty = true;
        }
        np_rx_at = timer_read32();
    } else if (length >= 5 && data[0] == 0xD1 && data[1] < DYNAMIC_KEYMAP_LAYER_COUNT && data[2] < 6) {
        uint8_t l = data[1], c = data[2];
        char    tag[4] = {0};
        for (uint8_t i = 0; i < 3 && data[4 + i] >= 32 && data[4 + i] < 127; i++) tag[i] = (char)data[4 + i];
        uint8_t icon = (data[3] < ICON_COUNT) ? data[3] : NO_ICON;
        if (icon != cell_icon[l][c] || strcmp(tag, cell_tag[l][c]) != 0 || !(layer_configured & (1 << l))) {
            cell_icon[l][c] = icon;
            strcpy(cell_tag[l][c], tag);
            layer_configured |= 1 << l;
            if (get_highest_layer(layer_state) == l) oled_dirty_layer = true;
        }
    }
}

static void draw_char(uint8_t x, uint8_t y, char c, uint8_t scale) {
    if ((uint8_t)c < OLED_FONT_START || (uint8_t)c > OLED_FONT_END) return;
    const unsigned char *glyph = &font[((uint8_t)c - OLED_FONT_START) * OLED_FONT_WIDTH];
    for (uint8_t col = 0; col < OLED_FONT_WIDTH; col++) {
        uint8_t bits = pgm_read_byte(&glyph[col]);
        for (uint8_t row = 0; row < OLED_FONT_HEIGHT; row++) {
            if (!(bits & (1 << row))) continue;
            for (uint8_t dx = 0; dx < scale; dx++)
                for (uint8_t dy = 0; dy < scale; dy++) oled_write_pixel(x + col * scale + dx, y + row * scale + dy, true);
        }
    }
}

// Draw str centered in [x0, x0+width). Trailing blank font column is not counted.
static void draw_centered(uint8_t x0, uint8_t width, uint8_t y, const char *str, uint8_t scale) {
    uint8_t len = strlen(str);
    uint8_t w   = len * OLED_FONT_WIDTH * scale - scale;
    uint8_t x   = x0 + (width - w) / 2;
    for (uint8_t i = 0; i < len; i++) draw_char(x + i * OLED_FONT_WIDTH * scale, y, str[i], scale);
}

static void draw_icon(uint8_t x, uint8_t y, uint8_t id) {
    for (uint8_t r = 0; r < 16; r++) {
        uint16_t bits = pgm_read_word(&icon_rows[id][r]);
        for (uint8_t c = 0; c < 16; c++) {
            if (bits & (0x8000 >> c)) oled_write_pixel(x + c, y + r, true);
        }
    }
}

// Text line 0 (y 0-7), 21 columns. Short text is centered, long text scrolls.
static void draw_nowplaying(void) {
    char buf[NP_COLS + 1];
    memset(buf, ' ', NP_COLS);
    buf[NP_COLS] = 0;
    if (np_len > 0 && np_len <= NP_COLS) {
        memcpy(&buf[(NP_COLS - np_len) / 2], np_text, np_len);
    } else if (np_len > NP_COLS) {
        uint8_t period = np_len + 3; // 3 spaces between loops
        for (uint8_t i = 0; i < NP_COLS; i++) {
            uint8_t k = (np_off + i) % period;
            buf[i]    = (k < np_len) ? np_text[k] : ' ';
        }
    }
    oled_set_cursor(0, 0);
    oled_write(buf, false);
}

static void draw_grid(uint8_t layer) {
    for (uint8_t x = 0; x < 128; x++) {
        oled_write_pixel(x, 9, true);
        oled_write_pixel(x, 37, true);
    }
    for (uint8_t y = 9; y < 64; y++) {
        oled_write_pixel(42, y, true);
        oled_write_pixel(85, y, true);
    }
    static const uint8_t cell_x[3] = {0, 43, 86}; // 42 px cells, 1 px separators at x=42 and x=85
    for (uint8_t i = 0; i < 6; i++) {
        uint8_t x = cell_x[i % 3], y = (i < 3) ? 10 : 38; // cell is 27 px high
        bool    has_icon = cell_icon[layer][i] != NO_ICON, has_tag = cell_tag[layer][i][0] != 0;
        if (has_icon && has_tag) {
            draw_icon(x + 13, y + 1, cell_icon[layer][i]);
            draw_centered(x, 42, y + 19, cell_tag[layer][i], 1);
        } else if (has_icon) {
            draw_icon(x + 13, y + 5, cell_icon[layer][i]);
        } else if (has_tag) {
            draw_centered(x, 42, y + 9, cell_tag[layer][i], 2);
        }
    }
}

bool oled_task_user(void) {
    if (np_len > 0 && timer_elapsed32(np_rx_at) > NP_STALE_MS) { np_len = 0; np_dirty = true; }
    if (np_len > NP_COLS && timer_elapsed32(np_scroll_at) > NP_SCROLL_MS) {
        np_scroll_at = timer_read32();
        np_off       = (np_off + 1) % (np_len + 3);
        np_dirty     = true;
    }
    if (oled_dirty_layer) {
        oled_dirty_layer = false;
        oled_clear();
        uint8_t layer = get_highest_layer(layer_state);
        if (layer_configured & (1 << layer)) {
            draw_grid(layer);
        } else {
            char title[] = "LAYER 1";
            title[6]     = '1' + layer;
            draw_centered(0, 128, 28, title, 2);
        }
        np_dirty = true;
    }
    if (np_dirty) { np_dirty = false; draw_nowplaying(); }
    return false;
}
#endif

layer_state_t layer_state_set_user(layer_state_t state) {
    set_layer_rgb(get_highest_layer(state));
#ifdef OLED_ENABLE
    oled_dirty_layer = true;
#endif
    return state;
}

void keyboard_post_init_user(void) {
    rgblight_enable_noeeprom(); // so the color shows even if RGB was left off in EEPROM
    set_layer_rgb(0);
}
