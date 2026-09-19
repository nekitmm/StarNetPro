# Third-party components

StarNetPro invokes the official StarNet2 CLI as a separate process. This repository
and its GUI package do not include StarNet2, model weights, LibTorch, OpenCV, or
other CLI runtime libraries.

Install the complete CLI from [StarNetAstro](https://starnetastro.com/cli-tools/starnet/)
or use the in-app download action, which fetches the official installer directly.
The CLI package supplies its own license and third-party notices. StarNetPro
presents the installed product license and records acceptance by content hash.

The previous integration required an externally supplied 2023 Torch engine bundle.
That packaging path has been removed; do not put old binaries into the GUI bundle.

StarNetPro's source-code license still requires an upstream maintainer decision.
This contribution does not assert ownership of the original source or grant rights
to redistribute separately licensed StarNet2 components.
