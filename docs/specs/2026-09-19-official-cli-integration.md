# Official CLI integration

Replace the bundled Torch engine with a separately installed official StarNet2
CLI, targeting 2.6.2-0241. Keep TIFF/PNG/JPEG and starless/stars-only controls.

- Discover/probe an installed CLI using machine-info; no weight/runtime overrides.
- Consume buffered machine-progress/diagnostic JSONL; successful process exit and
  validated output, not inference finish, establish job completion.
- Download the architecture-appropriate official installer on user request.
  Check HTTPS origins, byte count, SHA-256 and macOS package trust; open Apple
  Installer for approval. No silent installation. Recheck after returning.
- Installer setup uses an indeterminate spinner with metadata/download/checksum/
  macOS trust/opening stages. Do not show a percentage without live byte events.
  Image-processing progress remains determinate and driven by actual CLI tiles.
- Compare numeric version/build. Offline update checks do not block processing.
- Present the installed StarNet2 license and remember affirmative acceptance by
  content hash. Do not bundle engine files or introduce a source-code license.
- Test contracts and native Mac processing; document all untested UAT separately.

No FITS preview, new processing options, CLI release, or public GUI release.
