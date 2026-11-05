# Self-Healing 3-2-1 Vault Repair: Repairs bitrot/corrupted files on Primary Archive using verified Mirror copy sealed by .MHL
function Invoke-HealFromMirror {
    param(
        [string]$ArchivePath,
        [string]$MirrorArchivePath,
        [string]$ExplicitMhlPath,
        [int]$MaxThreads = 6
    )
    $safeArchive = Assert-SafeTargetPath -InputPath $ArchivePath -IsMutating $true
    $safeMirror  = Assert-SafeTargetPath -InputPath $MirrorArchivePath -IsMutating $false
    $resolvedMhl = if (-not [string]::IsNullOrWhiteSpace($ExplicitMhlPath)) {
        $ExplicitMhlPath
    } else {
        $folderName = Split-Path -Leaf $safeArchive
        $parentDir  = Split-Path -Parent $safeArchive
        Join-Path $parentDir "$folderName.mhl"
    }

    if (-not (Test-Path -LiteralPath $resolvedMhl)) {
        throw "MHL ledger file not found at: $resolvedMhl. Cannot perform cryptographic self-healing without a sealed .mhl manifest."
    }

    [xml]$xmlDoc = Get-Content -LiteralPath $resolvedMhl -Raw -Encoding UTF8
    $nodes = @($xmlDoc.hashlist.hash)
    Write-Host "================================================================" -ForegroundColor Cyan
    Write-Host "OffloadPro v4.1 Self-Healing Vault Repair -- Entries: $($nodes.Count)" -ForegroundColor Cyan
    Write-Host "================================================================" -ForegroundColor Cyan

    $healthyCount = 0
    $corruptedFound = 0
    $healedCount = 0
    $unhealableCount = 0

    foreach ($n in $nodes) {
        $relFile = [string]$n.file
        $expSize = [int64]$n.size
        $algo = 'SHA256'; $expHash = ''
        if ($n.sha256) { $algo = 'SHA256'; $expHash = ([string]$n.sha256).ToUpperInvariant() }
        elseif ($n.md5) { $algo = 'MD5'; $expHash = ([string]$n.md5).ToUpperInvariant() }
        elseif ($n.sha1) { $algo = 'SHA1'; $expHash = ([string]$n.sha1).ToUpperInvariant() }

        $targetFull = Join-Path $safeArchive $relFile
        $needsHeal  = $false

        if (-not (Test-Path -LiteralPath $targetFull)) {
            $needsHeal = $true
        } else {
            $tfi = Get-Item -LiteralPath $targetFull -Force
            if ($tfi.Length -ne $expSize) {
                $needsHeal = $true
            } else {
                $actualHash = Get-FileChecksumFull -FilePath $targetFull -HashAlgorithm $algo
                if ($actualHash -ne $expHash) {
                    $needsHeal = $true
                }
            }
        }

        if (-not $needsHeal) {
            $healthyCount++
            continue
        }

        $corruptedFound++
        $mirrorFull = Join-Path $safeMirror $relFile
        if (-not (Test-Path -LiteralPath $mirrorFull)) {
            $unhealableCount++
            continue
        }

        $mfi = Get-Item -LiteralPath $mirrorFull -Force
        if ($mfi.Length -ne $expSize) {
            $unhealableCount++
            continue
        }

        $mirrorHash = Get-FileChecksumFull -FilePath $mirrorFull -HashAlgorithm $algo
        if ($mirrorHash -ne $expHash) {
            $unhealableCount++
            continue
        }

        # Mirror file is 100% cryptographically verified against the original .mhl seal -> Atomically repair target
        $repairedHash = Copy-SingleReadMultiWrite -SourceFile $mirrorFull -TargetFiles @($targetFull) -HashAlgorithm $algo
        [System.IO.File]::SetCreationTimeUtc($targetFull, $mfi.CreationTimeUtc)
        [System.IO.File]::SetLastWriteTimeUtc($targetFull, $mfi.LastWriteTimeUtc)
        if ($repairedHash -eq $expHash) {
            $healedCount++
        } else {
            $unhealableCount++
        }
    }

    $color = if ($unhealableCount -eq 0) { 'Green' } else { 'Red' }
    Write-Host "[SELF-HEALING VAULT COMPLETE] Total Sealed: $($nodes.Count) | Healthy: $healthyCount | Corrupted Found: $corruptedFound | Healed From Mirror: $healedCount | Unhealable: $unhealableCount" -ForegroundColor $color

    return [PSCustomObject]@{
        totalSealed     = $nodes.Count
        healthyCount    = $healthyCount
        corruptedFound  = $corruptedFound
        healedCount     = $healedCount
        unhealableCount = $unhealableCount
    }
}
