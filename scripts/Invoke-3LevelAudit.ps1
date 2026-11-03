<#
.SYNOPSIS
    Runs the 3-Level Media & Bit-for-Bit Integrity Audit on a completed offload directory.
.DESCRIPTION
    - Level 1: Concurrent Bit-for-Bit MD5 Hash Verification (Source vs. Destination)
    - Level 2: FFprobe Container, moov Atom, Codec Keyframe & PDF Header Check
    - Level 3: FFmpeg Full-Stream Demux + Keyframe/Audio/Photo Decode Check
#>
param(
    [Parameter(Mandatory = $false)]
    [string]$SourceRoot = "D:\",

    [Parameter(Mandatory = $false)]
    [string]$DestinationRoot = "E:\Backups\Camera_Offload_001",

    [Parameter(Mandatory = $false)]
    [switch]$SkipLevel1Hash,

    [Parameter(Mandatory = $false)]
    [switch]$SkipLevel3DeepDecode,

    [Parameter(Mandatory = $false)]
    [int]$Threads = 6
)

$ErrorActionPreference = 'Continue'
$ffprobeCmd = (Get-Command ffprobe -ErrorAction SilentlyContinue).Source
$ffmpegCmd  = (Get-Command ffmpeg -ErrorAction SilentlyContinue).Source

if (-not $ffprobeCmd -or -not $ffmpegCmd) {
    Write-Error "FFmpeg / FFprobe not found in PATH. Install via: winget install Gyan.FFmpeg.Essentials"
    exit 1
}

$files = @(Get-ChildItem -Path $DestinationRoot -File -Recurse -Force -ErrorAction SilentlyContinue |
    Where-Object {
        $_.Name -notlike '._*' -and
        $_.Name -ne '.DS_Store' -and
        $_.FullName -notmatch '\\(System Volume Information|\.Spotlight-V100|\.Trashes)(\\|$)'
    })

Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "OffloadPro 3-Level Audit — Total Target Files: $($files.Count)" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan

# --- LEVEL 2: FFprobe Container & Header Check ---
Write-Host "`n[LEVEL 2] Running FFprobe Container, moov Atom & Header Check..." -ForegroundColor Yellow
$sw2 = [System.Diagnostics.Stopwatch]::StartNew()
$pool2 = [runspacefactory]::CreateRunspacePool(1, $Threads)
$pool2.Open()
$jobs2 = New-Object System.Collections.Generic.List[object]

