# StarNetPro

A macOS application for removing stars from astrophotography images, built with SwiftUI and powered by an external StarNet2 engine. This is an independent project, not an official StarNet product.

The application interface, menus, notifications, and built-in log messages are in English.

## Features

- Open or drag and drop TIFF, PNG, and JPEG images.
- Generate a starless image or a separate star image.
- Adjust the processing stride and cancel processing.
- Choose an output location and save the result as TIFF.

FITS input is not supported in this version. Convert FITS images to TIFF before importing them.

## System requirements

- Apple Silicon Mac (M-series chip); Intel Macs are not supported by the bundled test engine.
- macOS 15.5 or later.
- Xcode is required only when building from source.

## Download and use

GitHub's **Code → Download ZIP** downloads source code, not a runnable application. When a release is available, download the application ZIP from **Releases → Assets**, extract it, and move `StarNetPro.app` to Applications.

A public, Developer ID-signed and notarized release is not available yet. The maintainer's local test build includes third-party components whose redistribution terms still need to be verified. It uses ad-hoc signing and may be blocked by macOS when downloaded.

To process an image, open or drop a supported file, choose the stride and output mode, and start processing. Select where to save the TIFF result. Enable star mode for a star image; leave it disabled for a starless image.

## Build from source

1. Install the full Xcode application. This version was built with Xcode 26.3.
2. Follow `StarNetBin/README.md` to supply the compatible StarNet2 v2.1.0 ARM64 Torch runtime.
3. Run:

   ```sh
   ./scripts/build.sh
   ```

Build artifacts are written to `dist/`. The script creates an ad-hoc-signed local test build; it does not perform Developer ID signing or notarization.

This repository does not include the engine, model weights, or dynamic libraries. The interface can compile without them, but image processing will not work. Do not assume that current StarNet releases are compatible with this older command-line interface or model format.

## Data handling

The visible Swift source processes images locally through the engine. It does not implement accounts, advertising, analytics, or image uploads. This is not a complete privacy audit of the closed-source engine. Logs may contain local file paths; remove personal information before sharing them.

## Validation and limitations

- The Release / arm64 build passed with Xcode 26.3.
- The supplied engine processed a synthetic 512 × 512 image on the CPU and produced 16-bit TIFF starless and star outputs.
- Local application signature integrity checks passed.
- End-to-end GUI testing, real astrophotography images, large images, MPS/GPU execution, other Macs, and downloaded-file Gatekeeper behavior have not been fully tested.
- The application has not been Developer ID-signed or notarized.
- This version is being prepared for GitHub distribution and does not yet meet Mac App Store sandbox requirements.

## License and third-party components

The original source archive did not include a source-code license. Original author credits are preserved. No MIT or other license has been added without the maintainer's decision; the maintainer must confirm ownership and choose a license.

The StarNet engine, model, and libraries are separate third-party components. Any future license for this repository's source code does not automatically cover them. See `THIRD_PARTY.md`.
