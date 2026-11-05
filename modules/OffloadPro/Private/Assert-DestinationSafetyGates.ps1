function Assert-DestinationSafetyGates {
    param(
        [string[]]$DestinationRoots,
        [object[]]$QueueItems,
        [switch]$AllowRollOverwrite
    )
    $requiredBytes = [int64]0
    foreach ($q in $QueueItems) { $requiredBytes += [int64]$q.File.Length }
    $headroomBytes = [Math]::Max([int64]64MB, [int64]($requiredBytes * 0.05))

    foreach ($dst in $DestinationRoots) {
        $driveRoot = [System.IO.Path]::GetPathRoot($dst)
        if ($driveRoot) {
            $di = New-Object System.IO.DriveInfo($driveRoot)
            if ($di.IsReady) {
                $neededWithHeadroom = $requiredBytes + $headroomBytes
                if ($di.AvailableFreeSpace -lt $neededWithHeadroom) {
                    $freeGB = [Math]::Round($di.AvailableFreeSpace / 1GB, 2)
                    $reqGB  = [Math]::Round($neededWithHeadroom / 1GB, 2)
                    throw "[DIT FREE-SPACE GATE BLOCKED] Drive $driveRoot has $freeGB GB free, but offload requires $reqGB GB (including 5% NTFS safety headroom)."
                }
            }
        }

        if ((Test-Path -LiteralPath $dst) -and (-not $AllowRollOverwrite)) {
            $dstNorm = (Get-Item -LiteralPath $dst -Force).FullName
            $existingFiles = @(Get-ChildItem -LiteralPath $dstNorm -File -Recurse -Force -ErrorAction SilentlyContinue)
            if ($existingFiles.Count -gt 0) {
                $sizeMap = @{}
                foreach ($ef in $existingFiles) {
                    $rel = Get-RelativePathSafe -BasePath $dstNorm -FullPath $ef.FullName
                    $sizeMap[$rel] = $ef.Length
                }
                $collisions = 0
                foreach ($q in $QueueItems) {
                    if ($sizeMap.ContainsKey($q.RelPath) -and $sizeMap[$q.RelPath] -ne $q.File.Length) {
                        $collisions++
                    }
                }
                if ($collisions -gt 0) {
                    throw "[DIT ROLL-COLLISION GUARD BLOCKED] Target folder already contains $collisions file(s) with identical relative paths but different byte sizes (possible Roll A001/A002 mix-up). Use a new folder name or pass -AllowOverwrite."
                }
            }
        }
    }
}
