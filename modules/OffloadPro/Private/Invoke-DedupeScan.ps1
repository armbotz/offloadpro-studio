# Systems Design Professor Scalability Engine: Two-Stage O(1) Size-Pre-Filter + Multi-Threaded Cryptographic Deduplication
function Invoke-DedupeScan {
    param(
        [string]$ArchivePath,
        [string]$HashAlgorithm = 'SHA256',
        [int]$MaxThreads = 6
    )
    $safeArchive = Assert-SafeTargetPath -InputPath $ArchivePath -IsMutating $false
    $files = @(Get-ChildItem -LiteralPath $safeArchive -File -Recurse -Force -ErrorAction SilentlyContinue |
        Where-Object {
            -not ($_.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -and
            -not $_.Name.StartsWith('._') -and
            ($OsJunkNames -notcontains $_.Name.ToLowerInvariant()) -and
            $_.FullName -notmatch '(?i)\\(System Volume Information|\.Spotlight-V100|\.Trashes|\.fseventsd)(\\|$)'
        })

    # Stage 1: Group by exact byte length (eliminates all unique-size files with zero disk I/O)
    $sizeGroups = @{}
    foreach ($f in $files) {
        if ($f.Length -le 0) { continue }
        if (-not $sizeGroups.ContainsKey($f.Length)) {
            $sizeGroups[$f.Length] = New-Object 'System.Collections.Generic.List[System.IO.FileInfo]'
        }
        $sizeGroups[$f.Length].Add($f)
    }

    $candidates = New-Object 'System.Collections.Generic.List[System.IO.FileInfo]'
    foreach ($grp in $sizeGroups.Values) {
        if ($grp.Count -gt 1) {
            foreach ($item in $grp) { $candidates.Add($item) }
        }
    }

    # Stage 2: Multi-threaded cryptographic hash only on same-size candidates
    $pool = [runspacefactory]::CreateRunspacePool(1, $MaxThreads)
    $pool.Open()
    $jobs = New-Object 'System.Collections.Generic.List[object]'
    $sbHash = {
        param($fullPath, $len, $algo)
        $hasher = switch ($algo.ToUpperInvariant()) {
            'MD5'   { [System.Security.Cryptography.MD5]::Create() }
            'SHA1'  { [System.Security.Cryptography.SHA1]::Create() }
            default { [System.Security.Cryptography.SHA256]::Create() }
        }
        $s = [System.IO.File]::Open($fullPath, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::Read)
        try {
            $h = [System.BitConverter]::ToString($hasher.ComputeHash($s)).Replace('-', '')
            return [PSCustomObject]@{ Length = $len; Hash = $h }
        } finally {
            $s.Dispose()
            $hasher.Dispose()
        }
    }

    foreach ($c in $candidates) {
        $ps = [powershell]::Create().AddScript($sbHash).AddArgument($c.FullName).AddArgument($c.Length).AddArgument($HashAlgorithm)
        $ps.RunspacePool = $pool
        $jobs.Add([PSCustomObject]@{ Pipe = $ps; Handle = $ps.BeginInvoke() })
    }

    $hashTallies = @{}
    $hashSizes   = @{}
    foreach ($j in $jobs) {
        $r = $j.Pipe.EndInvoke($j.Handle) | Select-Object -First 1
        $j.Pipe.Dispose()
        if ($r) {
            $key = "$($r.Length):$($r.Hash)"
            if ($hashTallies.ContainsKey($key)) { $hashTallies[$key]++ } else { $hashTallies[$key] = 1 }
            $hashSizes[$key] = [int64]$r.Length
        }
    }
    $pool.Close(); $pool.Dispose()

    $trueDupFiles = 0
    $reclaimableBytes = [int64]0
    foreach ($kv in $hashTallies.GetEnumerator()) {
        if ($kv.Value -gt 1) {
            $extra = $kv.Value - 1
            $trueDupFiles += $extra
            $reclaimableBytes += ([int64]$extra * $hashSizes[$kv.Key])
        }
    }

    Write-Host "[DEDUPE SCAN COMPLETE] Total Scanned: $($files.Count) | Same-Size Candidates Hashed: $($candidates.Count) | True Hash Duplicates: $trueDupFiles ($([Math]::Round($reclaimableBytes / 1MB, 2)) MB reclaimable)" -ForegroundColor Green
    return [PSCustomObject]@{
        totalScanned       = $files.Count
        sameSizeCandidates = $candidates.Count
        trueDuplicates     = $trueDupFiles
        reclaimableBytes   = $reclaimableBytes
    }
}
