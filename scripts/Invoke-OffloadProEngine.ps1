<#
.SYNOPSIS
    OffloadPro DIT Studio v4.3 - Upper-Echelon Pure PowerShell Media Offload Engine,
    Win32 SequentialScan/FlushFileBuffers I/O, Crash-Resumable Ingest, Full-Roll ASC-MHL + NLE (.ALE/.CSV) Sealer,
    Self-Healing Bitrot Repair (HealFromMirror), Reversible DIT Card Release (FakeFormatCard/RestoreCard),
    Automated Editorial & Dailies Proxies (GenerateProxies), Camera OEM Recognizer, Two-Stage Deduplication & 3-Level FFmpeg Validator.
.DESCRIPTION
    100% Native PowerShell 5.1 & PowerShell 7+ (.NET Framework 4.8 & .NET 8/9) compatible engine
    requiring zero Node.js runtime, zero npm packages, and zero localhost HTTP servers.
    Pure 7-bit ASCII source encoding for 100% deterministic parsing in Windows PowerShell 5.1 and PowerShell 7+.
    Supports -PassThru for strongly-typed PSCustomObject pipeline output alongside human-readable console logs.
    Returns deterministic CI/CD exit codes (0 = Verified Pass, 1 = Integrity/Gate Failure).
#>
param(
    [Parameter(Mandatory = $false)]
    [ValidateSet('Preflight', 'Offload', 'Certificate', 'VerifyMhl', 'HealFromMirror', 'FakeFormatCard', 'RestoreCard', 'GenerateProxies', 'OrganizeByDate', 'DedupeScan', 'CompareArchives', 'ExportTelemetry')]
    [string]$Action = 'Preflight',

    [Parameter(Mandatory = $false)]
    [string]$SourceRoot = '',

    [Parameter(Mandatory = $false)]
    [string]$DestinationRoot = '',

    [Parameter(Mandatory = $false)]
    [string]$SecondaryDestinationRoot = '',

    [Parameter(Mandatory = $false)]
    [string]$TargetPath = '',

    [Parameter(Mandatory = $false)]
    [string]$MhlPath = '',

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
    [ValidateSet('1080p', '720p', 'source')]
    [string]$ProxyResolution = '1080p',

    [Parameter(Mandatory = $false)]
    [ValidateSet('cpu', 'nvenc')]
    [string]$ProxyEncoder = 'cpu',

    [Parameter(Mandatory = $false)]
    [switch]$ProxyBurnIn,

    [Parameter(Mandatory = $false)]
    [switch]$ForceFormat,

    [Parameter(Mandatory = $false)]
    [switch]$RescueMode,

    [Parameter(Mandatory = $false)]
    [switch]$AllowOverwrite,

    [Parameter(Mandatory = $false)]
    [switch]$UseHardlinks,

    [Parameter(Mandatory = $false)]
    [switch]$PassThru,

    [Parameter(Mandatory = $false)]
    [bool]$VerifyLevel1 = $true,

    [Parameter(Mandatory = $false)]
    [bool]$VerifyLevel2 = $true,

    [Parameter(Mandatory = $false)]
    [bool]$VerifyLevel3 = $false,

    [Parameter(Mandatory = $false)]
    [int]$Threads = 6
)

$ErrorActionPreference = 'Stop'
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot  = Split-Path -Parent $ScriptDir
$TelemetryJsPath = Join-Path $RepoRoot 'public\offloadpro-telemetry.js'

$CreativeSidecarExts = @('.aae', '.xmp', '.xml', '.bim', '.cpi', '.mpl', '.srt', '.vtt', '.cube', '.3dl', '.thm', '.lrv')
$OsJunkNames         = @('.ds_store', 'thumbs.db', 'desktop.ini')

# --- Private functions: modules/OffloadPro/Private (one function per file) ---
$PrivateDir = Join-Path $RepoRoot 'modules\OffloadPro\Private'
foreach ($privateFile in @(Get-ChildItem -LiteralPath $PrivateDir -Filter '*.ps1' -File | Sort-Object Name)) {
    . $privateFile.FullName
}


Initialize-OffloadProPInvoke




















