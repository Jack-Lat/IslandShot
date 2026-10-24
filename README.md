# IslandShot — GitHub Actions build

This repository includes a minimal SwiftUI app and a GitHub Actions workflow that builds an **unsigned IPA** on a macOS runner.

## Build it
1. Create a new GitHub repository.
2. Upload all files from this folder (keep the `.github/workflows/build-ipa.yml` path).
3. Open **Actions** → **Build IslandShot IPA** → **Run workflow** (or push to `main`).
4. When the run finishes, open the run and download the `IslandShot-unsigned-IPA` artifact.
5. Import `IslandShot-unsigned.ipa` into Sideloadly and let Sideloadly sign/install it using your Apple ID.

## Important
- This workflow builds an **unsigned** IPA; Sideloadly must sign it. It is not a ready-to-install signed IPA.
- A free Apple ID signing typically needs re-signing/reinstalling after the signing period expires; Sideloadly will show the applicable details.
- The workflow has not been run in this environment, so the first GitHub run is the actual build test.
- The app overlays a configurable black pill on an image. It does not change iOS or the physical notch, and it does not yet automatically detect/erase the old notch content.
- For privacy, keep signing certificates and Apple ID credentials out of the repository and GitHub logs.
