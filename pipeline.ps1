#!/usr/bin/env pwsh
# Copyright (c) 2026 NOAMi (https://noami.us)
$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $root

function Show-Usage {
@"
Usage: ./pipeline.ps1 <command>

Commands:
  build          Build models and site (Dockerized OpenSCAD)
  clean          Remove the generated ./site directory
  run            Serve the site locally via nginx
  create-github  Create a GitHub repo (runs in container)
  help           Show this help
"@ | Write-Host
}

function Ensure-Docker {
  if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    Write-Error "ERROR: docker not found. Install Docker Desktop and try again."
    exit 1
  }
}

function Ensure-GitReady {
  if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Error "ERROR: git not found. Install git to initialize the repo."
    exit 1
  }
  if (-not (& git rev-parse --is-inside-work-tree 2>$null)) {
    if (-not (& git config --get user.name 2>$null)) {
      $name = Read-Host "Git user.name"
      & git config user.name $name | Out-Null
    }
    if (-not (& git config --get user.email 2>$null)) {
      $email = Read-Host "Git user.email"
      & git config user.email $email | Out-Null
    }
    & git init -b main | Out-Null
  }
  if (-not (& git rev-parse --verify HEAD 2>$null)) {
    & git add . | Out-Null
    & git commit -m "Initial commit" | Out-Null
  } else {
    $status = & git status --porcelain
    if (-not [string]::IsNullOrWhiteSpace($status)) {
      & git add . | Out-Null
      & git commit -m "Prepare for GitHub" | Out-Null
    }
  }
}

function Configure-Remote([string]$full) {
  $url = "https://github.com/$full.git"
  $remote = "origin"
  $hasOrigin = $false
  try {
    & git remote get-url origin | Out-Null
    $hasOrigin = $true
  } catch { }

  if ($hasOrigin) {
    Write-Host "Existing git remote 'origin' detected."
    Write-Host "Choose an option:"
    Write-Host "1) Add new remote (keep existing origin)"
    Write-Host "2) Replace origin with the new GitHub repo"
    Write-Host "3) Skip remote setup"
    $choice = Read-Host "Select 1/2/3"
    switch ($choice) {
      "1" {
        $remote = Read-Host "New remote name (default: github)"
        if ([string]::IsNullOrWhiteSpace($remote)) { $remote = "github" }
        & git remote add $remote $url | Out-Null
      }
      "2" {
        & git remote remove origin | Out-Null
        & git remote add origin $url | Out-Null
        $remote = "origin"
      }
      "3" { return }
      default {
        Write-Host "Invalid choice. Skipping remote setup."
        return
      }
    }
  } else {
    & git remote add origin $url | Out-Null
    $remote = "origin"
  }

  $pushAll = Read-Host "Push all local branches to $remote? (y/n)"
  if ($pushAll -eq "y" -or $pushAll -eq "Y" -or [string]::IsNullOrWhiteSpace($pushAll)) {
    & git push --all $remote
    return
  }
  $push = Read-Host "Push current branch to $remote? (y/n)"
  if ($push -eq "y" -or $push -eq "Y") {
    $branch = (& git rev-parse --abbrev-ref HEAD).Trim()
    & git push -u $remote $branch
  }
}

function Get-DockerImage {
  if (-not [string]::IsNullOrWhiteSpace($env:OPENSCAD_DOCKER_IMAGE)) {
    return $env:OPENSCAD_DOCKER_IMAGE
  }
  return "scadpipeline:latest"
}

function Ensure-DockerImage {
  $image = Get-DockerImage
  if ($image -eq "scadpipeline:latest") {
    $hasImage = $false
    try {
      & docker image inspect $image | Out-Null
      $hasImage = $true
    } catch { }
    if (-not $hasImage) {
      if (-not (Test-Path "Dockerfile")) {
        Write-Error "ERROR: Dockerfile not found; cannot build $image."
        exit 1
      }
      Write-Host "Building Docker image $image..."
      if (-not [string]::IsNullOrWhiteSpace($env:OPENSCAD_DOCKER_PLATFORM)) {
        & docker build --platform $env:OPENSCAD_DOCKER_PLATFORM -t $image .
      } else {
        & docker build -t $image .
      }
    }
  }
}

function Get-PlatformArgs {
  $platform = $env:OPENSCAD_DOCKER_PLATFORM
  if ([string]::IsNullOrWhiteSpace($platform)) {
    if ($IsMacOS) {
      $arch = (& uname -m).Trim()
      if ($arch -eq "arm64" -or $arch -eq "aarch64") {
        $platform = "linux/amd64"
      }
    }
  }
  if (-not [string]::IsNullOrWhiteSpace($platform)) {
    return @("--platform", $platform)
  }
  return @()
}

