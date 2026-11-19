# Reference results

`reference.tif` and `reference_nondefault.tif` are the reference outputs of
MSPA 2.4 from
[MSPAstandalone](https://github.com/vogtpet/MSPAstandalone/tree/main/source/testing)
for `examples/input.tif`:

| File | Parameters |
|---|---|
| `reference.tif` | FGconn 8, EdgeWidth 1, Transition 1, Internal 1 (defaults) |
| `reference_nondefault.tif` | FGconn 4, EdgeWidth 1, Transition 1, Internal 0 |

`scripts/smoke-test.R` compares the pixel values of the plugin output with
these images. The reference images have no georeference; the plugin adds the
projection of the input image, so only the pixel values and the class codes
are compared.

The reference images were produced by the verified Linux and macOS builds of
MSPA and are pixel-identical on x86_64 and aarch64.
