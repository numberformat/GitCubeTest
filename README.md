# SCADPipeline
Test Repository for an OpenSCAD project

## 3D Preview

👉 **Interactive viewer:**
https://numberformat.github.io/SCADPipeline/

👉 **Download STL:**
[Latest Release](https://github.com/numberformat/SCADPipeline/releases/latest)

A minimal reference project demonstrating how to:

- Design parametric parts in **OpenSCAD**
- Build STL files **headlessly in CI**
- Publish generated artifacts via **GitHub Releases**
- Preview STL geometry interactively using **GitHub Pages + Three.js**
- Keep source control clean (generated STLs are not committed)

This repository intentionally keeps the model simple so the focus stays on **the pipeline**, not the geometry.

---

## Design principles

- **Source, not artifacts, live in Git**
- **Generated STLs are built in CI**
- **Pre-built assets are inputs**, committed under `src/assets/`
- **CI is the compiler**
- **Pages is a viewer**, not a build system

---

## How it works

- Builds run inside a Docker container with OpenSCAD preinstalled.
- The repo is bind‑mounted into the container; outputs are written to `site/`.
- The viewer loads `site/models.json` to populate the model dropdown.
- GitHub Actions runs the same containerized build.

---

## Local build (Docker only)

Requirements: Docker Desktop (or Docker Engine).

**macOS/Linux (bash):**
```bash
./build.sh
```

**Windows/macOS/Linux (PowerShell 7+):**
```powershell
./build.ps1
```

Both scripts run the same Docker container and:

- Create `site/`
- Copy `docs/index.html` and `.nojekyll`
- Render each `*.scad` in `src/models/` to `site/*.stl`
- Copy pre-built assets from `src/assets/` into `site/assets/` (STL assets are listed in `site/models.json`)
- Generate `site/models.json` for the viewer dropdown

The viewer lists both compiled STLs (from `src/models/`) and pre-built STLs (from `src/assets/`). For simplicity, the build uses **top-level files only** (no recursion).

### Assets-only template

To use this repository without OpenSCAD sources, put your `*.stl` files directly in `src/assets/` and skip `src/models/` entirely. The build will publish your pre-built STLs into the viewer with no `.scad` files required.

### Run viewer

Serve the built site locally (defaults to http://localhost:8080; if taken, the script will pick the next available port). You can also force a port with `SITE_PORT`.

```bash
./run.sh
```

```powershell
./run.ps1
```

### Clean artifacts

Remove all generated build output.

```bash
./clean.sh
```

```powershell
./clean.ps1
```

### Docker image

Default image: `openscad/openscad:bookworm`

If you're on Apple Silicon (arm64) and see a manifest error, set:

```bash
export OPENSCAD_DOCKER_PLATFORM="linux/amd64"
```

```powershell
$env:OPENSCAD_DOCKER_PLATFORM = "linux/amd64"
```

Override with `OPENSCAD_DOCKER_IMAGE` if you want a different tag:

```bash
export OPENSCAD_DOCKER_IMAGE="openscad/openscad:bookworm"
```

```powershell
$env:OPENSCAD_DOCKER_IMAGE = "openscad/openscad:bookworm"
```

---

## Releases

Each successful build on `main` creates a GitHub Release with:

- Versioned tag
- Generated STL attached as an asset

---

## Why this matters

This repository demonstrates a simple but powerful idea:

> **Geometry can be built, versioned, reviewed, and published the same way software is.**

Once you remove the GUI dependency, CAD becomes:

- Automatable
- Reviewable
- Reproducible
- Shareable
