# Automated Editorial & Dailies Proxy Transcoding Engine (FFmpeg)
function Invoke-GenerateProxies {
    param(
        [string]$SourceArchive,
        [string]$ProxyDestination,
        [string]$Resolution = '1080p',
        [string]$Encoder = 'cpu',
        [switch]$BurnIn,
        [int]$MaxThreads = 4,
        [switch]$AllowOverwrite
    )
    $safeSrc = Assert-SafeTargetPath -InputPath $SourceArchive -IsMutating $false
    $folderName = Split-Path -Leaf $safeSrc
    $parentDir  = Split-Path -Parent $safeSrc
    $targetProxyRoot = if (-not [string]::IsNullOrWhiteSpace($ProxyDestination)) {
        $ProxyDestination
    } else {
        Join-Path $parentDir "${folderName}_Proxies"
    }
    $safeDst = Assert-SafeTargetPath -InputPath $targetProxyRoot -IsMutating $true

    $ffmpegCmd = (Get-Command ffmpeg -ErrorAction SilentlyContinue).Source
    if (-not $ffmpegCmd) {
        throw "ffmpeg executable was not found on PATH. Install ffmpeg to generate proxies."
    }

    $vidExts = @('.mov', '.mp4', '.m4v', '.mxf', '.braw', '.r3d', '.avi', '.mkv')
    $sourceFiles = @(Get-ChildItem -LiteralPath $safeSrc -File -Recurse -Force -ErrorAction SilentlyContinue |
        Where-Object {
            $ext = if ($_.Extension) { $_.Extension.ToLowerInvariant() } else { '' }
            ($vidExts -contains $ext) -and
            (-not ($_.Attributes -band [System.IO.FileAttributes]::ReparsePoint)) -and
            (-not $_.Name.StartsWith('._')) -and
            ($OsJunkNames -notcontains $_.Name.ToLowerInvariant()) -and
            ($_.FullName -notmatch '(?i)\\(ascmhl|System Volume Information|\.Spotlight-V100|\.Trashes|\.fseventsd)(\\|$)')
        })

    Write-Host "================================================================" -ForegroundColor Cyan
    Write-Host "OffloadPro v4.4 Editorial & Dailies Proxy Engine (FFmpeg)" -ForegroundColor Cyan
    Write-Host "================================================================" -ForegroundColor Cyan
    Write-Host "Target Video Clips       : $($sourceFiles.Count)"
    Write-Host "Proxy Profile            : H.264 $Resolution ($Encoder) | Burn-In: $(if ($BurnIn) { 'Active' } else { 'Off' })"

    $renderedCount = 0
    $resumedCount  = 0
    $failedCount   = 0

    $scaleFilter = switch ($Resolution) {
        '720p'   { "scale=-2:720" }
        'source' { "null" }
        default  { "scale=-2:1080" }
    }

    $vcodec = if ($Encoder -eq 'nvenc') { 'h264_nvenc' } else { 'libx264' }

    foreach ($sf in $sourceFiles) {
        $rel = Get-RelativePathSafe -BasePath $safeSrc -FullPath $sf.FullName
        $relNoExt = [System.IO.Path]::ChangeExtension($rel, '.mp4')
        $proxyFile = Join-Path $safeDst $relNoExt
        $proxyDir = Split-Path -Parent $proxyFile
        if (-not (Test-Path -LiteralPath $proxyDir)) {
            [void][System.IO.Directory]::CreateDirectory($proxyDir)
        }

        # Idempotent Proxy Checkpoint: Skip if proxy already exists and is non-empty
        if ((Test-Path -LiteralPath $proxyFile) -and (-not $AllowOverwrite)) {
            $pfi = Get-Item -LiteralPath $proxyFile -Force
            if ($pfi.Length -gt 1024) {
                $resumedCount++
                continue
            }
        }

        $filters = New-Object 'System.Collections.Generic.List[string]'
        if ($scaleFilter -ne 'null') { $filters.Add($scaleFilter) }
        if ($BurnIn) {
            $safeClipName = $sf.Name.Replace("'", "").Replace(":", "")
            $filters.Add("drawbox=y=ih-48:color=black@0.65:width=iw:height=48:t=fill,drawtext=text='ROLL: $folderName | CLIP: $safeClipName':fontcolor=white:fontsize=20:x=24:y=h-36")
        }
        $vfArg = if ($filters.Count -gt 0) { "-vf `"$($filters -join ',')`"" } else { "" }

        $pinfo = New-Object System.Diagnostics.ProcessStartInfo
        $pinfo.FileName = $ffmpegCmd
        $pinfo.Arguments = "-v error -y -i `"$($sf.FullName)`" $vfArg -c:v $vcodec -preset veryfast -crf 23 -pix_fmt yuv420p -c:a aac -b:a 160k -map_metadata 0 -movflags +faststart `"$proxyFile`""
        $pinfo.RedirectStandardOutput = $true
        $pinfo.RedirectStandardError  = $true
        $pinfo.UseShellExecute        = $false
        $pinfo.CreateNoWindow         = $true

        $proc = [System.Diagnostics.Process]::Start($pinfo)
        $errOut = $proc.StandardError.ReadToEnd()
        $proc.WaitForExit()

        if ($proc.ExitCode -eq 0 -and (Test-Path -LiteralPath $proxyFile)) {
            [System.IO.File]::SetCreationTimeUtc($proxyFile, $sf.CreationTimeUtc)
            [System.IO.File]::SetLastWriteTimeUtc($proxyFile, $sf.LastWriteTimeUtc)
            $renderedCount++
        } else {
            $failedCount++
        }
    }

    $color = if ($failedCount -eq 0) { 'Green' } else { 'Red' }
    Write-Host "[PROXY GENERATION COMPLETE] Target Clips: $($sourceFiles.Count) | Rendered: $renderedCount | Resumed/Cached: $resumedCount | Failed: $failedCount" -ForegroundColor $color

    return [PSCustomObject]@{
        targetClips   = $sourceFiles.Count
        renderedCount = $renderedCount
        resumedCount  = $resumedCount
        failedCount   = $failedCount
        proxyRoot     = $safeDst
    }
}
