# Work log

- Base: leohgyang/StarNetPro main, 9aa2306f24df275632711b3faac61ac2dfc0f550.
- Separate checkout/feature branch; existing product repository untouched.
- Existing wrapper requires bundled Torch weights and libraries, simulates
  progress, and has only a placeholder unit test.
- Verified official feed advertises StarNet2 2.6.2-0241 for both Mac architectures.
- No installed applications or release feeds changed.

## Native verification in progress

- macOS 26.7, Xcode 27.0; first Debug build passed without an engine bundle.
- 18 new automated contract/process tests passed. The test sync initially retained
  upstream's deleted placeholder test on the Mac; removing that stale file before
  final verification. Two existing SwiftUI deprecation warnings are unrelated.
- Real official installer downloaded through the new Swift service: 128085271
  bytes, SHA-256 596f69c25dbf1601e37d62cd36e309ee0365890edd24e012bb4d006110b3d0de.
  macOS spctl install assessment passed. No installation performed.
- Real-package probe caught an incorrect license filename assumption. Portable
  archives use LICENSE.txt beside the executable; the Mac installer uses
  /usr/local/share/doc/starnet2/LICENSE.txt. Corrected discovery and added a
  package-layout regression test. Not using PixInsight license paths.
- Working checkouts are under Development/project-cosm-upstream/StarNetPro on
  both development hosts, separating upstream contributions from owned projects.
- Real SHO inference exposed delayed pipe delivery: FileHandle.read(upToCount:)
  buffered small progress messages until EOF. Replaced with availableData and
  added a regression requiring a short progress message before child exit.
  This was a wrapper bug, not a missing CLI progress stream.

## Verified results

- 21 XCTest tests passed on Apple Silicon, including the legacy-version message.
- Real 2048x2048, RGB16 SHO.tif: GUI processor and direct StarNet2 2.6.2-0241
  CoreML produced byte-identical files in both modes, with live progress observed.
  - Starless: 33419418 bytes, SHA-256
    d1c1484262e3d20221d6c79aefb12318218fa1efd6196a4d4087fa4141eef09f.
  - Stars: 5132322 bytes, SHA-256
    2cd191ce6f609bd0170b32193d7cd430633e7c9d85a48831326dcb02f821027a.
- The private real image and generated outputs are not added to this repository.
- Mac checkout: ~/Development/project-cosm-upstream/StarNetPro. Evidence is in
  ignored build/qa/ (real-output-3, installer-expanded, current CLI archive) and
  build/Logs/Test/*.xcresult. These are generated QA files, not release materials.

## Pending user acceptance / boundaries

- Clean first-run GUI, download/install approval, license dialog, cancellation and
  reopen behavior are awaiting user UAT. Native Intel GUI is not qualified.
- The source repository still has no declared license. No source license added;
  public app Developer ID signing/notarization remains an upstream decision.
- The existing system CLI is 2.5.0; no system CLI was replaced during verification.
- Pipeline commands: bash scripts/test.sh; the two swiftc verification commands
  in README.md; bash scripts/build.sh for the ad-hoc-signed local app/ZIP.
- User selected upgrade-path UAT, leaving installed 2.5.0 untouched; missing-CLI
  UAT is deferred. Real 2.5.0 rejects --machine-info and reports its version via
  --version. Added a diagnostic-only legacy probe and regression test so the UI
  identifies the installed version and offers an update, rather than a JSON error.
- Native setup harness verified installed 2.5.0 gives that exact upgrade message,
  while the expanded 2.6.2-0241 installer payload is compatible and discovers its
  license. License acceptance starts false in the isolated test preferences.
- Release app built and passed codesign --verify --deep --strict. No StarNetBin
  resource is present. Local test ZIP SHA-256:
  ded0b5ff643dca1d046cc95dfea6d3618d307b0171cc0162fee070700e0e039b.
  Copied byte-identically to Mac Downloads/StarNetPro-CLI-upgrade-test-20260919.zip
  and revealed in Finder. The system CLI still reports 2.5.0.
- Xcode 27 Release builds emitted a contradictory SwiftCompile diagnostic saying
  a command failed with exit code 0, but xcodebuild returned 0 and produced the
  signed app. Native tests passed; manual Release-app UAT remains the next gate.
- git diff --check and bash syntax checks passed. This upstream repository has
  no pre-commit configuration; the native tests are the executable validation gate.
- Initial UAT requested a main-window setup gate rather than a sidebar warning.
  Missing/incompatible CLI and unaccepted license now replace the image workspace;
  open/drop/menu processing cannot bypass this gate. Re-probing a compatible CLI
  keeps the existing workspace visible while controls are disabled.
- GitHub's configured OAuth credential lacks workflow scope. Omitted the optional
  CI workflow from this first PR instead of requesting wider account permissions.
  scripts/test.sh remains the repeatable native test entrypoint.
- Setup-gate revision: all 21 tests passed again; local Release app built and
  signature verified. UAT copy is in Downloads/StarNetPro-CLI-upgrade-r2 on the Mac.
  ZIP SHA-256: 2f5fce853ce2f25036b6f739763f65d182e26e187be8eb12dc5a6a80aca92efe.
- Draft upstream PR: https://github.com/leohgyang/StarNetPro/pull/1.
  Code commit: 0838b04. Upgrade-path UAT is in progress; no merge/release claimed.

## Download indicator UAT correction

- User reported the download bar stayed at zero until Apple Installer opened.
- Reproduced with the actual installer verifier: the server advertised
  Content-Length: 128085271, but the async URLSession download delivered zero
  didWriteData callbacks to our delegate while successfully downloading/verifying.
- Replaced the misleading bar with an indeterminate spinner and explicit
  metadata/download/checksum/macOS trust/opening stages. Removed the unused byte
  progress state/delegate path; retained exact final size/hash/trust checks and
  allowed-origin redirect policy. Inference's real tile progress is unchanged.
- Real installer verifier now requires all three service phase callbacks in
  order, on the main actor, before success. No automatic installation is tested.
- Verification: all 21 native tests passed; actual 128085271-byte official
  installer passed phase-order assertion, SHA-256 validation and spctl install
  trust assessment. No installer was opened by the automated test.
- Rebuilt and signature-verified local app is in Mac Downloads/
  StarNetPro-CLI-upgrade-r3/StarNetPro.app. ZIP SHA-256:
  e8c17b1df76af7c10c4e3d81a787cd40b6da09376894803761fe41fe96763013.
  Installed CLI still reported 2.5.0 before the tests; no system install changed.
  Spinner's visual behavior remains for user UAT, distinct from service-phase tests.
