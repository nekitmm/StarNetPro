# Official CLI integration

Replace the bundled Torch engine with a separately installed official StarNet2
CLI, targeting 2.6.2-0241. Keep TIFF/PNG/JPEG input, save starless images and expose
the CLI's optional Difference and Unscreen star outputs.

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

No FITS preview, other new processing options, CLI release, or public GUI release.

## Simplified first-run screen

- Short status, Download and Install (automatically skipped for a compatible CLI),
  Check on Launch, and Download Manually. Keep advanced location controls in the
  menu bar so a stale custom path cannot strand users behind the setup gate.
- Minimum compatible version is 2.6.2; newer versions still must satisfy the
  machine contract. A newer feed release does not raise this floor automatically.
- Skipping installation never skips license acceptance. An already accepted compatible
  installation opens the workspace directly. Recheck on app activation, including
  after a manual installation; no Refresh button is needed on the start screen.

## Post-install transition correction

Detecting a compatible installation must leave the download screen immediately.
If its license needs acceptance, open the license sheet automatically once per
license content per app session. Closing it leaves a dedicated Review License
screen, not an invitation to reinstall. Repeated activation/probes must not reopen
a dismissed sheet. Acceptance opens the workspace and persists across launches;
changed terms require acceptance again. Never infer consent from installation.

## Sidebar and optional star outputs

- Sidebar header shows only the installed semantic version. Location, backend,
  build details, license, update/discovery controls and support links move into
  a collapsed Advanced section below processing settings.
- Always save and preview the starless image. Replace Stars Only with independent
  Difference and Unscreen checkboxes, both initially off. Both may be selected.
  Pass --mask and --unscreen directly to the CLI in the same inference run.
- Saving starless.tiff also saves starless_difference.tiff and/or
  starless_unscreen.tiff beside it. Confirm existing companion replacements;
  reject aliases/duplicate destinations or source overwrite. Validate every
  requested generated image before publishing any. Report individual saved paths
  and any save failure accurately; multiple filesystem writes are not atomic as
  a group. Never publish failed or cancelled inference outputs.
- Prove flag mapping with tests, exercise all four output combinations and missing
  companion cases, then compare all three outputs byte-for-byte against a direct
  official CLI run on the real SHO fixture. No GUI-side star arithmetic.
