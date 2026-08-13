# Regenerates Ricardo-Yone-Leon-CV.pdf from index.html using headless Chrome
# or Edge.
#
# Run this after ANY content change, or the downloadable PDF goes stale.
#
#   powershell -NoProfile -ExecutionPolicy Bypass -File scripts/build-pdf.ps1
#
# Keep this file ASCII-only: PowerShell 5.1 reads BOM-less .ps1 as ANSI, and a
# stray multi-byte character breaks the parser.

param(
  [int]$Port = 8123,
  [string]$Output = 'Ricardo-Yone-Leon-CV.pdf'
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$pdfPath = Join-Path $root $Output
$url = "http://localhost:$Port/"

function Test-Server {
  try {
    Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 2 | Out-Null
    return $true
  }
  catch { return $false }
}

$browser = @(
  "$env:ProgramFiles\Google\Chrome\Application\chrome.exe"
  "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe"
  "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe"
  "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe"
) | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1

if (-not $browser) {
  throw 'Chrome or Edge is required to render the PDF, and neither was found.'
}

# The page must be served over HTTP: headless printing of a file:// URL skips
# the stylesheet and the web fonts, producing an unstyled PDF.
$server = $null
if (Test-Server) {
  Write-Host "Reusing the server already listening on port $Port"
}
else {
  $server = Start-Process -FilePath 'powershell' -PassThru -WindowStyle Hidden `
    -ArgumentList '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File',
  (Join-Path $PSScriptRoot 'serve.ps1'), '-Port', $Port

  $ready = $false
  foreach ($attempt in 1..20) {
    Start-Sleep -Milliseconds 500
    if (Test-Server) { $ready = $true; break }
  }
  if (-not $ready) { throw "The preview server never came up on port $Port" }
}

try {
  $before = if (Test-Path -LiteralPath $pdfPath) {
    (Get-Item -LiteralPath $pdfPath).LastWriteTimeUtc
  }
  else { [datetime]::MinValue }

  # A dedicated profile directory is mandatory: sharing the default one makes a
  # second headless run bail out against the first run's lock without printing.
  $profileDir = Join-Path ([System.IO.Path]::GetTempPath()) ("cv-pdf-" + [guid]::NewGuid())

  try {
    # Start-Process -Wait, never the call operator. chrome.exe on Windows is a
    # launcher: it spawns the real browser and returns immediately, so `&` lets
    # the script race ahead and inspect the PDF before it has been written.
    $print = Start-Process -FilePath $browser -Wait -PassThru -NoNewWindow -ArgumentList @(
      '--headless=new'
      '--disable-gpu'
      '--no-first-run'
      '--no-default-browser-check'
      '--no-pdf-header-footer'
      '--virtual-time-budget=8000'
      "--user-data-dir=$profileDir"
      "--print-to-pdf=$pdfPath"
      $url
    )
  }
  finally {
    Remove-Item -Recurse -Force -LiteralPath $profileDir -ErrorAction SilentlyContinue
  }

  if ($print.ExitCode -ne 0) {
    Write-Host "  browser exited with code $($print.ExitCode); verifying the output anyway"
  }

  if (-not (Test-Path -LiteralPath $pdfPath)) {
    throw "No PDF was produced at $pdfPath"
  }
  if ((Get-Item -LiteralPath $pdfPath).LastWriteTimeUtc -le $before) {
    throw 'The PDF on disk was not refreshed; the browser failed to render the page'
  }

  Write-Host ("PDF written to {0} ({1:N0} KB)" -f $pdfPath, ((Get-Item -LiteralPath $pdfPath).Length / 1kb))
}
finally {
  if ($server) { Stop-Process -Id $server.Id -Force -ErrorAction SilentlyContinue }
}
