#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#if defined(_WIN32)
#include <windows.h>
#endif

#include "sokol_gfx.h"
#include "sokol_gl.h"

#define FONTSTASH_IMPLEMENTATION
#if defined(_MSC_VER)
#pragma warning(disable: 4244 4267 4996)
#endif
#include "fontstash.h"

#define SOKOL_FONTSTASH_IMPL
#include "sokol_fontstash.h"

static FONScontext* zapp_fonts;
static int zapp_ui_font = FONS_INVALID;

static void zapp_font_error(void* user_ptr, int error, int value) {
    (void)user_ptr;
    (void)value;
    if (error != FONS_ATLAS_FULL || !zapp_fonts) {
        return;
    }

    int width = 0;
    int height = 0;
    fonsGetAtlasSize(zapp_fonts, &width, &height);
    if (width < 4096 && height < 4096) {
        fonsExpandAtlas(zapp_fonts, width * 2, height * 2);
    }
}

bool zapp_font_setup(const unsigned char* data, int data_len) {
    if (zapp_fonts) {
        return true;
    }
    if (!data || data_len <= 0) {
        return false;
    }

    stbtt_fontinfo font_info;
    const int font_offset = stbtt_GetFontOffsetForIndex(data, 0);
    if (font_offset < 0 ||
        !stbtt_InitFont(&font_info, data, font_offset) ||
        stbtt_FindGlyphIndex(&font_info, 0x4E2D) == 0) {
        return false;
    }

    const sfons_desc_t desc = {
        .width = 2048,
        .height = 2048,
    };
    zapp_fonts = sfons_create(&desc);
    if (!zapp_fonts) {
        return false;
    }

    fonsSetErrorCallback(zapp_fonts, zapp_font_error, NULL);
    zapp_ui_font = fonsAddFontMem(
        zapp_fonts,
        "Noto Sans SC",
        (unsigned char*)data,
        data_len,
        0
    );
    if (zapp_ui_font == FONS_INVALID) {
        sfons_destroy(zapp_fonts);
        zapp_fonts = NULL;
        return false;
    }
    return true;
}

void zapp_font_shutdown(void) {
    if (zapp_fonts) {
        sfons_destroy(zapp_fonts);
        zapp_fonts = NULL;
    }
    zapp_ui_font = FONS_INVALID;
}

float zapp_font_measure(
    const unsigned char* text,
    int text_len,
    float size,
    float spacing,
    float* height
) {
    if (!zapp_fonts || zapp_ui_font == FONS_INVALID || !text || text_len < 0) {
        if (height) {
            *height = size;
        }
        return 0.0f;
    }

    fonsSetFont(zapp_fonts, zapp_ui_font);
    fonsSetSize(zapp_fonts, size);
    fonsSetSpacing(zapp_fonts, spacing);
    fonsSetAlign(zapp_fonts, FONS_ALIGN_LEFT | FONS_ALIGN_TOP);

    float ascender = 0.0f;
    float descender = 0.0f;
    float line_height = 0.0f;
    fonsVertMetrics(zapp_fonts, &ascender, &descender, &line_height);
    if (height) {
        *height = ascender - descender;
    }

    const char* begin = (const char*)text;
    return fonsTextBounds(zapp_fonts, 0.0f, 0.0f, begin, begin + text_len, NULL);
}

void zapp_font_draw(
    const unsigned char* text,
    int text_len,
    float x,
    float y,
    float size,
    float spacing,
    uint8_t r,
    uint8_t g,
    uint8_t b,
    uint8_t a
) {
    if (!zapp_fonts || zapp_ui_font == FONS_INVALID || !text || text_len <= 0) {
        return;
    }

    fonsSetFont(zapp_fonts, zapp_ui_font);
    fonsSetSize(zapp_fonts, size);
    fonsSetSpacing(zapp_fonts, spacing);
    fonsSetColor(zapp_fonts, sfons_rgba(r, g, b, a));
    fonsSetAlign(zapp_fonts, FONS_ALIGN_LEFT | FONS_ALIGN_TOP);

    const char* begin = (const char*)text;
    fonsDrawText(zapp_fonts, x, y, begin, begin + text_len);
}

void zapp_font_flush(void) {
    if (zapp_fonts) {
        sfons_flush(zapp_fonts);
    }
}
