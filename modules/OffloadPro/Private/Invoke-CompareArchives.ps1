function Invoke-CompareArchives {
    param([string]$ArchiveA, [string]$ArchiveB)
    $scanA = Invoke-PreflightScan -ScanPath $ArchiveA
    $scanB = Invoke-PreflightScan -ScanPath $ArchiveB
    $exactParity = ($scanA.merkleStructureRoot -eq $scanB.merkleStructureRoot) -and ($null -ne $scanA.merkleStructureRoot)
    $color = if ($exactParity) { 'Green' } else { 'Yellow' }
    Write-Host "================================================================" -ForegroundColor Cyan
    Write-Host "OffloadPro v4.1 Cross-Archive Merkle & Parity Comparator" -ForegroundColor Cyan
    Write-Host "================================================================" -ForegroundColor Cyan
    Write-Host "Archive A Real Files : $($scanA.realFilesCount) ($([Math]::Round($scanA.realFilesBytes / 1GB, 3)) GB) | Merkle: $($scanA.merkleStructureRoot)"
    Write-Host "Archive B Real Files : $($scanB.realFilesCount) ($([Math]::Round($scanB.realFilesBytes / 1GB, 3)) GB) | Merkle: $($scanB.merkleStructureRoot)"
    Write-Host "100% Merkle Parity   : $exactParity" -ForegroundColor $color
    return [PSCustomObject]@{
        archiveACount = $scanA.realFilesCount
        archiveBCount = $scanB.realFilesCount
        exactParity   = $exactParity
    }
}
