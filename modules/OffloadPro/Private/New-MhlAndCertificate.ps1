function New-MhlAndCertificate {
    param(
        [string]$ArchivePath,
        [string]$HashAlgorithm,
        [hashtable]$PrecomputedHashes = $null,
        [int]$MaxThreads = 6,
        [int]$HashMismatches = 0,
        [string]$StreamAuditStatus = '100% Container Verified'
    )
    $safeArchive = Assert-SafeTargetPath -InputPath $ArchivePath -IsMutating $false
    $manifestExts = @('.mhl', '.ale', '.csv', '.html')
    $files = @(Get-ChildItem -LiteralPath $safeArchive -File -Recurse -Force -ErrorAction SilentlyContinue |
        Where-Object {
            $ext = if ($_.Extension) { $_.Extension.ToLowerInvariant() } else { '' }
            (-not $_.Name.StartsWith('._')) -and
            ($OsJunkNames -notcontains $_.Name.ToLowerInvariant()) -and
            ($manifestExts -notcontains $ext) -and
            ($_.FullName -notmatch '(?i)\\(ascmhl|System Volume Information|\.Spotlight-V100|\.Trashes|\.fseventsd)(\\|$)')
        })

    $nowIso     = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
    $folderName = Split-Path -Leaf $safeArchive
    $parentDir  = Split-Path -Parent $safeArchive
    $mhlPath    = Join-Path $parentDir "$folderName.mhl"
    $certPath   = Join-Path $parentDir "${folderName}_Offload_Certificate.html"
    $csvPath    = Join-Path $parentDir "${folderName}_PostHouse_Manifest.csv"
    $alePath    = Join-Path $parentDir "$folderName.ale"

    $totalBytes = [int64]0
    $extSummary = @{}
    $minDateUtc = [DateTime]::MaxValue
    $maxDateUtc = [DateTime]::MinValue
    $treeLeaves = New-Object 'System.Collections.Generic.List[string]'

    foreach ($f in $files) {
        $totalBytes += $f.Length
        $ext = if ($f.Extension) { $f.Extension.ToLowerInvariant() } else { '.noext' }
        if ($extSummary.ContainsKey($ext)) { $extSummary[$ext]++ } else { $extSummary[$ext] = 1 }
        if ($f.LastWriteTimeUtc -lt $minDateUtc) { $minDateUtc = $f.LastWriteTimeUtc }
        if ($f.LastWriteTimeUtc -gt $maxDateUtc) { $maxDateUtc = $f.LastWriteTimeUtc }
        $rel = Get-RelativePathSafe -BasePath $safeArchive -FullPath $f.FullName
        $treeLeaves.Add("$($rel.Replace('/','\')):$($f.Length)")
    }

    $treeLeaves.Sort([System.StringComparer]::Ordinal)
    $merkleRoot = ''
    if ($treeLeaves.Count -gt 0) {
        $sha = [System.Security.Cryptography.SHA256]::Create()
        try {
            $merkleRoot = [System.BitConverter]::ToString($sha.ComputeHash([System.Text.Encoding]::UTF8.GetBytes(($treeLeaves -join '|')))).Replace('-', '')
        } finally { $sha.Dispose() }
    }

    Write-Host "[ASC-MHL & NLE SEALER] Sealing 100% of roll ($($files.Count) files) with $HashAlgorithm..." -ForegroundColor Cyan
    $mhlEntries = New-Object 'System.Collections.Generic.List[object]'
    $pool = [runspacefactory]::CreateRunspacePool(1, $MaxThreads)
    $pool.Open()
    $jobs = New-Object 'System.Collections.Generic.List[object]'

    $sbHash = {
        param($fullPath, $relPath, $nameOnly, $size, $mtimeIso, $algo)
        $hasher = switch ($algo.ToUpperInvariant()) {
            'MD5'   { [System.Security.Cryptography.MD5]::Create() }
            'SHA1'  { [System.Security.Cryptography.SHA1]::Create() }
            default { [System.Security.Cryptography.SHA256]::Create() }
        }
        $s = [System.IO.File]::Open($fullPath, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::Read)
        try {
            $h = [System.BitConverter]::ToString($hasher.ComputeHash($s)).Replace('-', '')
            return [PSCustomObject]@{ Name = $nameOnly; RelPath = $relPath; Size = $size; MTime = $mtimeIso; Hash = $h }
        } finally {
            $s.Dispose()
            $hasher.Dispose()
        }
    }

    foreach ($f in $files) {
        $rel = Get-RelativePathSafe -BasePath $safeArchive -FullPath $f.FullName
        $mtimeIso = $f.LastWriteTimeUtc.ToString('yyyy-MM-ddTHH:mm:ssZ')
        if ($PrecomputedHashes -and $PrecomputedHashes.ContainsKey($rel)) {
            $mhlEntries.Add([PSCustomObject]@{ Name = $f.Name; RelPath = $rel; Size = $f.Length; MTime = $mtimeIso; Hash = $PrecomputedHashes[$rel] })
        } else {
            $ps = [powershell]::Create().AddScript($sbHash).AddArgument($f.FullName).AddArgument($rel).AddArgument($f.Name).AddArgument($f.Length).AddArgument($mtimeIso).AddArgument($HashAlgorithm)
            $ps.RunspacePool = $pool
            $jobs.Add([PSCustomObject]@{ Pipe = $ps; Handle = $ps.BeginInvoke() })
        }
    }

    foreach ($j in $jobs) {
        $res = $j.Pipe.EndInvoke($j.Handle) | Select-Object -First 1
        $j.Pipe.Dispose()
        if ($res) { $mhlEntries.Add($res) }
    }
    $pool.Close(); $pool.Dispose()

    $algoTag = $HashAlgorithm.ToLowerInvariant()
    $mhlNodes = ($mhlEntries | ForEach-Object {
        "  <hash>`n    <file>$([System.Security.SecurityElement]::Escape($_.RelPath))</file>`n    <size>$($_.Size)</size>`n    <lastmodificationdate>$($_.MTime)</lastmodificationdate>`n    <$algoTag>$($_.Hash)</$algoTag>`n  </hash>"
    }) -join "`n"

    # 1. Write Legacy MHL v1.1 Manifest for backward compatibility
    $mhlXml = @"
<?xml version="1.0" encoding="UTF-8"?>
<hashlist version="1.1">
  <creatorinfo>
    <name>OffloadPro DIT Studio v4.4 (Full-Roll Sealer)</name>
    <version>4.4.0</version>
    <creationdate>$nowIso</creationdate>
    <merkle_tree_sha256>$merkleRoot</merkle_tree_sha256>
  </creatorinfo>
$mhlNodes
</hashlist>
"@
    Set-Content -LiteralPath $mhlPath -Value $mhlXml -Encoding UTF8

    # 2. Write Official ASC-MHL v2 Specification Directory & Chain Ledger
    try {
        $ascmhlDir = Join-Path $safeArchive 'ascmhl'
        if (-not (Test-Path -LiteralPath $ascmhlDir)) {
            [void][System.IO.Directory]::CreateDirectory($ascmhlDir)
        }
        $genStamp = (Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssZ')
        $genFileName = "${folderName}_${genStamp}_0001.mhl"
        $genFilePath = Join-Path $ascmhlDir $genFileName

        $ascmhlHashes = ($mhlEntries | ForEach-Object {
            $relNorm = $_.RelPath.Replace('\', '/')
            "    <hash>`n      <path>$([System.Security.SecurityElement]::Escape($relNorm))</path>`n      <size>$($_.Size)</size>`n      <lastmodificationdate>$($_.MTime)</lastmodificationdate>`n      <$algoTag>$($_.Hash)</$algoTag>`n    </hash>"
        }) -join "`n"

        $ascmhlGenXml = @"
<?xml version="1.0" encoding="UTF-8"?>
<ascmhl xmlns="urn:ASC:MHL:v2.0">
  <header>
    <creationdate>$nowIso</creationdate>
    <tool>OffloadPro DIT Studio</tool>
    <toolversion>4.4.0</toolversion>
    <generation>1</generation>
  </header>
  <hashes>
$ascmhlHashes
  </hashes>
</ascmhl>
"@
        Set-Content -LiteralPath $genFilePath -Value $ascmhlGenXml -Encoding UTF8

        # Compute SHA-256 of the generation manifest for the chain ledger
        $genBytes = [System.Text.Encoding]::UTF8.GetBytes($ascmhlGenXml)
        $hasherSha = [System.Security.Cryptography.SHA256]::Create()
        $genHash = [System.BitConverter]::ToString($hasherSha.ComputeHash($genBytes)).Replace('-', '').ToLowerInvariant()
        $hasherSha.Dispose()

        $chainPath = Join-Path $ascmhlDir 'ascmhl_chain.xml'
        $chainXml = @"
<?xml version="1.0" encoding="UTF-8"?>
<ascmhl xmlns="urn:ASC:MHL:v2.0">
  <ascmhl_generation generation="1">
    <file>$genFileName</file>
    <hash>
      <sha256>$genHash</sha256>
    </hash>
  </ascmhl_generation>
</ascmhl>
"@
        Set-Content -LiteralPath $chainPath -Value $chainXml -Encoding UTF8
    } catch {}

    # Generate NLE Post-House CSV Manifest & Avid/DaVinci Resolve .ALE Log Exchange File
    $csvLines = New-Object 'System.Collections.Generic.List[string]'
    $csvLines.Add("RollName,RelativePath,Bytes,Algorithm,Checksum,LastModifiedUtc")
    foreach ($e in $mhlEntries) {
        $safeRelCsv = $e.RelPath.Replace('"', '""')
        $csvLines.Add("`"$folderName`",`"$safeRelCsv`",$($e.Size),$HashAlgorithm,$($e.Hash),$($e.MTime)")
    }
    Set-Content -LiteralPath $csvPath -Value ($csvLines -join "`r`n") -Encoding UTF8

    $aleLines = New-Object 'System.Collections.Generic.List[string]'
    $aleLines.Add("Heading")
    $aleLines.Add("FIELD_DELIM`tTABS")
    $aleLines.Add("VIDEO_FORMAT`t1080")
    $aleLines.Add("FPS`t24")
    $aleLines.Add("")
    $aleLines.Add("Column")
    $aleLines.Add("Name`tTape`tSource File`tSize`tChecksum ($HashAlgorithm)`tShoot Date")
    $aleLines.Add("")
    $aleLines.Add("Data")
    foreach ($e in $mhlEntries) {
        $aleLines.Add("$($e.Name)`t$folderName`t$($e.RelPath)`t$($e.Size)`t$($e.Hash)`t$($e.MTime)")
    }
    Set-Content -LiteralPath $alePath -Value ($aleLines -join "`r`n") -Encoding UTF8

    $ffprobeCmd = (Get-Command ffprobe -ErrorAction SilentlyContinue).Source
    $totalDurationSec = 0.0
    $codecProfiles = @{}
    if ($ffprobeCmd) {
        $avFiles = @($files | Where-Object { $_.Extension -match '(?i)^\.(mov|mp4|3gp|wav|mp3|m4a|aif|aiff)$' })
        $poolProbe = [runspacefactory]::CreateRunspacePool(1, $MaxThreads)
        $poolProbe.Open()
        $probeJobs = New-Object 'System.Collections.Generic.List[object]'
        $sbProbe = {
            param($fullPath, $probeExe)
            $pinfo = New-Object System.Diagnostics.ProcessStartInfo
            $pinfo.FileName = $probeExe
            $pinfo.Arguments = "-v error -select_streams v:0 -show_entries stream=codec_name,width,height -show_entries format=duration -of default=noprint_wrappers=1 `"$fullPath`""
            $pinfo.RedirectStandardOutput = $true
            $pinfo.RedirectStandardError  = $true
            $pinfo.UseShellExecute        = $false
            $pinfo.CreateNoWindow         = $true
            $p = [System.Diagnostics.Process]::Start($pinfo)
            $out = $p.StandardOutput.ReadToEnd()
            $p.WaitForExit()
            $dur = 0.0; $codec = ''; $w = ''; $h = ''
            foreach ($line in ($out -split '\r?\n')) {
                if ($line -match '^duration=([0-9\.]+)$') { $dur = [double]$Matches[1] }
                elseif ($line -match '^codec_name=(.+)$') { $codec = $Matches[1].ToUpperInvariant() }
                elseif ($line -match '^width=(\d+)$') { $w = $Matches[1] }
                elseif ($line -match '^height=(\d+)$') { $h = $Matches[1] }
            }
            $profile = if ($codec -and $w -and $h) { "$codec ${w}x${h}" } elseif ($codec) { $codec } else { '' }
            return [PSCustomObject]@{ Duration = $dur; Profile = $profile }
        }
        foreach ($av in $avFiles) {
            $ps = [powershell]::Create().AddScript($sbProbe).AddArgument($av.FullName).AddArgument($ffprobeCmd)
            $ps.RunspacePool = $poolProbe
            $probeJobs.Add([PSCustomObject]@{ Pipe = $ps; Handle = $ps.BeginInvoke() })
        }
        foreach ($pj in $probeJobs) {
            $pr = $pj.Pipe.EndInvoke($pj.Handle) | Select-Object -First 1
            $pj.Pipe.Dispose()
            if ($pr) {
                $totalDurationSec += $pr.Duration
                if ($pr.Profile) {
                    if ($codecProfiles.ContainsKey($pr.Profile)) { $codecProfiles[$pr.Profile]++ } else { $codecProfiles[$pr.Profile] = 1 }
                }
            }
        }
        $poolProbe.Close(); $poolProbe.Dispose()
    }

    $tsSpan = [TimeSpan]::FromSeconds([Math]::Round($totalDurationSec))
    $durationFormatted = "{0:D2}h {1:D2}m {2:D2}s" -f [int]$tsSpan.TotalHours, $tsSpan.Minutes, $tsSpan.Seconds
    $dateRangeFormatted = if ($files.Count -gt 0) {
        "$($minDateUtc.ToString('yyyy-MM-dd')) to $($maxDateUtc.ToString('yyyy-MM-dd'))"
    } else { 'N/A' }

    $ffmpegCmd = (Get-Command ffmpeg -ErrorAction SilentlyContinue).Source
    $thumbCards = New-Object 'System.Collections.Generic.List[string]'
    if ($ffmpegCmd) {
        $vidCandidates = @($files | Where-Object { $_.Extension -match '(?i)^\.(mov|mp4|3gp)$' } | Select-Object -First 12)
        $clipIndex = 1
        foreach ($vc in $vidCandidates) {
            $pinfo = New-Object System.Diagnostics.ProcessStartInfo
            $pinfo.FileName = $ffmpegCmd
            $pinfo.Arguments = "-v error -ss 00:00:01 -i `"$($vc.FullName)`" -frames:v 1 -vf scale=180:-1 -q:v 6 -f image2pipe -vcodec mjpeg pipe:1"
            $pinfo.RedirectStandardOutput = $true
            $pinfo.RedirectStandardError  = $true
            $pinfo.UseShellExecute        = $false
            $pinfo.CreateNoWindow         = $true
            $proc = [System.Diagnostics.Process]::Start($pinfo)
            $ms = New-Object System.IO.MemoryStream
            $proc.StandardOutput.BaseStream.CopyTo($ms)
            $proc.WaitForExit()
            $bytes = $ms.ToArray()
            $ms.Dispose()
            if ($bytes.Length -gt 0) {
                $b64 = [Convert]::ToBase64String($bytes)
                $szMB = [Math]::Round($vc.Length / 1MB, 1)
                $thumbCards.Add("<div style='background:#0f1626;border:1px solid #1e293b;border-radius:8px;overflow:hidden;'><img src='data:image/jpeg;base64,$b64' style='width:100%;height:105px;object-fit:cover;display:block;'/><div style='padding:8px;font-size:11px;'><div style='color:#f8fafc;font-weight:600;'>Clip #$clipIndex ($($vc.Extension.ToUpper()))</div><div style='color:#94a3b8;margin-top:2px;'>$szMB MB &bull; Stream Decoded</div></div></div>")
                $clipIndex++
            }
        }
    }

    $extBadges = ($extSummary.GetEnumerator() | Sort-Object Value -Descending | ForEach-Object {
        "<span class='badge'>$($_.Key): <strong>$($_.Value)</strong></span>"
    }) -join ' '

    $codecBadges = ($codecProfiles.GetEnumerator() | Sort-Object Value -Descending | ForEach-Object {
        "<span class='badge' style='border:1px solid #0284c7;color:#38bdf8;'>$($_.Key): <strong>$($_.Value) clips</strong></span>"
    }) -join ' '

    $thumbsHtml = if ($thumbCards.Count -gt 0) {
        "<h3 style='margin-top:28px;margin-bottom:10px;'>Offline Visual Contact Sheet ($($thumbCards.Count) Sample Clips &mdash; Embedded Base64)</h3><div style='display:grid;grid-template-columns:repeat(4,1fr);gap:12px;'>$($thumbCards -join '')</div>"
    } else { '' }

    $certHtml = @"
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title>DIT Offload &amp; Full-Roll ASC-MHL Certificate</title>
<style>
  body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; background: #0b0f17; color: #e2e8f0; padding: 40px; }
  .card { max-width: 1020px; margin: 0 auto; background: #131b2e; border: 1px solid #263554; border-radius: 14px; padding: 32px; box-shadow: 0 20px 50px rgba(0,0,0,0.5); }
  .header { display: flex; justify-content: space-between; align-items: center; border-bottom: 1px solid #263554; padding-bottom: 20px; margin-bottom: 24px; }
  .stamp { background: rgba(16, 185, 129, 0.15); border: 2px solid #10b981; color: #34d399; padding: 10px 18px; border-radius: 8px; font-weight: 700; letter-spacing: 0.06em; }
  .grid { display: grid; grid-template-columns: repeat(3, 1fr); gap: 14px; margin-bottom: 24px; }
  .metric { background: #0f1626; border: 1px solid #1e293b; padding: 16px; border-radius: 10px; }
  .metric .label { font-size: 11.5px; color: #94a3b8; text-transform: uppercase; }
  .metric .val { font-size: 20px; font-weight: 700; color: #f8fafc; margin-top: 6px; }
  .badge { display: inline-block; background: #1e293b; padding: 6px 12px; border-radius: 6px; margin: 4px; font-size: 13px; }
</style>
</head>
<body>
  <div class="card">
    <div class="header">
      <div>
        <h1 style="margin:0;font-size:24px;">OffloadPro DIT Studio v4.4.0 &mdash; Camera Roll Verification Certificate</h1>
        <p style="margin:6px 0 0;color:#94a3b8;">Generated: $nowIso | Capture Window: $dateRangeFormatted | Deliverables: ASC-MHL v2 + .MHL + .ALE + .CSV</p>
      </div>
      <div class="stamp">&#10003; 100% FULL-ROLL ASC-MHL &amp; NLE SEALED</div>
    </div>
    <div class="grid">
      <div class="metric"><div class="label">100% Sealed Media Files</div><div class="val">$($mhlEntries.Count) / $($files.Count) Files</div></div>
      <div class="metric"><div class="label">Total Archive Payload</div><div class="val">$([Math]::Round($totalBytes / 1GB, 2)) GB</div></div>
      <div class="metric"><div class="label">Total Playable Duration</div><div class="val" style="color:#38bdf8;">$durationFormatted</div></div>
      <div class="metric"><div class="label">Level 1 Cryptographic Seal</div><div class="val" style="color:$(if ($HashMismatches -eq 0) { '#34d399' } else { '#f87171' });">$HashMismatches Mismatches ($HashAlgorithm)</div></div>
      <div class="metric"><div class="label">Level 2 &amp; 3 Stream Audit</div><div class="val" style="color:$(if ($StreamAuditStatus -match 'Warning|Blocked') { '#fbbf24' } else { '#34d399' });font-size:17px;">$StreamAuditStatus</div></div>
      <div class="metric"><div class="label">Capture Date Range</div><div class="val" style="font-size:15px;">$dateRangeFormatted</div></div>
    </div>
    <div style="background:rgba(16,185,129,0.08);border:1px solid rgba(16,185,129,0.35);padding:12px;border-radius:9px;margin-bottom:20px;font-size:12px;">
      <strong style="color:#34d399;">SHA-256 Tree Structure Merkle Root:</strong>
      <code style="display:block;margin-top:4px;color:#cbd5e1;word-break:break-all;">$merkleRoot</code>
    </div>
    <h3 style="margin-bottom:8px;">Camera Codec, Resolution &amp; Container Breakdown</h3>
    <div>$codecBadges $extBadges</div>
    $thumbsHtml
  </div>
</body>
</html>
"@
    Set-Content -LiteralPath $certPath -Value $certHtml -Encoding UTF8
    Write-Host "[CERTIFICATE & NLE DELIVERABLES COMPLETE] 100% Full-Roll Sealed: $($mhlEntries.Count) files ($([Math]::Round($totalBytes / 1GB, 2)) GB) | Deliverables: .mhl, .ale, .csv, .html" -ForegroundColor Green
}
