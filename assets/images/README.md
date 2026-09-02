# Image assets

The renderer embeds these encoded assets and decodes them once while its image
registry is initialized. UI code refers to them through the stable resource IDs
defined in `src/assets/image_catalog.zig`; no image decoding or file I/O occurs
while a frame is being built or rendered.

| File | Format | Intrinsic size | SHA-256 |
| --- | --- | --- | --- |
| `app-hero.png` | PNG | 128 x 64 | `ec1bbe03996b23aa6e3f7e79659d60b480d0162f4e52cd24573c6af185dd6b42` |
| `activity-card.jpg` | JPEG | 96 x 64 | `3b837c971b112c2f2a509f344799e24e389a0a5e3133eedb925f9be6c5d26efa` |

When an asset is replaced, update its catalog dimensions and this checksum
table together. The registry rejects decoded dimensions that disagree with the
catalog metadata.
