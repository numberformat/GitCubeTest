#!/usr/bin/env pwsh
$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $root

$openscad = $env:OPENSCAD_BIN
if ([string]::IsNullOrWhiteSpace($openscad) -or -not (Test-Path $openscad)) {
  $cmd = Get-Command "openscad.exe" -ErrorAction SilentlyContinue
  if ($cmd) {
    $openscad = $cmd.Source
  } elseif (Test-Path "C:\Program Files\OpenSCAD\openscad.exe") {
    $openscad = "C:\Program Files\OpenSCAD\openscad.exe"
  } elseif (Test-Path "C:\Program Files (x86)\OpenSCAD\openscad.exe") {
    $openscad = "C:\Program Files (x86)\OpenSCAD\openscad.exe"
  } else {
    Write-Error "ERROR: OpenSCAD not found. Install OpenSCAD or set OPENSCAD_BIN."
    exit 1
  }
}

New-Item -ItemType Directory -Force -Path "site" | Out-Null
Copy-Item -Force "docs/index.html" "site/index.html"
Copy-Item -Force ".nojekyll" "site/.nojekyll"

$scadFiles = Get-ChildItem -Path "src/models" -Filter "*.scad" -File
if ($scadFiles.Count -eq 0) {
  Write-Error "No .scad files found in src/models."
  exit 1
}

$models = @()
foreach ($file in $scadFiles) {
  $base = [System.IO.Path]::GetFileNameWithoutExtension($file.Name)
  $out = "site/$base.stl"
  & $openscad -o $out $file.FullName
  $models += "$base.stl"
}

$json = "[" + ($models | ForEach-Object { '"' + $_ + '"' }) -join "," + "]"
Set-Content -Path "site/models.json" -Value $json -NoNewline

Write-Host "Build complete. Output in ./site"
