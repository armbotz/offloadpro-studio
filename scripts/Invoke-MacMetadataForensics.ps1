<#
.SYNOPSIS
    Extracts readable forensic metadata strings from macOS AppleDouble (._*) files and optionally deletes ._* and .DS_Store clutter.
#>
param(
    [Parameter(Mandatory = $false)]
    [string]$TargetPath = "E:\Backups\Camera_Offload_001",

    [Parameter(Mandatory = $false)]
    [string]$ReportPath = "E:\Backups\mac_metadata_findings.txt",

    [Parameter(Mandatory = $false)]
    [switch]$DeleteJunkAfterDump
)

Write-Host "Scanning macOS AppleDouble (._*) files in $TargetPath..." -ForegroundColor Cyan

Get-ChildItem -Path $TargetPath -Filter "._*" -Recurse -Force -File -ErrorAction SilentlyContinue | ForEach-Object {
    $bytes = [System.IO.File]::ReadAllBytes($_.FullName)
    $text  = [System.Text.Encoding]::ASCII.GetString($bytes)
    $matches = [regex]::Matches($text, '[ -~]{6,}') |
               ForEach-Object { $_.Value.Trim() } |
               Where-Object { $_ -notmatch '^(Mac OS X|ATTR|com\.apple\.FinderInfo)$' }
    if ($matches) {
        "=== $($_.FullName) ==="
        $matches | Select-Object -Unique
        ""
    }
} | Out-File -FilePath $ReportPath -Encoding utf8

Write-Host "Saved extracted metadata strings to: $ReportPath" -ForegroundColor Green

$junk = @(Get-ChildItem -Path $TargetPath -Include "._*", ".DS_Store" -Recurse -Force -File -ErrorAction SilentlyContinue)
$mb   = [math]::Round(($junk | Measure-Object Length -Sum).Sum / 1MB, 2)
Write-Host "Found $($junk.Count) macOS sidecar files ($mb MB on NTFS / ~$([math]::Round(($junk.Count * 128) / 1024, 1)) MB on exFAT)." -ForegroundColor Yellow

if ($DeleteJunkAfterDump) {
    $junk | Remove-Item -Force
    $rem = (Get-ChildItem -Path $TargetPath -Include "._*", ".DS_Store" -Recurse -Force -File -ErrorAction SilentlyContinue | Measure-Object).Count
    Write-Host "Cleanup complete. Remaining junk files: $rem" -ForegroundColor Green
} else {
    Write-Host "Dry-Run only. Re-run with -DeleteJunkAfterDump to remove all $($junk.Count) files." -ForegroundColor Gray
}
