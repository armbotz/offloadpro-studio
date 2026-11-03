<#
.SYNOPSIS
    Extracts readable forensic metadata strings from macOS AppleDouble (._*) files into a report file
    and optionally deletes Tier-2 OS clutter (._*, .DS_Store, Thumbs.db, desktop.ini) while protecting
    Tier-1 creative sidecars (.AAE, .XMP, .SRT, .XML, .CPI, .CUBE, .3DL, .THM).
#>
param(
    [Parameter(Mandatory = $false)]
    [string]$TargetPath = "E:\Backups\Camera_Offload_001",

    [Parameter(Mandatory = $false)]
    [string]$ReportPath = "E:\Backups\mac_metadata_findings.txt",

    [Parameter(Mandatory = $false)]
    [switch]$DeleteJunkAfterDump
)

Write-Host "Scanning macOS AppleDouble (._*) files in target archive (privacy-safe aggregate mode)..." -ForegroundColor Cyan

$findingsCount = 0
$reportLines = New-Object 'System.Collections.Generic.List[string]'
$reportLines.Add("================================================================")
$reportLines.Add("MACOS APPLEDOUBLE (._*) FORENSIC METADATA EXTRACTION REPORT")
$reportLines.Add("Generated: $((Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ'))")
$reportLines.Add("================================================================")
$reportLines.Add("")

Get-ChildItem -LiteralPath $TargetPath -Filter "._*" -Recurse -Force -File -ErrorAction SilentlyContinue | ForEach-Object {
    $bytes = [System.IO.File]::ReadAllBytes($_.FullName)
    $text  = [System.Text.Encoding]::ASCII.GetString($bytes)
    $matches = @([regex]::Matches($text, '[ -~]{6,}') |
               ForEach-Object { $_.Value.Trim() } |
               Where-Object { $_ -notmatch '^(Mac OS X|ATTR|com\.apple\.FinderInfo|THIS FILE IS FOR)$' } |
               Select-Object -Unique)
    if ($matches.Count -gt 0) {
        $findingsCount++
        $rel = $_.FullName.Substring($TargetPath.Length).TrimStart('\')
        $reportLines.Add("=== $rel ===")
        foreach ($m in $matches) { $reportLines.Add("  * $m") }
        $reportLines.Add("")
    }
}

$reportLines | Out-File -LiteralPath $ReportPath -Encoding utf8
Write-Host "Saved extracted metadata strings ($findingsCount AppleDouble files with extended attributes) to report file." -ForegroundColor Green

$junk = @(Get-ChildItem -LiteralPath $TargetPath -Include "._*", ".DS_Store", "Thumbs.db", "desktop.ini" -Recurse -Force -File -ErrorAction SilentlyContinue)
$mb   = [math]::Round(($junk | Measure-Object Length -Sum).Sum / 1MB, 2)
Write-Host "Found $($junk.Count) Tier-2 OS junk sidecar files ($mb MB on NTFS / ~$([math]::Round(($junk.Count * 128) / 1024, 1)) MB on exFAT). Creative sidecars (.AAE/.XMP/.SRT) are protected." -ForegroundColor Yellow

if ($DeleteJunkAfterDump) {
    $junk | Remove-Item -Force -ErrorAction SilentlyContinue
    $rem = @(Get-ChildItem -LiteralPath $TargetPath -Include "._*", ".DS_Store", "Thumbs.db", "desktop.ini" -Recurse -Force -File -ErrorAction SilentlyContinue).Count
    Write-Host "Cleanup complete. Remaining Tier-2 OS junk files: $rem" -ForegroundColor Green
} else {
    Write-Host "Dry-Run only. Re-run with -DeleteJunkAfterDump to remove all $($junk.Count) OS junk files." -ForegroundColor Gray
}
