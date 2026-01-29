#!/usr/bin/env pwsh
$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $root

if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
  Write-Error "ERROR: docker not found. Install Docker Desktop and try again."
  exit 1
}

if (-not (Test-Path "site/index.html")) {
  Write-Error "ERROR: site/index.html not found. Run ./build.ps1 first."
  exit 1
}

$port = $env:SITE_PORT
if ([string]::IsNullOrWhiteSpace($port)) {
  $port = 8080
} else {
  $port = [int]$port
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
