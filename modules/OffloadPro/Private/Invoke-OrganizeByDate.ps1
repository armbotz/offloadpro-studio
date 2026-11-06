function Invoke-OrganizeByDate {
    param(
        [string]$SourceArchive,
        [string]$OrganizedRoot,
        [switch]$CreateHardlinks
    )
    $safeSrc = Assert-SafeTargetPath -InputPath $SourceArchive -IsMutating $false
    $safeDst = Assert-SafeTargetPath -InputPath $OrganizedRoot -IsMutating $true

    $manifestExts = @('.mhl', '.ale', '.csv', '.html')
    $files = @(Get-ChildItem -LiteralPath $safeSrc -File -Recurse -Force -ErrorAction SilentlyContinue |
        Where-Object {
            $ext = if ($_.Extension) { $_.Extension.ToLowerInvariant() } else { '' }
            (-not ($_.Attributes -band [System.IO.FileAttributes]::ReparsePoint)) -and
            (-not $_.Name.StartsWith('._')) -and
            ($OsJunkNames -notcontains $_.Name.ToLowerInvariant()) -and
            ($manifestExts -notcontains $ext) -and
            ($_.FullName -notmatch '(?i)\\(ascmhl|System Volume Information|\.Spotlight-V100|\.Trashes|\.fseventsd)(\\|$)')
        })

    $groupDateMap = @{}
    foreach ($f in $files) {
        $ext = if ($f.Extension) { $f.Extension.ToLowerInvariant() } else { '' }
        $key = "$($f.DirectoryName)\$($f.BaseName.ToLowerInvariant())"
        $isSidecar = $CreativeSidecarExts -contains $ext
        if (-not $isSidecar) {
            if (-not $groupDateMap.ContainsKey($key) -or $f.LastWriteTimeUtc -lt $groupDateMap[$key]) {
                $groupDateMap[$key] = $f.LastWriteTimeUtc
            }
        }
    }
    foreach ($f in $files) {
        $key = "$($f.DirectoryName)\$($f.BaseName.ToLowerInvariant())"
        if (-not $groupDateMap.ContainsKey($key)) {
            $groupDateMap[$key] = $f.LastWriteTimeUtc
        }
    }

    $organizedCount = 0
    $bucketSet = New-Object 'System.Collections.Generic.HashSet[string]'
    foreach ($f in $files) {
        $key = "$($f.DirectoryName)\$($f.BaseName.ToLowerInvariant())"
        $dt  = $groupDateMap[$key]
        $yearFolder = $dt.ToString('yyyy')
        $dayFolder  = $dt.ToString('yyyy-MM-dd')
        $bucketDir  = Join-Path (Join-Path $safeDst $yearFolder) $dayFolder
        [void]$bucketSet.Add("$yearFolder\$dayFolder")

        if (-not (Test-Path -LiteralPath $bucketDir)) {
            [void][System.IO.Directory]::CreateDirectory($bucketDir)
        }
        $targetFile = Join-Path $bucketDir $f.Name
        if ($CreateHardlinks) {
            if (Test-Path -LiteralPath $targetFile) { Remove-Item -LiteralPath $targetFile -Force }
            [void](New-Item -ItemType HardLink -Path $targetFile -Target $f.FullName)
        } else {
            [System.IO.File]::Copy($f.FullName, $targetFile, $true)
            [System.IO.File]::SetCreationTimeUtc($targetFile, $f.CreationTimeUtc)
            [System.IO.File]::SetLastWriteTimeUtc($targetFile, $f.LastWriteTimeUtc)
        }
        $organizedCount++
    }

    Write-Host "[ORGANIZE BY DATE COMPLETE] Organized $organizedCount files across $($bucketSet.Count) date bucket(s) (Live Photos & .AAE/.XMP sidecars glued)." -ForegroundColor Green
    return [PSCustomObject]@{
        organizedFiles = $organizedCount
        dateBuckets    = $bucketSet.Count
    }
}
