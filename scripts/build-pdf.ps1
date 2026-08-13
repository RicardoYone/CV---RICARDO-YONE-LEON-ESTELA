# Regenerates Ricardo-Yone-Leon-CV.pdf from index.html using headless Chrome
# or Edge, then mirrors the result into dist/.
#
# Run this after ANY content change, or the downloadable PDF goes stale.
#
#   powershell -NoProfile -ExecutionPolicy Bypass -File scripts/build-pdf.ps1

param(
  [int]$Port = 8123,
  [string]$Output = 'Ricardo-Yone-Leon-CV.pdf'
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$pdfPath = Join-Path $root $Output

$browser = @(
  "$env:ProgramFiles\Google\Chrome\Application\chrome.exe"
  "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe"
  "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe"
  "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe"
) | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1

if (-not $browser) {
  throw 'Chrome or Edge is required to render the PDF, and neither was found.'
}

# The page must be served over HTTP: headless printing of file:// URLs skips
# the stylesheet and the web fonts.
$server = Start-Process -FilePath 'powershell' -PassThru -WindowStyle Hidden `
  -ArgumentList '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File',
(Join-Path $PSScriptRoot 'serve.ps1'), '-Port', $Port

try {
  Start-Sleep -Seconds 2
  & $browser --headless=new --disable-gpu --no-pdf-header-footer `
    --virtual-time-budget=8000 "--print-to-pdf=$pdfPath" "http://localhost:$Port/"

  Copy-Item -Force -LiteralPath $pdfPath -Destination (Join-Path $root 'dist')
  Write-Host "PDF written to $pdfPath and mirrored into dist/"
}
finally {
  Stop-Process -Id $server.Id -Force -ErrorAction SilentlyContinue
}
