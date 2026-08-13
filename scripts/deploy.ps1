# Full publish pipeline for the CV site.
#
# Runs every step in the required order and refuses to publish when an
# invariant is broken. Read docs/DEPLOY.md before changing anything here.
#
#   powershell -NoProfile -ExecutionPolicy Bypass -File scripts/deploy.ps1 -Message "fix(cv): update role dates"
#
# Flags:
#   -SkipPush     Build, verify and commit, but do not push.
#   -DryRun       Build and verify only. Nothing is committed.

param(
  [string]$Message,
  [switch]$SkipPush,
  [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

$failures = @()

function Step($n, $text) { Write-Host "`n[$n] $text" -ForegroundColor Cyan }
function Ok($text) { Write-Host "    OK  $text" -ForegroundColor Green }
function Bad($text) { Write-Host "    !!  $text" -ForegroundColor Red; $script:failures += $text }

# ---------------------------------------------------------------------------
# 1. Source-of-truth check
# ---------------------------------------------------------------------------

Step 1 'Checking the source of truth'

foreach ($f in @('index.html', 'styles.css', 'Foto perfil.jpg', 'netlify.toml')) {
  if (Test-Path -LiteralPath (Join-Path $root $f)) { Ok "$f present at repo root" }
  else { Bad "$f is missing from the repo root" }
}

$rootHtml = Get-Content -LiteralPath (Join-Path $root 'index.html') -Raw

# The site is served straight from the repo root. A second copy of the page
# under dist/ has no build step keeping it honest, and drifts.
if (Test-Path -LiteralPath (Join-Path $root 'dist')) {
  Bad 'dist/ exists again -the site publishes from the repo root; delete the duplicate'
}
else { Ok 'No duplicate copy of the site' }

# ---------------------------------------------------------------------------
# 2. Design invariants
# ---------------------------------------------------------------------------

Step 2 'Verifying design invariants'

$css = Get-Content -LiteralPath (Join-Path $root 'styles.css') -Raw

# The owner decided light is the default for every first visit, whatever the
# visitor's OS says. A prefers-color-scheme block silently reverses that.
if ($css -match 'prefers-color-scheme') {
  Bad 'styles.css contains prefers-color-scheme -dark would become the default on dark-mode machines'
}
else { Ok 'Light theme is the unconditional default' }

if ($css -match '@media print') { Ok 'Print stylesheet present' }
else { Bad 'The @media print block is gone -the PDF export will be wrong' }

# break-inside:avoid on a whole section pushes it wholesale to the next page.
if ($css -match '(?s)@media print.*?\.section\s*\{[^}]*break-inside:\s*avoid') {
  Bad 'break-inside:avoid is applied to .section -it will leave half-empty PDF pages'
}
else { Ok 'Page breaks are constrained to individual entries' }

if ($rootHtml -match 'window\.print\(\)') {
  Bad 'index.html still calls window.print() -that opens the print dialog instead of downloading'
}
else { Ok 'The PDF button is a direct download link' }

if ($rootHtml -match 'href="\./Ricardo-Yone-Leon-CV\.pdf"') { Ok 'Download link points at the generated PDF' }
else { Bad 'The download link does not point at Ricardo-Yone-Leon-CV.pdf' }

if ($failures.Count -gt 0) {
  Write-Host "`nAborted before building. Fix the items above.`n" -ForegroundColor Red
  exit 1
}

# ---------------------------------------------------------------------------
# 3. Rebuild the PDF
# ---------------------------------------------------------------------------

Step 3 'Rebuilding the PDF from the current HTML'

$pdf = Join-Path $root 'Ricardo-Yone-Leon-CV.pdf'
$before = if (Test-Path -LiteralPath $pdf) { (Get-Item -LiteralPath $pdf).LastWriteTimeUtc } else { [datetime]::MinValue }

# build-pdf.ps1 throws on failure. Its exit code is not usable: headless Chrome
# returns non-zero on Windows even when it writes the file correctly.
& (Join-Path $PSScriptRoot 'build-pdf.ps1')

if (-not (Test-Path -LiteralPath $pdf)) { throw 'The PDF was not produced' }
if ((Get-Item -LiteralPath $pdf).LastWriteTimeUtc -le $before) { throw 'The PDF was not refreshed' }

$pdfSize = (Get-Item -LiteralPath $pdf).Length
if ($pdfSize -lt 50kb) { Bad "The PDF is only $pdfSize bytes -the stylesheet or fonts probably did not load" }
else { Ok ("PDF rebuilt, {0:N0} KB" -f ($pdfSize / 1kb)) }

# GetEncoding(28591) is ISO-8859-1. Encoding::Latin1 exists only on .NET Core,
# and this script has to run on the PowerShell 5.1 that ships with Windows.
$raw = [System.Text.Encoding]::GetEncoding(28591).GetString([System.IO.File]::ReadAllBytes($pdf))
if ($raw -match '/Count\s+(\d+)') {
  $pages = [int]$Matches[1]
  Ok "PDF page count: $pages"
  if ($pages -gt 3) { Bad "The PDF grew to $pages pages -expected 2" }
}

# ---------------------------------------------------------------------------
# 4. Asset references
# ---------------------------------------------------------------------------

Step 4 'Checking asset references'

# Every asset the page points at must exist, or it 404s once deployed.
$refs = [regex]::Matches($rootHtml, '(?:src|href)="\./([^"]+)"') |
ForEach-Object { [System.Uri]::UnescapeDataString($_.Groups[1].Value) } |
Select-Object -Unique

foreach ($ref in $refs) {
  if (Test-Path -LiteralPath (Join-Path $root $ref)) { Ok "$ref resolves" }
  else { Bad "index.html points at $ref, which does not exist" }
}

if ($failures.Count -gt 0) {
  Write-Host "`nBuild finished with problems. Nothing was committed.`n" -ForegroundColor Red
  exit 1
}

if ($DryRun) {
  Write-Host "`nDry run complete. Everything built and verified; nothing committed.`n" -ForegroundColor Green
  exit 0
}

# ---------------------------------------------------------------------------
# 5. Commit
# ---------------------------------------------------------------------------

Step 5 'Committing'

git add -A
if ($LASTEXITCODE -ne 0) { throw 'git add failed' }

$staged = git diff --cached --name-only
if (-not $staged) {
  Write-Host '    Nothing to commit; the working tree already matches HEAD.' -ForegroundColor DarkYellow
}
else {
  if (-not $Message) {
    $Message = 'chore(cv): rebuild PDF and sync dist'
    Write-Host "    No -Message given, using: $Message" -ForegroundColor DarkYellow
  }

  # Conventional commits, and never any AI attribution.
  git commit -q -m $Message
  if ($LASTEXITCODE -ne 0) { throw 'git commit failed' }
  Ok "Committed: $Message"
}

# ---------------------------------------------------------------------------
# 6. Push -Netlify deploys from origin/main
# ---------------------------------------------------------------------------

if ($SkipPush) {
  Write-Host "`nSkipping push as requested. Run 'git push origin main' when ready.`n" -ForegroundColor DarkYellow
  exit 0
}

Step 6 'Pushing to origin/main'

git push origin main
if ($LASTEXITCODE -ne 0) {
  Write-Host @"

    The push failed.

    The usual cause on this machine is Git Credential Manager: it needs to
    open its sign-in window, which it cannot do from a non-interactive shell
    such as an AI agent's. The commit is safe in your local history.

    Finish the publish from your own terminal:

        git push origin main

"@ -ForegroundColor Yellow
  exit 1
}

Ok 'Pushed. Netlify builds from origin/main and will pick this up automatically.'
Write-Host "`nPublished.`n" -ForegroundColor Green
