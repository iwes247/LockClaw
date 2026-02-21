# Image Builder Stubs

This directory is a transition layer from container-first builds to VM/installer artifacts.

## Why this exists

OpenClaw docs used in this repo define Docker/Nix build paths, but do not define an authoritative ISO/qcow2/raw builder.
These stubs keep the repo structured and auditable while you choose a concrete image toolchain.

## Quick start

1. Copy config template:
   - `cp image-builder/config/flavor.env.example image-builder/config/flavor.env`
2. Edit `image-builder/config/flavor.env`
3. Run:
   - `make -C image-builder validate`
   - `make -C image-builder iso`
   - `make -C image-builder qcow2`
   - `make -C image-builder raw`

Generated files are placeholders in `image-builder/output/*.stub`.

## Contract for future real implementation

- Preserve overlay inputs under `overlays/etc/security` and `overlays/etc/network`.
- Preserve package policy manifests under `packages/`.
- Keep `scripts/test-smoke.sh` as post-build validation gate.
- Keep default exposure policy aligned with `docs/design-spec.md`.