$sbLevel2 = {
    param($fullName, $length, $ext, $ffprobePath)
    if ($length -eq 0) { return "ZERO_BYTE: $fullName" }
    $extLower = $ext.ToLower()
    if ($extLower -match '^\.(mov|mp4|3gp|jpg|jpeg|wav|mp3|m4a|aif|aiff)$') {
        $pinfo = New-Object System.Diagnostics.ProcessStartInfo
        $pinfo.FileName = $ffprobePath
        $pinfo.Arguments = "-v error -show_entries format=duration -of default=noprint_wrappers=1 `"$fullName`""
        $pinfo.RedirectStandardError = $true
        $pinfo.RedirectStandardOutput = $true
        $pinfo.UseShellExecute = $false
        $pinfo.CreateNoWindow = $true
        $p = [System.Diagnostics.Process]::Start($pinfo)
        $stderr = $p.StandardError.ReadToEnd()
        $p.WaitForExit()
        if ($p.ExitCode -ne 0) {
            return "CORRUPT_CONTAINER: $fullName -> $(($stderr -replace '\r|\n',' ').Trim())"
        }
    } elseif ($extLower -eq '.pdf') {
        $fs = [System.IO.File]::OpenRead($fullName)
        $buf = New-Object byte[] 5
        $read = $fs.Read($buf, 0, 5)
        $fs.Close()
        if ([System.Text.Encoding]::ASCII.GetString($buf, 0, $read) -ne '%PDF-') {
            return "CORRUPT_PDF: $fullName"
        }
    }
    return $null
}

foreach ($f in $files) {
    $ps = [powershell]::Create().AddScript($sbLevel2).AddArgument($f.FullName).AddArgument($f.Length).AddArgument($f.Extension).AddArgument($ffprobeCmd)
    $ps.RunspacePool = $pool2
    $jobs2.Add([PSCustomObject]@{ Pipe = $ps; Handle = $ps.BeginInvoke() })
}

$l2Issues = foreach ($j in $jobs2) {
    $r = $j.Pipe.EndInvoke($j.Handle)
    $j.Pipe.Dispose()
    if ($r) { $r }
}
$pool2.Close(); $pool2.Dispose(); $sw2.Stop()
Write-Host "[LEVEL 2 COMPLETE] $([math]::Round($sw2.Elapsed.TotalSeconds, 1))s | Corrupt Containers: $($l2Issues.Count)" -ForegroundColor Green

# --- LEVEL 1: Bit-for-Bit MD5 Check (Source vs Destination) ---
if (-not $SkipLevel1Hash -and (Test-Path -LiteralPath $SourceRoot)) {
    Write-Host "`n[LEVEL 1] Running Concurrent MD5 Bit-for-Bit Hash Check (Source vs Destination)..." -ForegroundColor Yellow
    $sw1 = [System.Diagnostics.Stopwatch]::StartNew()
    $hashPool = [runspacefactory]::CreateRunspacePool(1, 2)
    $hashPool.Open()
    $hashScript = {
        param($p)
        $md5 = [System.Security.Cryptography.MD5]::Create()
        $s = [System.IO.File]::Open($p, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::Read)
        try { return [System.BitConverter]::ToString($md5.ComputeHash($s)).Replace('-', '') }
        finally { $s.Dispose(); $md5.Dispose() }
    }
    $mainMd5 = [System.Security.Cryptography.MD5]::Create()
    $l1Issues = New-Object System.Collections.Generic.List[string]

    foreach ($f in $files) {
        $rel = $f.FullName.Substring($DestinationRoot.Length).TrimStart('\')
        $srcFile = Join-Path $SourceRoot $rel
        if (-not (Test-Path -LiteralPath $srcFile)) {
            $l1Issues.Add("MISSING_ON_SRC: $rel")
            continue
        }
        $psDst = [powershell]::Create().AddScript($hashScript).AddArgument($f.FullName)
        $psDst.RunspacePool = $hashPool
        $hHandle = $psDst.BeginInvoke()

        $srcStream = [System.IO.File]::Open($srcFile, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::Read)
        try { $hSrc = [System.BitConverter]::ToString($mainMd5.ComputeHash($srcStream)).Replace('-', '') }
        finally { $srcStream.Dispose() }

        $hDst = ($psDst.EndInvoke($hHandle) | Select-Object -First 1)
        $psDst.Dispose()
        if ($hSrc -ne $hDst) {
            $l1Issues.Add("HASH_MISMATCH: $rel (Src=$hSrc, Dst=$hDst)")
        }
    }
    $mainMd5.Dispose(); $hashPool.Close(); $hashPool.Dispose(); $sw1.Stop()
    Write-Host "[LEVEL 1 COMPLETE] $([math]::Round($sw1.Elapsed.TotalSeconds, 1))s | Hash Mismatches: $($l1Issues.Count)" -ForegroundColor Green
}

# --- LEVEL 3: FFmpeg Deep Stream & Keyframe/Audio Decode ---
if (-not $SkipLevel3DeepDecode) {
    Write-Host "`n[LEVEL 3] Running FFmpeg Deep Stream & Frame Decode Check..." -ForegroundColor Yellow
    $sw3 = [System.Diagnostics.Stopwatch]::StartNew()
    $pool3 = [runspacefactory]::CreateRunspacePool(1, $Threads)
    $pool3.Open()
    $jobs3 = New-Object System.Collections.Generic.List[object]

    $sbLevel3 = {
        param($fullName, $ext, $ffmpegPath)
        function Invoke-Decode($path, $useSkip) {
            $pinfo = New-Object System.Diagnostics.ProcessStartInfo
            $pinfo.FileName = $ffmpegPath
            $skipArg = if ($useSkip) { "-skip_frame nokey " } else { "" }
            $pinfo.Arguments = "-v error ${skipArg}-i `"$path`" -f null -"
            $pinfo.RedirectStandardError = $true
            $pinfo.RedirectStandardOutput = $true
            $pinfo.UseShellExecute = $false
            $pinfo.CreateNoWindow = $true
            $p = [System.Diagnostics.Process]::Start($pinfo)
            $stderr = $p.StandardError.ReadToEnd()
            $p.WaitForExit()
            return [PSCustomObject]@{ ExitCode = $p.ExitCode; StdErr = ($stderr -replace '\r|\n',' ').Trim() }
        }
        $isVidImg = $ext.ToLower() -match '^\.(mov|mp4|3gp|jpg|jpeg)$'
        $res = Invoke-Decode -path $fullName -useSkip $isVidImg
        if ($res.ExitCode -eq -22 -and $res.StdErr -match 'skip_frame') {
            $res = Invoke-Decode -path $fullName -useSkip $false
        }
        if ($res.ExitCode -ne 0) {
            return "CORRUPT_STREAM [Exit=$($res.ExitCode)]: $fullName -> $($res.StdErr)"
        }
        return $null
    }

    foreach ($f in $files | Where-Object { $_.Extension -match '^\.(mov|mp4|3gp|jpg|jpeg|wav|mp3|m4a|aif|aiff)$' }) {
        $ps = [powershell]::Create().AddScript($sbLevel3).AddArgument($f.FullName).AddArgument($f.Extension).AddArgument($ffmpegCmd)
        $ps.RunspacePool = $pool3
        $jobs3.Add([PSCustomObject]@{ Pipe = $ps; Handle = $ps.BeginInvoke() })
    }

    $l3Issues = foreach ($j in $jobs3) {
        $r = $j.Pipe.EndInvoke($j.Handle)
        $j.Pipe.Dispose()
        if ($r) { $r }
    }
    $pool3.Close(); $pool3.Dispose(); $sw3.Stop()
    Write-Host "[LEVEL 3 COMPLETE] $([math]::Round($sw3.Elapsed.TotalSeconds, 1))s | Corrupt Streams: $($l3Issues.Count)" -ForegroundColor Green
}
