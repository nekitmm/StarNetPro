# StarNetPro

An independent macOS GUI for the official StarNet2 command-line tool, originally
created by Sunny Ma. This is not an official StarNet product.

## First run

1. Open StarNetPro. It checks for StarNet2 in the official installer location
   (`/usr/local/bin/starnet2`), then Homebrew/PATH locations.
2. If it is missing or incompatible, click **Download and Install…**.
   The app fetches the latest release for your Mac from StarNetAstro, verifies
   the installer's size and SHA-256, and asks macOS to assess its trust.
   A spinner identifies the current download/verification stage; it does not
   claim a transfer percentage.
3. Apple Installer opens. Review the package and approve installation there.
   StarNetPro never asks for your administrator password or installs silently.
4. Return to StarNetPro; it rechecks the installation automatically. **Skip** uses
   an already compatible CLI instead of installing again. If its terms have not
   been accepted, Skip opens the license dialog first. Acceptance is remembered;
   changed license contents require renewed acceptance.
5. Open a TIFF, PNG or JPEG, choose the stride and output mode, and process it.
   **Stars Only** saves the CLI's subtractive star mask instead of its starless
   output. Output is saved as TIFF.

For a portable installation, use **StarNet2 CLI → Choose Executable…** in the
menu bar to select its `starnet2` executable without cluttering the start screen.
Keep the complete CLI archive together, including its model, libraries and
`LICENSE.txt`. A custom selection takes precedence over automatic discovery.
Use **StarNet2 CLI → Use Automatic Location** after installing system-wide if an old custom
selection is still active.

The CLI is downloaded directly from official sources, not bundled in this app.
It locates its own model/runtime files. There is no need to copy weights, rename
models, or configure library paths.

## Compatibility and progress

- The app requires macOS 15.5 or later. The supplied build script targets Apple
  Silicon; a native Intel GUI has not been qualified by this change.
- StarNet2 CLI **2.6.2 or newer** with the supported machine-info and machine-progress
  contracts is required. The old bundled 2.1.0 Torch engine is no longer supported.
  The minimum stays at 2.6.2 when newer releases are published; update availability
  is separate from compatibility.
- Apple Silicon downloads select the CoreML CLI, including if a GUI is translated
  by Rosetta. The release feed also defines the Intel/ORT package lane.
- Processing passes the original file to the CLI; previews are not processing
  inputs. The CLI determines supported image/sample formats and output depth.
  This GUI does not add float-TIFF support or convert unsupported data silently.
- FITS preview/import remains out of scope. Convert to a suitable TIFF upstream.
- The progress bar reports actual **tile inference**, not total wall-clock work.
  Preparation and final output writing are separate phases. Completion requires
  a successful process exit and a readable output; errors/warnings stay in the log.
- Cancel stops the CLI and does not publish a partial result. Existing destination
  files are replaced only after a successful run.

## CLI updates and privacy

The GUI and CLI have independent versions. StarNetPro checks the public
[official release feed](https://starnetastro.com/cli-tools/latest.json) at launch;
disable **Check on Launch** to opt out, or use **Check for CLI Updates** manually.
Version and build numbers are compared numerically. Checks failing offline do not
prevent use of an already installed compatible CLI.

Downloads and installation are always user-initiated. No background installer,
automatic replacement, app self-update, account, image upload, or analytics is
implemented. Update requests contact StarNetAstro over HTTPS; image processing is
local. Logs include local paths, so review them before sharing.

Verified installers are kept in a uniquely named macOS temporary directory while
Apple Installer may need them. They are not application-bundled resources.

## Build and test

Install full Xcode, then run:

```sh
bash scripts/build.sh
bash scripts/test.sh
```

No CLI, weights, or third-party runtime is needed to compile or run the automated
tests. The tests use temporary fake executables and fixture images. The build
script creates an ad-hoc-signed local test ZIP under `dist/`; it does not produce
a Developer ID-signed/notarized public release.

For optional real-release checks on a Mac:

```sh
mkdir -p build/qa
xcrun swiftc -parse-as-library StarNetPro/Models/*.swift \
  scripts/verify-real-cli.swift -o build/qa/verify-real-cli
build/qa/verify-real-cli /path/to/starnet2 /path/to/image.tif build/qa/new-results

xcrun swiftc -parse-as-library StarNetPro/Models/*.swift \
  scripts/verify-installer.swift -o build/qa/verify-installer
build/qa/verify-installer
```

The first compares the GUI processing path's starless and stars-only saved files
byte-for-byte with direct CLI results and observes live progress. Use a new output
directory. The second downloads and verifies the official installer, but never
opens or installs it. Neither test establishes manual GUI/Installer usability.

See [verification notes](docs/build-logs/2026-09-19-official-cli-integration.md)
for tested releases, results and outstanding UAT.

## Licensing and distribution

The upstream source archive did not declare a source-code license. Original
credits are preserved; this contribution does not assign a new license.
The maintainer must settle source licensing before claiming open-source reuse rights.

StarNet2 is separately licensed. Its terms are presented from the user's official
CLI installation. No StarNet2 binaries, weights or runtime libraries are shipped
with StarNetPro. See [THIRD_PARTY.md](THIRD_PARTY.md).

A public signed/notarized StarNetPro release and Mac App Store distribution are
not part of this change.
