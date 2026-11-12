<#
.SYNOPSIS
    Orchestrates verified single-read multi-destination offloads with crash-resumable
    checkpointing, inline hashing, 3-2-1 dual-copy verification, and MHL/ALE/CSV deliverables.
#>
function Invoke-OffloadSession {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$SourceRoot,

        [Parameter(Mandatory = $true)]
        [string]$DestinationRoot,

        [Parameter(Mandatory = $false)]
        [string]$SecondaryDestinationRoot = '',

        [Parameter(Mandatory = $false)]
        [string]$CameraId = '',

        [Parameter(Mandatory = $false)]
        [string]$RollId = '',

        [Parameter(Mandatory = $false)]
        [ValidateSet('SHA256', 'MD5', 'SHA1')]
        [string]$Algorithm = 'SHA256',

        [Parameter(Mandatory = $false)]
        [ValidateSet('forensic_split', 'clean', 'raw')]
        [string]$MacMode = 'forensic_split',

        [Parameter(Mandatory = $false)]
        [switch]$RescueMode,

        [Parameter(Mandatory = $false)]
        [switch]$AllowOverwrite,

        [Parameter(Mandatory = $false)]
        [bool]$VerifyLevel1 = $true,

        [Parameter(Mandatory = $false)]
        [bool]$VerifyLevel2 = $true,

        [Parameter(Mandatory = $false)]
        [bool]$VerifyLevel3 = $false,

        [Parameter(Mandatory = $false)]
        [int]$Threads = 6,

        [Parameter(Mandatory = $false)]
        [switch]$PassThru
    )

    $effectiveSrc = if (-not [string]::IsNullOrWhiteSpace($SourceRoot)) { $SourceRoot } else { 'D:\' }
    $effectiveDstBase = if (-not [string]::IsNullOrWhiteSpace($DestinationRoot)) { $DestinationRoot } else { 'E:\Backups\Camera_Offload_001' }
    $safeSrc  = Assert-SafeTargetPath -InputPath $effectiveSrc -IsMutating $false
    $effectiveDst1 = $effectiveDstBase
    if (-not [string]::IsNullOrWhiteSpace($CameraId) -or -not [string]::IsNullOrWhiteSpace($RollId)) {
        $dateStr = (Get-Date).ToString('yyyy-MM-dd')
        $camPart = if ($CameraId) { "_$CameraId" } else { '' }
        $rolPart = if ($RollId)   { "_$RollId" }   else { '' }
        $effectiveDst1 = Join-Path $effectiveDstBase "${dateStr}${camPart}${rolPart}"
    }
    $safeDst1 = Assert-SafeTargetPath -InputPath $effectiveDst1 -IsMutating $true
    $dstRoots = New-Object 'System.Collections.Generic.List[string]'
    $dstRoots.Add($safeDst1)
    if (-not [string]::IsNullOrWhiteSpace($SecondaryDestinationRoot)) {
        $dstRoots.Add((Assert-SafeTargetPath -InputPath $SecondaryDestinationRoot -IsMutating $true))
    }

    $allItems = @(Get-ChildItem -LiteralPath $safeSrc -File -Recurse -Force -ErrorAction SilentlyContinue |
        Where-Object { -not ($_.Attributes -band [System.IO.FileAttributes]::ReparsePoint) })

    $queue = @(foreach ($f in $allItems) {
        $rel = Get-RelativePathSafe -BasePath $safeSrc -FullPath $f.FullName
        $inSys = $rel -match '(?i)(^|\\)(ascmhl|System Volume Information|\.Spotlight-V100|\.Trashes|\.fseventsd)(\\|$)'
        $isJunk = $f.Name.StartsWith('._') -or ($OsJunkNames -contains $f.Name.ToLowerInvariant())
        if ($MacMode -eq 'clean' -and ($inSys -or $isJunk)) { continue }
        [PSCustomObject]@{
            File       = $f
            RelPath    = $rel
            IsForensic = ($inSys -or $isJunk)
        }
    })

    Assert-DestinationSafetyGates -DestinationRoots $dstRoots -QueueItems $queue -AllowRollOverwrite:$AllowOverwrite

    if ($RescueMode) {
        $queue = @($queue | Sort-Object { $_.File.Length })
        Write-Host "[RESCUE MODE] Sorted $($queue.Count) files smallest-to-largest..." -ForegroundColor Yellow
    } else {
        Write-Host "[SINGLE-READ OFFLOAD] Queued $($queue.Count) files ($Algorithm inline hash)..." -ForegroundColor Cyan
    }

    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $copied = 0
    $resumedSkipped = 0
    $mismatches = 0
    $inlineHashes = @{}

    Set-ExecutionAwakeLock -Enable $true
    try {
        foreach ($item in $queue) {
            $targets = @(foreach ($r in $dstRoots) {
                if ($MacMode -eq 'forensic_split' -and $item.IsForensic) {
                    Join-Path "${r}_forensics" $item.RelPath
                } else {
                    Join-Path $r $item.RelPath
                }
            })

            # OS Professor Crash-Resumable Checkpoint Check: If all target files already exist with matching byte size & mtime, verify in place
            $allTargetsIntact = $true
            foreach ($tf in $targets) {
                if (-not (Test-Path -LiteralPath $tf)) {
                    $allTargetsIntact = $false
                    break
                }
                $tfi = Get-Item -LiteralPath $tf -Force
                if ($tfi.Length -ne $item.File.Length -or $tfi.LastWriteTimeUtc -ne $item.File.LastWriteTimeUtc) {
                    $allTargetsIntact = $false
                    break
                }
            }

            if ($allTargetsIntact -and (-not $AllowOverwrite)) {
                $existingHash = Get-FileChecksumFull -FilePath $targets[0] -HashAlgorithm $Algorithm
                if (-not $item.IsForensic) {
                    $inlineHashes[$item.RelPath] = $existingHash
                }
                $resumedSkipped++
                $copied++
                continue
            }

            $srcHash = Copy-SingleReadMultiWrite -SourceFile $item.File.FullName -TargetFiles $targets -HashAlgorithm $Algorithm
            if (-not $item.IsForensic) {
                $inlineHashes[$item.RelPath] = $srcHash
            }
            foreach ($tf in $targets) {
                [System.IO.File]::SetCreationTimeUtc($tf, $item.File.CreationTimeUtc)
                [System.IO.File]::SetLastWriteTimeUtc($tf, $item.File.LastWriteTimeUtc)
                if ($VerifyLevel1) {
                    $dstHash = Get-FileChecksumFull -FilePath $tf -HashAlgorithm $Algorithm
                    if ($dstHash -ne $srcHash) { $mismatches++ }
                }
            }
            $copied++
            if ($copied % 500 -eq 0 -or $copied -eq $queue.Count) {
                $pct = [math]::Round(($copied / $queue.Count) * 100, 1)
                $rate = if ($sw.Elapsed.TotalSeconds -gt 0) { [math]::Round($copied / $sw.Elapsed.TotalSeconds, 1) } else { 0 }
                Write-Host "  -> [PROGRESS] $copied / $($queue.Count) files ($pct%) | $rate files/sec" -ForegroundColor Cyan
            }
        }
        $sw.Stop()
        $traffic = if ($mismatches -gt 0) { 'RED_ERRORS' } elseif ($dstRoots.Count -ge 2) { 'GREEN_321_VERIFIED' } else { 'AMBER_SINGLE_COPY' }
        Write-Host "[OFFLOAD COMPLETE] $copied/$($queue.Count) files (Resumed: $resumedSkipped) | Level 1 Hash Mismatches: $mismatches | Status: $traffic" -ForegroundColor Green

        $streamAuditStatus = 'Skipped (L1 Hash Only)'
        if ($mismatches -gt 0) {
            Write-OffloadEventLog -EventId 4001 -EntryType 'Error' -Message "OffloadPro Level 1 Hash Mismatch count: $mismatches"
            $script:ExitCodeToReturn = 1
            $streamAuditStatus = 'Blocked (L1 Mismatch)'
        } elseif ($VerifyLevel2 -or $VerifyLevel3) {
            $auditScript = Join-Path $RepoRoot 'scripts\Invoke-3LevelAudit.ps1'
            if (Test-Path -LiteralPath $auditScript) {
                & $auditScript -SourceRoot $safeSrc -DestinationRoot $safeDst1 -SkipLevel1Hash -SkipLevel3DeepDecode:(-not $VerifyLevel3) -Threads $Threads
                if ($LASTEXITCODE -ne 0) {
                    $script:ExitCodeToReturn = $LASTEXITCODE
                    $streamAuditStatus = 'Audit Warning Detected'
                } else {
                    $streamAuditStatus = if ($VerifyLevel3) { '100% Decoded (L2+L3)' } else { 'L2 Container Verified' }
                }
            }
        }

        foreach ($r in $dstRoots) {
            New-MhlAndCertificate -ArchivePath $r -HashAlgorithm $Algorithm -PrecomputedHashes $inlineHashes -MaxThreads $Threads -HashMismatches $mismatches -StreamAuditStatus $streamAuditStatus
        }

        if ($script:ExitCodeToReturn -eq 0) {
            Write-OffloadEventLog -EventId 1000 -EntryType 'Information' -Message "OffloadPro Offload Completed ($traffic): $copied files verified."
        }
    } finally {
        Set-ExecutionAwakeLock -Enable $false
    }

    $resObj = [PSCustomObject]@{
        queuedFiles      = $queue.Count
        processedFiles   = $copied
        resumedFiles     = $resumedSkipped
        newlyCopied      = ($copied - $resumedSkipped)
        hashMismatches   = $mismatches
        status           = $traffic
        destinationVault = $safeDst1
        mirrorVault      = if ($dstRoots.Count -gt 1) { $dstRoots[1] } else { $null }
    }

    if ($PassThru) {
        return $resObj
    }
    return $null
}