function Invoke-Build {
  Ensure-Docker
  Ensure-DockerImage
  $image = Get-DockerImage
  $platformArgs = Get-PlatformArgs
  $mount = "$(Get-Location):/workspace"
  $userArgs = @()
  if (-not $IsWindows) {
    $uid = & id -u
    $gid = & id -g
    $userArgs = @("--user", "$uid:$gid")
  }
  & docker run --rm @userArgs @platformArgs `
    -v $mount `
    -w /workspace `
    $image `
    bash /workspace/scripts/docker-build.sh
}

function Invoke-Clean {
  if (Test-Path "site") {
    Remove-Item -Recurse -Force "site"
    Write-Host "Removed ./site"
  } else {
    Write-Host "No ./site directory to remove"
  }
}

function Test-PortAvailable([int]$p) {
  try {
    $listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, $p)
    $listener.Start()
    $listener.Stop()
    return $true
  } catch {
    return $false
  }
}

function Invoke-Run {
  Ensure-Docker
  if (-not (Test-Path "site/index.html")) {
    Write-Error "ERROR: site/index.html not found. Run ./pipeline.ps1 build first."
    exit 1
  }

  $port = $env:SITE_PORT
  if ([string]::IsNullOrWhiteSpace($port)) {
    $port = 8080
  } else {
    $port = [int]$port
  }

  if (-not (Test-PortAvailable $port)) {
    $startPort = $port
    for ($i = 0; $i -lt 20; $i++) {
      $port++
      if (Test-PortAvailable $port) { break }
    }
    if ($port -eq $startPort) {
      Write-Error "ERROR: Port $startPort is in use and no free port found nearby."
      exit 1
    }
  }

  $url = "http://localhost:$port"
  $logFile = Join-Path $env:TEMP "scadpipeline-site.log"

  $proc = Start-Process -FilePath "docker" -ArgumentList @(
    "run","--rm",
    "-p","$port:80",
    "-v","$(Get-Location)/site:/usr/share/nginx/html:ro",
    "nginx:alpine"
  ) -NoNewWindow -PassThru -RedirectStandardOutput $logFile -RedirectStandardError $logFile

  Start-Sleep -Seconds 1

  Write-Host "Serving site at $url"
  Write-Host "Press Ctrl+C to stop."
  Write-Host "(nginx logs in $logFile)"

  Wait-Process -Id $proc.Id
}

$cmd = if ($args.Count -gt 0) { $args[0] } else { "help" }
$rest = if ($args.Count -gt 1) { $args[1..($args.Count - 1)] } else { @() }

switch ($cmd) {
  "build" {
    Invoke-Build @rest
  }
  "clean" {
    Invoke-Clean @rest
  }
  "run" {
    Invoke-Run @rest
  }
  "create-github" {
    Ensure-GitReady
    Ensure-Docker
    Ensure-DockerImage
    if (-not (Test-Path "$HOME/.scadpipeline")) {
      New-Item -ItemType File -Path "$HOME/.scadpipeline" -Force | Out-Null
    }
    $tokenFile = (Resolve-Path "$HOME/.scadpipeline").Path
    $image = Get-DockerImage
    $platformArgs = Get-PlatformArgs
    $mount = "$(Get-Location):/workspace"
    $userArgs = @("--user","0:0")
    $ttyArgs = @()
    if ([Environment]::UserInteractive -and -not $env:CI) {
      $ttyArgs = @("-it")
    }

    & docker run --rm @ttyArgs @userArgs @platformArgs `
      -v "$tokenFile:/root/.scadpipeline" `
      -v $mount `
      -w /workspace `
      $image `
      bash /workspace/scripts/gh-repo-pages.sh create
    $repoFile = Join-Path (Get-Location) ".scadpipeline_repo"
    if (Test-Path $repoFile) {
      $repo = (Get-Content $repoFile -Raw).Trim()
      if (-not [string]::IsNullOrWhiteSpace($repo)) {
        Configure-Remote $repo
      } else {
        Write-Host "WARN: No repo name returned from GitHub setup."
      }
      Remove-Item $repoFile -Force
    } else {
      Write-Host "WARN: Repo info file not found. Skipping remote setup."
    }
  }
  "help" { Show-Usage }
  "-h" { Show-Usage }
  "--help" { Show-Usage }
  default {
    Write-Error "Unknown command: $cmd"
    Show-Usage
    exit 1
  }
}
