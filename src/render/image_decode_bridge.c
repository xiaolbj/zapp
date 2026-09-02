#include <limits.h>
#include <stddef.h>
#include <stdint.h>
#include <string.h>

#define STBI_NO_STDIO
#define STBI_ONLY_PNG
#define STBI_ONLY_JPEG
#define STBI_NO_HDR
#define STBI_NO_LINEAR
#define STB_IMAGE_IMPLEMENTATION
#include "stb_image.h"

typedef struct zapp_decoded_image {
    unsigned char *pixels;
    int width;
    int height;
    size_t byte_count;
} zapp_decoded_image;

enum {
    ZAPP_IMAGE_OK = 0,
    ZAPP_IMAGE_INVALID_ARGUMENT = 1,
    ZAPP_IMAGE_INVALID_DATA = 2,
    ZAPP_IMAGE_LIMIT_EXCEEDED = 3,
    ZAPP_IMAGE_DECODE_FAILED = 4,
};

int zapp_image_decode_rgba(
    const unsigned char *encoded,
    size_t encoded_length,
    int max_dimension,
    size_t max_decoded_bytes,
    zapp_decoded_image *out_image
) {
    int width = 0;
    int height = 0;
    int expected_width;
    int expected_height;
    int components = 0;
    size_t pixel_count;
    size_t byte_count;
    unsigned char *pixels;

    if (out_image == NULL) return ZAPP_IMAGE_INVALID_ARGUMENT;
    memset(out_image, 0, sizeof(*out_image));
    if (encoded == NULL || encoded_length == 0 || encoded_length > INT_MAX ||
        max_dimension <= 0 || max_decoded_bytes == 0) {
        return ZAPP_IMAGE_INVALID_ARGUMENT;
    }
    if (!stbi_info_from_memory(encoded, (int)encoded_length, &width, &height, &components)) {
        return ZAPP_IMAGE_INVALID_DATA;
    }
    if (width <= 0 || height <= 0 || width > max_dimension || height > max_dimension) {
        return ZAPP_IMAGE_LIMIT_EXCEEDED;
    }
    if ((size_t)width > SIZE_MAX / (size_t)height) return ZAPP_IMAGE_LIMIT_EXCEEDED;
    pixel_count = (size_t)width * (size_t)height;
    if (pixel_count > SIZE_MAX / 4u) return ZAPP_IMAGE_LIMIT_EXCEEDED;
    byte_count = pixel_count * 4u;
    if (byte_count > max_decoded_bytes) return ZAPP_IMAGE_LIMIT_EXCEEDED;

    expected_width = width;
    expected_height = height;

    pixels = stbi_load_from_memory(encoded, (int)encoded_length, &width, &height, &components, 4);
    if (pixels == NULL) return ZAPP_IMAGE_DECODE_FAILED;
    if (width != expected_width || height != expected_height) {
        stbi_image_free(pixels);
        return ZAPP_IMAGE_DECODE_FAILED;
    }

    out_image->pixels = pixels;
    out_image->width = width;
    out_image->height = height;
    out_image->byte_count = byte_count;
    return ZAPP_IMAGE_OK;
}

void zapp_image_free(unsigned char *pixels) {
    stbi_image_free(pixels);
}
