// Copyright 2025 TogKey
// SPDX-License-Identifier: GPL-2.0-or-later

#include "quantum.h"

#if defined(OLED_ENABLE)
oled_rotation_t oled_init_kb(oled_rotation_t rotation) {
    return OLED_ROTATION_180;
}
#endif
