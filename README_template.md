# Project Title

Short description of the design project.

---

## What this repo contains

- `src/models/` — OpenSCAD source files (top-level only)
- `src/assets/` — Pre-built assets (top-level only)
- `src/images/` — Optional user images (any format, converted to PNG)
- `site/` — Generated viewer output (build artifact)

---

## Build

**macOS / Linux (bash):**
```bash
./pipeline.sh build
```

**Windows (PowerShell 7+):**
```powershell
.\pipeline.ps1 build
```

---

## Viewer

Run the local viewer:

```bash
./pipeline.sh run
```

```powershell
.\pipeline.ps1 run
```

## Upload to Github and enable Pages

Enable GitHub Pages to publish the viewer:

Optional (guided, console-only auth supported):

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

Token scope guidance (classic PAT):
- public repos only: `public_repo`
- private repos: `repo`
- org repos: `admin:org`
Avoid `delete_repo` and `project` unless you explicitly need them.

Optional (guided):

```bash
./pipeline.sh create-github
```

```powershell
.\pipeline.ps1 create-github
```

1. Go to **Settings** → **Pages**
2. **Source**: Deploy from a Branch
3. Select `gh-pages` and `/ (root)`
4. Save and wait for the site to publish

The viewer includes:
- Image browser with thumbnails and 3D toggle (for STL previews)
- README and LICENSE tabs (rendered into the page during build)
- Build date shown under the page title

---

## Releases

Each build on `main` publishes STL assets as a GitHub Release.

---

## Pipeline

This project uses the SCADPipeline build system. See the pipeline README for details and updates: [SCADPipeline README](README_pipeline.md).
