function Invoke-PreflightScan {
    param([string]$ScanPath)
    $exists = Test-Path -LiteralPath $ScanPath -ErrorAction SilentlyContinue
    if ($exists) {
        $ScanPath = (Get-Item -LiteralPath $ScanPath -Force).FullName
    }
    $result = [ordered]@{
        targetPath               = $ScanPath
        exists                   = [bool]$exists
        realFilesCount           = 0
        realFilesBytes           = [int64]0
        creativeSidecarsCount    = 0
        creativeSidecarsBytes    = [int64]0
        orphanSidecarsCount      = 0
        livePhotoPairsCount      = 0
        sequenceGapCount         = 0
        spannedClipGroupsCount   = 0
        spanGapWarnings          = @()
        detectedCameraOems       = @()
        oemStructureWarnings     = @()
        sameSizeDuplicateCount   = 0
        sameSizeDuplicateBytes   = [int64]0
        priorMhlMatchedCount     = 0
        macAppleDoubleCount      = 0
        macAppleDoubleBytes      = [int64]0
        dsStoreCount             = 0
        systemForensicFilesCount = 0
        systemForensicBytes      = [int64]0
        zeroByteRealFiles        = 0
        extensions               = [ordered]@{}
        estimatedExfatSlackBytes = [int64]0
        thinkStats               = $null
        merkleStructureRoot      = $null
    }
    if (-not $exists) { return [PSCustomObject]$result }

    $priorLedgerSizes = New-Object 'System.Collections.Generic.HashSet[int64]'
    $parentDir = Split-Path -Parent $ScanPath
    if ($parentDir -and (Test-Path -LiteralPath $parentDir -ErrorAction SilentlyContinue)) {
        Get-ChildItem -LiteralPath $parentDir -Filter '*.mhl' -File -ErrorAction SilentlyContinue | ForEach-Object {
            $rawXml = Get-Content -LiteralPath $_.FullName -Raw -ErrorAction SilentlyContinue
            if ($rawXml) {
                [regex]::Matches($rawXml, '<size>(\d+)</size>') | ForEach-Object {
                    [void]$priorLedgerSizes.Add([int64]$_.Groups[1].Value)
                }
            }
        }
    }

    $realSizes  = New-Object 'System.Collections.Generic.List[int64]'
    $sizeCounts = @{}
    $treeLeaves = New-Object 'System.Collections.Generic.List[string]'
    $dirBaseMap = @{}
    $seqMap     = @{}
    $oemSet     = New-Object 'System.Collections.Generic.HashSet[string]'
    $hasSonyM4Root    = $false
    $hasSonyMediapro  = $false

    $allFiles = @(Get-ChildItem -LiteralPath $ScanPath -File -Recurse -Force -ErrorAction SilentlyContinue |
        Where-Object { -not ($_.Attributes -band [System.IO.FileAttributes]::ReparsePoint) })

    foreach ($f in $allFiles) {
        $rel = Get-RelativePathSafe -BasePath $ScanPath -FullPath $f.FullName
        $relUpper = $rel.Replace('/', '\').ToUpperInvariant()
        $nameLower = $f.Name.ToLowerInvariant()
        $ext = if ($f.Extension) { $f.Extension.ToLowerInvariant() } else { '.noext' }
        $inSys = ($rel -match '(?i)(^|\\)(ascmhl|System Volume Information|\.Spotlight-V100|\.Trashes|\.fseventsd)(\\|$)') -or
                 ($ext -in @('.mhl', '.ale')) -or
                 ($nameLower -match '(_posthouse_manifest\.csv|_offload_certificate\.html)$')

        # Lead DIT Camera-Vendor OEM Folder & Container Fingerprinting
        if ($relUpper.Contains('M4ROOT\CLIP') -or $relUpper.Contains('XDROOT')) {
            $hasSonyM4Root = $true
            [void]$oemSet.Add('Sony XAVC / Cinema Line')
        }
        if ($nameLower -eq 'mediapro.xml') {
            $hasSonyMediapro = $true
        }
        if ($relUpper.Contains('.RDC\') -or $ext -eq '.r3d') {
            [void]$oemSet.Add('RED Digital Cinema (.R3D)')
        }
        if ($ext -eq '.braw') {
            [void]$oemSet.Add('Blackmagic RAW (.BRAW)')
        }
        if ($ext -eq '.ari' -or ($ext -eq '.mxf' -and $relUpper.Contains('ARRI'))) {
            [void]$oemSet.Add('ARRI Alexa / Amira')
        }
        if ($relUpper.Contains('100EOS') -or $ext -eq '.cr3' -or $ext -eq '.cr2' -or $ext -eq '.crm') {
            [void]$oemSet.Add('Canon EOS / Cinema')
        }
        if ($relUpper.Contains('100MEDIA') -or $relUpper.Contains('DJI') -or $ext -eq '.srt') {
            [void]$oemSet.Add('DJI / Drone Media')
        }
        if ($ext -eq '.aae' -or $ext -eq '.heic') {
            [void]$oemSet.Add('Apple iOS / Live Photo')
        }

        if ($inSys) {
            $result.systemForensicFilesCount++
            $result.systemForensicBytes += $f.Length
        } elseif ($f.Name.StartsWith('._')) {
            $result.macAppleDoubleCount++
            $result.macAppleDoubleBytes += $f.Length
            $rem = $f.Length % 131072
            $result.estimatedExfatSlackBytes += if ($rem -gt 0) { 131072 - $rem } else { 0 }
        } elseif ($OsJunkNames -contains $nameLower) {
            $result.dsStoreCount++
            $rem = $f.Length % 131072
            $result.estimatedExfatSlackBytes += if ($rem -gt 0) { 131072 - $rem } else { 0 }
        } else {
            if ($CreativeSidecarExts -contains $ext) {
                $result.creativeSidecarsCount++
                $result.creativeSidecarsBytes += $f.Length
            }
            $result.realFilesCount++
            $result.realFilesBytes += $f.Length
            $realSizes.Add([int64]$f.Length)
            $treeLeaves.Add("$($rel.Replace('/','\')):$($f.Length)")

            if ($f.Length -gt 0) {
                if ($sizeCounts.ContainsKey($f.Length)) {
                    $sizeCounts[$f.Length] = $sizeCounts[$f.Length] + 1
                } else {
                    $sizeCounts[$f.Length] = 1
                }
                if ($priorLedgerSizes.Contains($f.Length)) {
                    $result.priorMhlMatchedCount++
                }
            } else {
                $result.zeroByteRealFiles++
            }

            $rem = $f.Length % 131072
            if ($rem -gt 0) { $result.estimatedExfatSlackBytes += (131072 - $rem) }

            if (-not $result.extensions.Contains($ext)) {
                $result.extensions[$ext] = [ordered]@{ count = 0; bytes = [int64]0 }
            }
            $result.extensions[$ext].count++
            $result.extensions[$ext].bytes += $f.Length

            $baseLower = $f.BaseName.ToLowerInvariant()
            $baseKey = "$($f.DirectoryName)\$baseLower"
            if (-not $dirBaseMap.ContainsKey($baseKey)) {
                $dirBaseMap[$baseKey] = New-Object 'System.Collections.Generic.HashSet[string]'
            }
            [void]$dirBaseMap[$baseKey].Add($ext)

            if (-not ($CreativeSidecarExts -contains $ext) -and $baseLower -match '^([a-z_]+?)(\d{3,6})$') {
                $seqKey = "$($f.DirectoryName)\$($Matches[1])$ext"
                if (-not $seqMap.ContainsKey($seqKey)) {
                    $seqMap[$seqKey] = New-Object 'System.Collections.Generic.List[int]'
                }
                $seqMap[$seqKey].Add([int]$Matches[2])
            }
        }
    }

    foreach ($extSet in $dirBaseMap.Values) {
        if ($extSet.Contains('.mov') -and ($extSet.Contains('.heic') -or $extSet.Contains('.jpg') -or $extSet.Contains('.jpeg'))) {
            $result.livePhotoPairsCount++
        }
        $hasPrimaryMedia = $false
        $sidecarsInGroup = 0
        foreach ($e in $extSet) {
            if ($CreativeSidecarExts -contains $e) {
                if ($e -ne '.cube' -and $e -ne '.3dl') { $sidecarsInGroup++ }
            } else {
                $hasPrimaryMedia = $true
            }
        }
        if (-not $hasPrimaryMedia -and $sidecarsInGroup -gt 0) {
            $result.orphanSidecarsCount += $sidecarsInGroup
        }
    }

    if ($result.livePhotoPairsCount -gt 0) {
        [void]$oemSet.Add('Apple iOS / Live Photo')
    }
    $result.detectedCameraOems = @($oemSet | Sort-Object)
    if ($hasSonyM4Root -and (-not $hasSonyMediapro)) {
        $result.oemStructureWarnings = @('Sony M4ROOT\CLIP detected without MEDIAPRO.XML (NLE spanned-clip & LUT conform warning)')
    }

    foreach ($numList in $seqMap.Values) {
        if ($numList.Count -gt 1) {
            $uniqueSorted = @($numList | Sort-Object -Unique)
            for ($i = 1; $i -lt $uniqueSorted.Count; $i++) {
                if ($uniqueSorted[$i] -gt ($uniqueSorted[$i - 1] + 1)) {
                    $result.sequenceGapCount += ($uniqueSorted[$i] - $uniqueSorted[$i - 1] - 1)
                }
            }
        }
    }

    foreach ($kv in $sizeCounts.GetEnumerator()) {
        if ($kv.Value -gt 1) {
            $dupCnt = $kv.Value - 1
            $result.sameSizeDuplicateCount += $dupCnt
            $result.sameSizeDuplicateBytes += ([int64]$dupCnt * [int64]$kv.Key)
        }
    }

    if ($realSizes.Count -gt 0) {
        $realSizes.Sort()
        $n = $realSizes.Count
        $totalB = [double]$result.realFilesBytes
        $GetQuantileMB = {
            param([double]$p)
            $idx = [Math]::Min($n - 1, [int][Math]::Floor($n * $p))
            return [Math]::Round($realSizes[$idx] / 1MB, 2)
        }
        $medianB = $realSizes[[Math]::Min($n - 1, [int][Math]::Floor($n * 0.5))]
        $meanB = $totalB / $n
        $top10Count = [Math]::Max(1, [int][Math]::Floor($n * 0.1))
        $top10Bytes = [int64]0
        for ($i = $n - $top10Count; $i -lt $n; $i++) { $top10Bytes += $realSizes[$i] }

        $bDefs = @(
            [ordered]@{ label = '< 1 MB';     min = [int64]0;           max = [int64]1MB;   count = 0; bytes = [int64]0 },
            [ordered]@{ label = '1-10 MB';    min = [int64]1MB;         max = [int64]10MB;  count = 0; bytes = [int64]0 },
            [ordered]@{ label = '10-50 MB';   min = [int64]10MB;        max = [int64]50MB;  count = 0; bytes = [int64]0 },
            [ordered]@{ label = '50-150 MB';  min = [int64]50MB;        max = [int64]150MB; count = 0; bytes = [int64]0 },
            [ordered]@{ label = '150+ MB';    min = [int64]150MB;       max = [int64]::MaxValue; count = 0; bytes = [int64]0 }
        )
        foreach ($sz in $realSizes) {
            foreach ($b in $bDefs) {
                if ($sz -ge $b.min -and $sz -lt $b.max) {
                    $b.count++
                    $b.bytes += $sz
                    break
                }
            }
        }

        $totalMB = $totalB / 1MB
        $result.thinkStats = [ordered]@{
            n                 = $n
            minKB             = [Math]::Round($realSizes[0] / 1KB, 2)
            p10MB             = (& $GetQuantileMB 0.10)
            p25MB             = (& $GetQuantileMB 0.25)
            medianMB          = [Math]::Round($medianB / 1MB, 2)
            meanMB            = [Math]::Round($meanB / 1MB, 2)
            p75MB             = (& $GetQuantileMB 0.75)
            p90MB             = (& $GetQuantileMB 0.90)
            p99MB             = (& $GetQuantileMB 0.99)
            maxMB             = [Math]::Round($realSizes[$n - 1] / 1MB, 2)
            meanToMedianRatio = [Math]::Round($meanB / [Math]::Max(1.0, [double]$medianB), 2)
            top10PctByteShare = [Math]::Round(($top10Bytes / [Math]::Max(1.0, $totalB)) * 100.0, 1)
            buckets           = @($bDefs | ForEach-Object {
                [ordered]@{
                    label   = $_.label
                    count   = $_.count
                    filePct = [Math]::Round(($_.count / [double]$n) * 100.0, 1)
                    bytePct = [Math]::Round(($_.bytes / [Math]::Max(1.0, $totalB)) * 100.0, 1)
                }
            })
            bivariateEtaSec   = [ordered]@{
                copySec             = [int][Math]::Round(0.002 * $n + ($totalMB / 98.1))
                level1HashSec       = [int][Math]::Round(0.002 * $n + ($totalMB / 100.5))
                level2FfprobeSec    = [int][Math]::Round(0.023 * $n)
                level3DeepDecodeSec = [int][Math]::Round(0.05 * $n + ($totalMB / 29.8))
            }
        }

        $treeLeaves.Sort([System.StringComparer]::Ordinal)
        $sha = [System.Security.Cryptography.SHA256]::Create()
        try {
            $joinedBytes = [System.Text.Encoding]::UTF8.GetBytes(($treeLeaves -join '|'))
            $result.merkleStructureRoot = [System.BitConverter]::ToString($sha.ComputeHash($joinedBytes)).Replace('-', '')
        } finally {
            $sha.Dispose()
        }
    }

    return [PSCustomObject]$result
}
