# Third-party components

## Original StarNetPro application

This fork is based on [leohgyang/StarNetPro](https://github.com/leohgyang/StarNetPro).
Original source files credit Sunny Ma, and those credits are preserved. Our
integration changes do not transfer ownership of the original code or assets or
imply the original authors' endorsement.

Upstream has not declared a source-code license. We have not added one on its
behalf. An explicit license or permission from the relevant rights holders is
needed before public GUI binary distribution; see the
[README's licensing section](README.md#licensing-and-distribution).

## StarNet2 CLI

StarNetPro invokes the official StarNet2 CLI as a separate process. This repository
and its GUI package do not include StarNet2, model weights, LibTorch, OpenCV, or
other CLI runtime libraries.

Install the complete CLI from [StarNetAstro](https://starnetastro.com/cli-tools/starnet/)
or use the in-app download action, which fetches the official installer directly.
The CLI package supplies its own license and third-party notices. StarNetPro
presents the installed product license and records acceptance by content hash.

The previous integration required an externally supplied 2023 Torch engine bundle.
That packaging path has been removed; do not put old binaries into the GUI bundle.

The CLI license and third-party notices apply to those separate components, not
to the original StarNetPro application. This fork does not grant permission to
redistribute StarNet2 or its dependencies.
