# GitCubeTest
Test Repository for an OpenSCAD project

## 3D Preview

👉 **Interactive viewer:**
https://numberformat.github.io/GitCubeTest/

👉 **Download STL:**
[Latest Release](https://github.com/numberformat/GitCubeTest/releases/latest)

A minimal reference project demonstrating how to:

- Design parametric parts in **OpenSCAD**
- Build STL files **headlessly in CI**
- Publish generated artifacts via **GitHub Releases**
- Preview STL geometry interactively using **GitHub Pages + Three.js**
- Keep source control clean (no generated STLs committed)

This repository intentionally keeps the model simple (a cube) so the focus stays on **the pipeline**, not the geometry.

---

## Project Structure

```

.
├── cube.scad                  # Parametric OpenSCAD model (source of truth)
├── docs/
│   └── index.html              # Browser-based STL viewer (Three.js)
├── .github/
│   └── workflows/
│       └── build.yml           # CI pipeline (OpenSCAD → STL → release/pages)
├── .nojekyll                   # Disables Jekyll for GitHub Pages
└── README.md

````

### Design principles

- **Source, not artifacts, live in Git**
- **STLs are generated**, never committed
- **CI is the compiler**
- **Pages is a viewer**, not a build system

---

## OpenSCAD Model (`cube.scad`)

The OpenSCAD file defines a fully parametric model:

```scad
cube_size = 20;
cube([cube_size, cube_size, cube_size], center = true);
````

Changing a parameter and committing triggers:

* A rebuild
* A new STL
* A new release (on `main`)
* An updated 3D preview

This pattern scales naturally to multiple modules, assemblies, and parts.

---

## Branch Strategy

This project uses a conservative branch model:

| Branch     | Purpose                        |
| ---------- | ------------------------------ |
| `develop`  | Iteration, testing, validation |
| `main`     | Stable, publishable artifacts  |
| `gh-pages` | Generated static output only   |

### Behavior by branch

* **develop**

  * STL is built in CI
  * Output is uploaded as a workflow artifact
  * No releases
  * No Pages deployment

* **main**

  * STL is built in CI
  * GitHub Release is created
  * STL viewer is deployed to GitHub Pages

---

## GitHub Actions (CI)

The workflow performs the following steps:

1. Check out the repository
2. Install OpenSCAD on Linux
3. Render STL files headlessly
4. Assemble a static site directory
5. Conditionally:

   * Upload artifacts (develop)
   * Create releases and deploy Pages (main)

Key idea: **the same build, different outcomes depending on trust level**.

---

## STL Viewer (GitHub Pages)

The STL preview is implemented using:

* Native browser **ES modules**
* **Import maps** (no bundler, no npm)
* Three.js + STLLoader
* OpenSCAD-like colors and lighting

### Why import maps?

Three.js example modules internally import `"three"` as a bare specifier.
Browsers require an import map to resolve this without a bundler.

This keeps the site:

* Fully static
* CDN-based
* CI-friendly
* Archive-safe

---

## GitHub Pages Setup

Pages is configured to serve:

* **Branch**: `gh-pages`
* **Folder**: `/ (root)`

The `gh-pages` branch is **written exclusively by CI** and contains only:

```
index.html
cube.stl
.nojekyll
```

No hand edits. No history pollution.

---

## Releases

Each successful build on `main` creates a GitHub Release with:

* Versioned tag
* Generated STL attached as an asset

This gives consumers a clean, printable download while keeping Git history semantic.

---

## Reproducing This Pattern

To adapt this setup for your own project:

1. Replace `cube.scad` with your own OpenSCAD model(s)
2. Add additional `openscad -o ...` commands in CI for multiple parts
3. Update `index.html` to load different STLs or provide a selector
4. Keep generated geometry out of Git
5. Treat CI as the authoritative builder

This works equally well for:

* Single parts
* Assemblies
* Parametric libraries
* Hardware projects
* Print-ready releases

---

## Why This Matters

This repository demonstrates a simple but powerful idea:

> **Geometry can be built, versioned, reviewed, and published the same way software is.**

Once you remove the GUI dependency, CAD becomes:

* Automatable
* Reviewable
* Reproducible
* Shareable

That’s the real point of this project.

---

## Local Build

This repo includes two local build scripts that mirror CI output.

**macOS/Linux (bash):**
```bash
./build.sh
```

**Windows/macOS/Linux (PowerShell 7+):**
```powershell
./build.ps1
```

Both scripts:

- Create `site/`
- Copy `docs/index.html` and `.nojekyll`
- Render each `*.scad` in the repo root to `site/*.stl`
- Generate `site/models.json` for the viewer dropdown

### OpenSCAD location

If `openscad` is not on `PATH`, set `OPENSCAD_BIN` to the executable path:

```bash
export OPENSCAD_BIN="/Applications/OpenSCAD.app/Contents/MacOS/OpenSCAD"
```

```powershell
$env:OPENSCAD_BIN = "C:\Program Files\OpenSCAD\openscad.exe"
```
