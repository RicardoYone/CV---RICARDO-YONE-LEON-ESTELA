# Minimal static file server for local preview.
# No Node or Python required - runs on stock Windows PowerShell.
# Keep this file ASCII-only: PowerShell 5.1 reads BOM-less .ps1 as ANSI, and a
# stray multi-byte character breaks the parser.
#
#   powershell -NoProfile -ExecutionPolicy Bypass -File scripts/serve.ps1
#   -> http://localhost:8123/

param(
  [int]$Port = 8123,
  [string]$Root = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = 'Stop'
$prefix = "http://localhost:$Port/"

$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add($prefix)
$listener.Start()
Write-Host "Serving $Root at $prefix  (Ctrl+C to stop)"

$mime = @{
  '.html' = 'text/html; charset=utf-8'
  '.css'  = 'text/css; charset=utf-8'
  '.js'   = 'application/javascript; charset=utf-8'
  '.json' = 'application/json; charset=utf-8'
  '.pdf'  = 'application/pdf'
  '.jpg'  = 'image/jpeg'
  '.jpeg' = 'image/jpeg'
  '.png'  = 'image/png'
  '.svg'  = 'image/svg+xml'
  '.ico'  = 'image/x-icon'
  '.webp' = 'image/webp'
}

while ($listener.IsListening) {
  $ctx = $listener.GetContext()
  try {
    $path = [System.Uri]::UnescapeDataString($ctx.Request.Url.AbsolutePath)
    if ($path -eq '/') { $path = '/index.html' }
    $file = Join-Path $Root ($path.TrimStart('/') -replace '/', '\')

    if (Test-Path -LiteralPath $file -PathType Leaf) {
      $ext = [System.IO.Path]::GetExtension($file).ToLower()
      $ct = $mime[$ext]
      if (-not $ct) { $ct = 'application/octet-stream' }
      $bytes = [System.IO.File]::ReadAllBytes($file)
      $ctx.Response.ContentType = $ct
      $ctx.Response.ContentLength64 = $bytes.Length
      $ctx.Response.OutputStream.Write($bytes, 0, $bytes.Length)
    }
    else {
      $ctx.Response.StatusCode = 404
    }
  }
  catch {
    $ctx.Response.StatusCode = 500
  }
  finally {
    $ctx.Response.Close()
  }
}
