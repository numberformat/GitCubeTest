# SCADPipeline

A reusable CI/CD toolchain for OpenSCAD projects

SCADPipeline turns OpenSCAD designs into a **software-style build pipeline**:

* Parametric models in Git
* Deterministic STL builds in CI
* Web-based 3D previews
* Versioned, downloadable releases

This repository contains both a **reference implementation** (a cube and a cylinder) and the **pipeline itself**, which you can reuse across your own design projects without forking.

---

## 3D Preview

👉 **Interactive viewer:**
[https://numberformat.github.io/SCADPipeline/](https://numberformat.github.io/SCADPipeline/)

👉 **Download STL:**
[Latest Release](https://github.com/numberformat/SCADPipeline/releases/latest)

The geometry here is intentionally simple.
The point of this repo is not the shapes — it is the **build system**.

---

## What this repository is

This project serves two roles:

1. A minimal example OpenSCAD project (cube + cylinder)
2. A production-grade pipeline that can be imported into other repositories

You can browse, build, and preview this repo directly — or you can treat it as an **OpenSCAD toolchain** and pull it into your own design projects.

---

## Design principles

* **Source, not artifacts, live in Git**
* **Generated STLs are built in CI**
* **Pre-built assets are inputs**, committed under `src/assets/`
* **CI is the compiler**
* **Pages is a viewer**, not a build system

---

## How it works

* Builds run inside a Docker container with OpenSCAD preinstalled.
* The repo is bind-mounted into the container; outputs are written to `site/`.
* The viewer loads `site/models.json` to populate the model dropdown.
* GitHub Actions runs the same containerized build.

Everything that works locally also works in CI.

---

## Local build (Docker only)

Requirements: Docker Desktop (or Docker Engine).
The build runs in a container and auto-builds the local image as needed.

If you use the GitHub setup wizard, your token is saved to `~/.scadpipeline` on your host.
When creating a classic PAT, use minimal scopes:
- public repos only: `public_repo`
- private repos: `repo`
- org repos: `admin:org`
Avoid `delete_repo` and `project` unless you explicitly need them.

**macOS/Linux (bash):**

```bash
./pipeline.sh build
```

**Windows/macOS/Linux (PowerShell 7+):**

```powershell
.\pipeline.ps1 build
```

Both scripts run the same Docker container and:

* Create `site/`
* Copy `docs/index.html` and `.nojekyll`
* Append `README.md` (rendered as HTML) to the end of the viewer page
* Render each `*.scad` in `src/models/` to `site/*.stl`
* Copy pre-built assets from `src/assets/` into `site/assets/`
* Render PNG previews for each STL into `site/images/` with an `_stl` suffix
* Generate `site/models.json` for the viewer dropdown

The viewer lists both compiled STLs (from `src/models/`) and pre-built STLs (from `src/assets/`). For simplicity, the build uses **top-level files only** (no recursion).

Preview image size defaults to `1200,900` and can be overridden with `OPENSCAD_IMAGE_SIZE` (format: `WIDTH,HEIGHT`).

---

### Assets-only projects

You can use SCADPipeline without OpenSCAD sources at all.

Put your `*.stl` files in `src/assets/` and leave `src/models/` empty.
The build will publish your pre-built STLs into the viewer with no `.scad` files required.

---

### Run the viewer

Serve the built site locally (defaults to [http://localhost:8080](http://localhost:8080); if taken, the script picks the next available port). You can override with `SITE_PORT`.

```bash
./pipeline.sh run
```

```powershell
.\pipeline.ps1 run
```

---

### Clean artifacts

Remove all generated build output.

```bash
./pipeline.sh clean
```

```powershell
.\pipeline.ps1 clean
```

---

## Using SCADPipeline in Your Own Projects (No Forking Required)

SCADPipeline is designed to be reused across many OpenSCAD design projects without forking this repository or dealing with Git submodules.

Instead, each design project pulls a **snapshot** of the SCADPipeline build system using a small update script.
This gives you all of the CI/CD, viewer, and build logic — without inheriting this repository’s history or demo models.

Think of SCADPipeline as a **toolchain**, not a template.

---

### How it works

SCADPipeline publishes itself as a downloadable snapshot via GitHub.
Your project pulls that snapshot and copies the pipeline files into your repo.

Your design stays yours.
The pipeline stays updatable.

You choose when to upgrade.

---

### Step 1 — Add the update script to your project

In the root of your own OpenSCAD project, add one of these:

#### macOS / Linux

Create `get_pipeline.sh`:

```bash
#!/usr/bin/env bash
set -e

REPO_URL="https://github.com/numberformat/SCADPipeline/archive/refs/heads/main.zip"
TMP_DIR="$(mktemp -d)"

echo "Downloading SCADPipeline..."
curl -L "$REPO_URL" -o "$TMP_DIR/pipeline.zip"

echo "Extracting..."
unzip -q "$TMP_DIR/pipeline.zip" -d "$TMP_DIR"

PIPELINE_DIR="$(find "$TMP_DIR" -maxdepth 1 -type d -name "SCADPipeline-*")"

# Copy the pipeline into this project
rsync -av \
  --exclude 'examples/' \
  --exclude '*.scad' \
  --exclude 'LICENSE' \
  "$PIPELINE_DIR/" \
  "./"

cp "$PIPELINE_DIR/README.md" "./README_pipeline.md"
if [ -f "./README_template.md" ]; then
  mv "./README_template.md" "./README.md"
fi

mkdir -p src/assets src/config src/images src/lib src/models

rm -rf "$TMP_DIR"

echo "SCADPipeline updated."
```

This also creates `src/images/` for optional user-provided images.

Then make it executable:

```bash
chmod +x get_pipeline.sh
```

---

#### Windows (PowerShell)

Create `get_pipeline.ps1`:

```powershell
$RepoUrl = "https://github.com/numberformat/SCADPipeline/archive/refs/heads/main.zip"
$Temp = New-Item -ItemType Directory -Path ([System.IO.Path]::GetTempPath() + [System.Guid]::NewGuid())

Write-Host "Downloading SCADPipeline..."
Invoke-WebRequest $RepoUrl -OutFile "$Temp\pipeline.zip"

Write-Host "Extracting..."
Expand-Archive "$Temp\pipeline.zip" "$Temp"

$PipelineDir = Get-ChildItem $Temp | Where-Object { $_.Name -like "SCADPipeline-*" } | Select-Object -First 1

# Copy everything except example models
Get-ChildItem $PipelineDir.FullName -Recurse | Where-Object {
    $_.FullName -notmatch "\\examples\\" -and
    $_.Extension -ne ".scad" -and
    $_.FullName -notmatch "(?:^|[\\/])LICENSE$"
} | ForEach-Object {
    $target = $_.FullName.Replace($PipelineDir.FullName, (Get-Location).Path)
    New-Item -ItemType Directory -Path (Split-Path $target) -Force | Out-Null
    Copy-Item $_.FullName $target -Force
}

Copy-Item (Join-Path $PipelineDir.FullName "README.md") (Join-Path (Get-Location).Path "README_pipeline.md") -Force
if (Test-Path "README_template.md") {
  Move-Item "README_template.md" "README.md" -Force
}

New-Item -ItemType Directory -Path "src/assets","src/config","src/images","src/lib","src/models" -Force | Out-Null

Remove-Item $Temp -Recurse -Force
Write-Host "SCADPipeline updated."
```

This also creates `src/images/` for optional user-provided images.

---

### Step 2 — Pull SCADPipeline into your project

Run the script from your project root:

**macOS / Linux**

```bash
./get_pipeline.sh
```

**Windows**

```powershell
.\get_pipeline.ps1
```

This copies all CI/CD, viewer, and build logic from SCADPipeline into your project.

Your own `.scad` models are not touched.

---

### Step 3 — Commit the pipeline into your repo

After pulling the pipeline, commit the files:

```bash
git add .
git commit -m "Add SCADPipeline build system"
```

Your project now has a frozen, reproducible version of the SCADPipeline.

---

### Updating the pipeline later

Whenever you want the latest version:

```bash
./get_pipeline.sh
# or
.\get_pipeline.ps1
```

Then commit the changes.

This gives you **opt-in upgrades** — no breaking changes unless you choose them.

---

### Why this is better than forking

Forks rot.
Submodules confuse people.
Monorepos tangle unrelated designs.

This approach gives you:

• Full isolation per design
• Reproducible builds
• Zero Git coupling
• CI/CD that just works
• A real pipeline you can version

SCADPipeline becomes your **OpenSCAD toolchain**, not your project’s parent.

---

## Releases

Each successful build on `main` creates a GitHub Release with:

* A versioned tag
* Generated STL files attached as assets

## GitHub Pages

This build pipeline includes a viewer that publishes your model objects to GitHub Pages.

GitHub Pages is a free hosting service for static sites. It needs to be enabled for each repo (it is off by default).

**Optional (guided, console-only auth supported):**

```bash
./pipeline.sh create-github
```

```powershell
.\pipeline.ps1 create-github
```

The setup will initialize a git repo if needed, commit your current files, and ask how to handle any existing `origin` remote.

If GitHub Actions is disabled in the new repo, enable it here:

```
https://github.com/<owner>/<repo>/settings/actions
```

After GitHub Actions publishes the `gh-pages` branch, enable Pages here:

```
https://github.com/<owner>/<repo>/settings/pages
```

1. Go to your repository **Settings**.
2. Select **Pages** in the left nav.
3. Under **Source**, choose **Deploy from a Branch**.
4. Select the `gh-pages` branch and `/ (root)` as the folder.
5. Click **Save**. Within a few minutes, your viewer (with compiled STLs) will be live.

---

## License

This repository is licensed under the MIT License. OpenSCAD models (`src/models/`) and pre-built assets (`src/assets/`) may be governed by their own licenses; check each asset before reuse.

---

## Why this matters

This repository demonstrates a simple but powerful idea:

> **Geometry can be built, versioned, reviewed, and published the same way software is.**

Once you remove the GUI dependency, CAD becomes:

* Automatable
* Reviewable
* Reproducible
* Shareable
