function Invoke-VerifyMhlLedger {
    param(
        [string]$ArchivePath,
        [string]$ExplicitMhlPath,
        [int]$MaxThreads = 6
    )
    $safeArchive = Assert-SafeTargetPath -InputPath $ArchivePath -IsMutating $false
    $resolvedMhl = if (-not [string]::IsNullOrWhiteSpace($ExplicitMhlPath)) {
        $ExplicitMhlPath
    } else {
        $folderName = Split-Path -Leaf $safeArchive
        $parentDir  = Split-Path -Parent $safeArchive
        Join-Path $parentDir "$folderName.mhl"
    }

    if (-not (Test-Path -LiteralPath $resolvedMhl)) {
        throw "MHL ledger file not found at: $resolvedMhl. Run -Action Certificate first to seal the roll."
    }

    [xml]$xmlDoc = Get-Content -LiteralPath $resolvedMhl -Raw -Encoding UTF8
    $nodes = @($xmlDoc.hashlist.hash)
    Write-Host "================================================================" -ForegroundColor Cyan
    Write-Host "OffloadPro v4.0 Vault & Bitrot MHL Verifier -- Entries: $($nodes.Count)" -ForegroundColor Cyan
    Write-Host "================================================================" -ForegroundColor Cyan

    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $pool = [runspacefactory]::CreateRunspacePool(1, $MaxThreads)
    $pool.Open()
    $jobs = New-Object 'System.Collections.Generic.List[object]'

    $sbVerify = {
        param($rootDir, $relFile, $expectedSize, $algo, $expectedHash)
        $full = Join-Path $rootDir $relFile
        if (-not (Test-Path -LiteralPath $full)) {
            return 'MISSING'
        }
        $fi = Get-Item -LiteralPath $full -Force
        if ($fi.Length -ne $expectedSize) {
            return 'SIZE_MISMATCH'
        }
        $hasher = switch ($algo.ToUpperInvariant()) {
            'MD5'   { [System.Security.Cryptography.MD5]::Create() }
            'SHA1'  { [System.Security.Cryptography.SHA1]::Create() }
            default { [System.Security.Cryptography.SHA256]::Create() }
        }
        $s = [System.IO.File]::Open($full, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::Read)
        try {
            $actual = [System.BitConverter]::ToString($hasher.ComputeHash($s)).Replace('-', '')
            if ($actual -ne $expectedHash.ToUpperInvariant()) {
                return 'HASH_MISMATCH'
            }
            return 'OK'
        } finally {
            $s.Dispose()
            $hasher.Dispose()
        }
    }

    foreach ($n in $nodes) {
        $relFile = [string]$n.file
        $expSize = [int64]$n.size
        $algo = 'SHA256'; $expHash = ''
        if ($n.sha256) { $algo = 'SHA256'; $expHash = [string]$n.sha256 }
        elseif ($n.md5) { $algo = 'MD5'; $expHash = [string]$n.md5 }
        elseif ($n.sha1) { $algo = 'SHA1'; $expHash = [string]$n.sha1 }

        $ps = [powershell]::Create().AddScript($sbVerify).AddArgument($safeArchive).AddArgument($relFile).AddArgument($expSize).AddArgument($algo).AddArgument($expHash)
        $ps.RunspacePool = $pool
        $jobs.Add([PSCustomObject]@{ Pipe = $ps; Handle = $ps.BeginInvoke() })
    }

    $okCount = 0; $missingCount = 0; $sizeMismatchCount = 0; $bitrotCount = 0
    foreach ($j in $jobs) {
        $status = $j.Pipe.EndInvoke($j.Handle) | Select-Object -First 1
        $j.Pipe.Dispose()
        switch ($status) {
            'OK'            { $okCount++ }
            'MISSING'       { $missingCount++ }
            'SIZE_MISMATCH' { $sizeMismatchCount++ }
            'HASH_MISMATCH' { $bitrotCount++ }
        }
    }
    $pool.Close(); $pool.Dispose(); $sw.Stop()

    $totalFailures = $missingCount + $sizeMismatchCount + $bitrotCount
    $color = if ($totalFailures -eq 0) { 'Green' } else { 'Red' }
    Write-Host "[MHL BITROT AUDIT COMPLETE] $([Math]::Round($sw.Elapsed.TotalSeconds, 1))s | Verified OK: $okCount/$($nodes.Count) | Missing: $missingCount | Size Drift: $sizeMismatchCount | Bitrot Hash Errors: $bitrotCount" -ForegroundColor $color

    if ($totalFailures -gt 0) {
        Write-OffloadEventLog -EventId 4001 -EntryType 'Error' -Message "OffloadPro MHL Bitrot Failure: Missing=$missingCount, SizeDrift=$sizeMismatchCount, Bitrot=$bitrotCount"
    } else {
        Write-OffloadEventLog -EventId 1000 -EntryType 'Information' -Message "OffloadPro MHL Bitrot Verified: $okCount/$($nodes.Count) files intact."
    }
    return [PSCustomObject]@{
        totalSealed   = $nodes.Count
        verifiedOk    = $okCount
        missingCount  = $missingCount
        sizeDrift     = $sizeMismatchCount
        bitrotCount   = $bitrotCount
        totalFailures = $totalFailures
    }
}
