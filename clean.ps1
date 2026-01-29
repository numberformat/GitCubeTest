#!/usr/bin/env pwsh
$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $root

if (Test-Path "site") {
  Remove-Item -Recurse -Force "site"
  Write-Host "Removed ./site"
} else {
  Write-Host "No ./site directory to remove"
}
