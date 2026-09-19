# Changelog

## Unreleased — official CLI integration

- Build the GUI without bundled StarNet2 binaries, weights or runtime libraries.
- Discover and validate the current official CLI, with explicit custom-path support.
- Download verified official Mac installers and hand installation to Apple Installer.
- Check for CLI updates at launch (optional) or on request, comparing version/build.
- Show actual tile progress and CLI diagnostics; handle cancellation and failed output.
- Present the installed StarNet2 terms and remember acceptance by license content.
- Add native Mac regression tests and real-release verification harnesses.

## GitHub preparation build

- Set English as the default development language and translate the application interface, menus, notifications, and built-in logs.

- Remove personal Xcode workspace state and Finder metadata.
- Add ignore rules, a build script, and project documentation.
- Exclude third-party engine binaries, libraries, and model weights from the source package.
- Limit supported input to TIFF, PNG, and JPEG, using shared validation for opening and dropping files.
- Add a save panel and process into temporary files before atomically saving a successful result.
- Prevent duplicate processing starts and wait for the engine to exit after cancellation.
- Check the engine exit status and display standard error output.
- Use separate paths for starless and star outputs and clean up auxiliary temporary files.
- Validate model readability rather than executable permissions.
- Clarify that the result button reveals an already saved file in Finder.
