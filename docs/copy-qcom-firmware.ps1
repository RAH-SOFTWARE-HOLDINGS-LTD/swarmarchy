#requires -Version 5
<#
.SYNOPSIS
  Collect the Qualcomm firmware Linux needs (*.mbn, *.jsn, *dtbs.elf) from the Windows
  DriverStore onto a USB stick, for bringing up Linux on a Snapdragon X Elite
  (Lenovo Yoga Slim 7x / x1e80100).

.DESCRIPTION
  Implements docs/05-install-on-yoga.md, Step 0's "copy out the Qualcomm firmware" bullet.
  Recursively scans C:\Windows\System32\DriverStore\FileRepository\ for the firmware and
  copies it to <Destination>\qcom-firmware\, PRESERVING each file's source subfolder so
  same-named blobs (e.g. adsp.mbn) from different driver packages don't overwrite each other.
  Also writes MANIFEST.csv listing every file and its original path.

  Run from an ELEVATED PowerShell -- some DriverStore subtrees are ACL'd and are silently
  skipped otherwise.

  NOTE: this only *collects* the files. Placing them under /lib/firmware/qcom/... on Linux
  is device-specific -- follow Step 1 (joske's gist + kuruczgy's x1e-nixos-config) for the
  exact target layout.

.PARAMETER Destination
  Target root, typically your USB drive letter, e.g. E:\  -- a 'qcom-firmware' folder is
  created underneath it.

.PARAMETER Source
  DriverStore FileRepository to scan. Defaults to the live system's.

.EXAMPLE
  # from an elevated PowerShell:
  .\copy-qcom-firmware.ps1 -Destination E:\
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$Destination,

    [string]$Source = "$env:SystemRoot\System32\DriverStore\FileRepository"
)

$ErrorActionPreference = 'Stop'

# Files the Step 1 guide calls for. NOTE: the guide says "dtbs.elf", but on a real X Elite
# DriverStore the files are actually named adsp_dtbs.elf / cdsp_dtbs.elf -- so match *dtbs.elf,
# not the literal 'dtbs.elf' (which matches nothing).
$patterns = @('*.mbn', '*.jsn', '*dtbs.elf')

# --- sanity checks ---
if (-not (Test-Path -LiteralPath $Source)) { throw "Source not found: $Source" }
if (-not (Test-Path -LiteralPath $Destination)) {
    throw "Destination not found: $Destination  (is the USB plugged in and lettered? see docs/05 Troubleshooting)"
}

$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()
           ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Warning "Not running elevated -- some DriverStore folders may be unreadable. Re-run from an admin PowerShell if files look missing."
}

$Source   = (Resolve-Path -LiteralPath $Source).Path.TrimEnd('\')
$destRoot = Join-Path $Destination 'qcom-firmware'
New-Item -ItemType Directory -Force -Path $destRoot | Out-Null

Write-Host "Scanning $Source ..." -ForegroundColor Cyan

# One recurse pass per pattern; SilentlyContinue so ACL-blocked folders don't abort the run.
$found = foreach ($pat in $patterns) {
    Get-ChildItem -LiteralPath $Source -Recurse -File -Filter $pat -ErrorAction SilentlyContinue
}
$found = $found | Sort-Object FullName -Unique

if (-not $found) {
    Write-Warning "No *.mbn / *.jsn / dtbs.elf found under $Source. Wrong machine, or not elevated."
    return
}

# --- copy, preserving relative structure (provenance + no name collisions) ---
$copied = 0; $failed = 0; $bytes = 0
foreach ($f in $found) {
    $rel    = $f.FullName.Substring($Source.Length).TrimStart('\')
    $target = Join-Path $destRoot $rel
    try {
        New-Item -ItemType Directory -Force -Path (Split-Path $target) | Out-Null
        # \\?\ prefix dodges the 260-char MAX_PATH limit (DriverStore paths are long).
        Copy-Item -LiteralPath $f.FullName -Destination "\\?\$target" -Force
        $copied++; $bytes += $f.Length
    } catch {
        Write-Warning "Failed: $($f.FullName) -> $_"
        $failed++
    }
}

# --- manifest + summary ---
$found |
    Select-Object @{n='Ext';e={$_.Extension.ToLower()}}, Name,
                  @{n='SizeKB';e={[math]::Round($_.Length/1KB,1)}}, FullName |
    Sort-Object Ext, Name |
    Export-Csv -NoTypeInformation -Path (Join-Path $destRoot 'MANIFEST.csv')

Write-Host ""
Write-Host ("Copied {0} file(s), {1} MB -> {2}" -f $copied, [math]::Round($bytes/1MB,1), $destRoot) -ForegroundColor Green
if ($failed) { Write-Host ("  {0} file(s) failed to copy (see warnings above)" -f $failed) -ForegroundColor Yellow }
$found | Group-Object { $_.Extension.ToLower() } | Sort-Object Name |
    ForEach-Object { Write-Host ("  {0,-6} {1}" -f $_.Name, $_.Count) }
Write-Host ("Manifest: {0}" -f (Join-Path $destRoot 'MANIFEST.csv')) -ForegroundColor DarkGray
Write-Host ""
Write-Host "Next: on Linux these go under /lib/firmware/qcom/... -- see docs/05 Step 1 for the exact layout." -ForegroundColor DarkGray