$script:ExitCodeToReturn = 0
Set-ExecutionAwakeLock -Enable $true
try {
    switch ($Action) {
        'Preflight' {
            $effectiveScanPath = if (-not [string]::IsNullOrWhiteSpace($TargetPath)) { $TargetPath } elseif (-not [string]::IsNullOrWhiteSpace($SourceRoot)) { $SourceRoot } else { 'D:\' }
            $vols = Get-MountedVolumesTelemetry
            $scan = Invoke-PreflightScan -ScanPath $effectiveScanPath
            $oems = if ($scan.detectedCameraOems.Count -gt 0) { $scan.detectedCameraOems -join ', ' } else { 'Generic Media' }
            Write-Host "================================================================" -ForegroundColor Cyan
            Write-Host "OffloadPro v4.1 Pre-Flight X-Ray (Pure PowerShell)" -ForegroundColor Cyan
            Write-Host "================================================================" -ForegroundColor Cyan
            Write-Host "Mounted Volumes Detected : $($vols.Count)"
            Write-Host "Detected Camera OEMs     : $oems"
            Write-Host "Real Media/User Files    : $($scan.realFilesCount) ($([Math]::Round($scan.realFilesBytes / 1GB, 3)) GB)"
            Write-Host "Protected Sidecars       : $($scan.creativeSidecarsCount) | Live Photo Pairs: $($scan.livePhotoPairsCount) | Orphan Sidecars: $($scan.orphanSidecarsCount)"
            Write-Host "Sequence Numbering Gaps  : $($scan.sequenceGapCount)"
            Write-Host "macOS ._* 4KB Sidecars   : $($scan.macAppleDoubleCount) ($([Math]::Round($scan.macAppleDoubleBytes / 1MB, 2)) MB)"
            Write-Host "exFAT 128KB Slack Waste  : ~$([Math]::Round($scan.estimatedExfatSlackBytes / 1MB, 1)) MB"
            if ($scan.oemStructureWarnings.Count -gt 0) {
                Write-Host "OEM Structure Warnings   : $($scan.oemStructureWarnings -join '; ')" -ForegroundColor Yellow
            }
            if ($scan.merkleStructureRoot) {
                Write-Host "SHA-256 Tree Merkle Root : $($scan.merkleStructureRoot)" -ForegroundColor Green
            }
            if ($PassThru) { Write-Output $scan }
        }
        'ExportTelemetry' {
            $vols = Get-MountedVolumesTelemetry
            $scan = Invoke-PreflightScan -ScanPath $TargetPath
            $payload = [ordered]@{
                generatedAt = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
                drives      = $vols
                preflight   = $scan
            }
            $json = $payload | ConvertTo-Json -Depth 8 -Compress
            Set-Content -LiteralPath $TelemetryJsPath -Value "window.__OFFLOADPRO_TELEMETRY__ = $json;" -Encoding UTF8
            Write-Host "Exported offline telemetry snapshot to public\offloadpro-telemetry.js" -ForegroundColor Green
            if ($PassThru) { Write-Output ([PSCustomObject]$payload) }
        }
        'Offload' {
            $offloadRes = Invoke-OffloadSession `
                -SourceRoot $SourceRoot `
                -DestinationRoot $DestinationRoot `
                -SecondaryDestinationRoot $SecondaryDestinationRoot `
                -CameraId $CameraId `
                -RollId $RollId `
                -Algorithm $Algorithm `
                -MacMode $MacMode `
                -RescueMode:$RescueMode `
                -AllowOverwrite:$AllowOverwrite `
                -VerifyLevel1:$VerifyLevel1 `
                -VerifyLevel2:$VerifyLevel2 `
                -VerifyLevel3:$VerifyLevel3 `
                -Threads $Threads `
                -PassThru:$PassThru
            if ($PassThru -and $null -ne $offloadRes) {
                Write-Output $offloadRes
            }
        }
        'Certificate' {
            New-MhlAndCertificate -ArchivePath $TargetPath -HashAlgorithm $Algorithm -MaxThreads $Threads
        }
        'VerifyMhl' {
            $mhlRes = Invoke-VerifyMhlLedger -ArchivePath $TargetPath -ExplicitMhlPath $MhlPath -MaxThreads $Threads
            if ($mhlRes.totalFailures -gt 0) {
                $script:ExitCodeToReturn = 1
            }
            if ($PassThru) { Write-Output $mhlRes }
        }
        'HealFromMirror' {
            $healRes = Invoke-HealFromMirror -ArchivePath $TargetPath -MirrorArchivePath $SourceRoot -ExplicitMhlPath $MhlPath -MaxThreads $Threads
            if ($healRes.unhealableCount -gt 0) {
                $script:ExitCodeToReturn = 1
            }
            if ($PassThru) { Write-Output $healRes }
        }
        'FakeFormatCard' {
            $fmtRes = Invoke-FakeFormatCard -CardPath $SourceRoot -VerifiedBackupPath $DestinationRoot -Force:$ForceFormat
            if ($PassThru) { Write-Output $fmtRes }
        }
        'RestoreCard' {
            $rstRes = Invoke-RestoreCard -CardPath $SourceRoot
            if ($PassThru) { Write-Output $rstRes }
        }
        'GenerateProxies' {
            $proxyRes = Invoke-GenerateProxies -SourceArchive $TargetPath -ProxyDestination $DestinationRoot -Resolution $ProxyResolution -Encoder $ProxyEncoder -BurnIn:$ProxyBurnIn -MaxThreads $Threads -AllowOverwrite:$true
            if ($proxyRes.failedCount -gt 0) {
                $script:ExitCodeToReturn = 1
            }
            if ($PassThru) { Write-Output $proxyRes }
        }
        'OrganizeByDate' {
            $orgRes = Invoke-OrganizeByDate -SourceArchive $SourceRoot -OrganizedRoot $DestinationRoot -CreateHardlinks:$UseHardlinks
            if ($PassThru) { Write-Output $orgRes }
        }
        'DedupeScan' {
            $dedupeRes = Invoke-DedupeScan -ArchivePath $TargetPath -HashAlgorithm $Algorithm -MaxThreads $Threads
            if ($PassThru) { Write-Output $dedupeRes }
        }
        'CompareArchives' {
            $cmpRes = Invoke-CompareArchives -ArchiveA $SourceRoot -ArchiveB $DestinationRoot
            if ($PassThru) { Write-Output $cmpRes }
        }
    }
} finally {
    Set-ExecutionAwakeLock -Enable $false
}

if ($script:ExitCodeToReturn -ne 0) {
    exit $script:ExitCodeToReturn
}
exit 0
