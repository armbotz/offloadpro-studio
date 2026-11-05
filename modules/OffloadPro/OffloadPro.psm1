<#
.SYNOPSIS
    OffloadPro - Professional Open-Source Media Offload & DIT Archival Engine.
.DESCRIPTION
    Pure PowerShell (5.1 & 7+) module providing verified single-read media offloading,
    100% full-roll ASC-MHL & NLE (.ALE/.CSV) generation, self-healing 3-2-1 vault repair,
    automated H.264 dailies proxy rendering, and reversible safe card release.
#>

$RepoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$EngineScript = Join-Path $RepoRoot 'scripts\Invoke-OffloadProEngine.ps1'

function Start-OffloadProSession {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
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
        [switch]$PassThru
    )
    process {
        $params = @{
            Action           = 'Offload'
            SourceRoot       = $SourceRoot
            DestinationRoot  = $DestinationRoot
            Algorithm        = $Algorithm
            MacMode          = $MacMode
            CameraId         = $CameraId
            RollId           = $RollId
            PassThru         = $PassThru
        }
        if ($SecondaryDestinationRoot) {
            $params['SecondaryDestinationRoot'] = $SecondaryDestinationRoot
        }
        & $EngineScript @params
    }
}

function Test-MediaParity {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$ArchiveA,

        [Parameter(Mandatory = $true, Position = 1)]
        [string]$ArchiveB,

        [Parameter(Mandatory = $false)]
        [switch]$PassThru
    )
    & $EngineScript -Action CompareArchives -SourceRoot $ArchiveA -DestinationRoot $ArchiveB -PassThru:$PassThru
}

function Repair-MediaVault {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$PrimaryArchivePath,

        [Parameter(Mandatory = $true)]
        [string]$MirrorArchivePath,

        [Parameter(Mandatory = $false)]
        [switch]$PassThru
    )
    & $EngineScript -Action HealFromMirror -TargetPath $PrimaryArchivePath -SourceRoot $MirrorArchivePath -PassThru:$PassThru
}

function New-CameraProxy {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$SourceArchivePath,

        [Parameter(Mandatory = $false)]
        [string]$ProxyDestination = '',

        [Parameter(Mandatory = $false)]
        [ValidateSet('1080p', '720p', 'source')]
        [string]$Resolution = '1080p',

        [Parameter(Mandatory = $false)]
        [switch]$BurnIn,

        [Parameter(Mandatory = $false)]
        [switch]$PassThru
    )
    & $EngineScript -Action GenerateProxies -TargetPath $SourceArchivePath -DestinationRoot $ProxyDestination -ProxyResolution $Resolution -ProxyBurnIn:$BurnIn -PassThru:$PassThru
}

function Clear-CameraCard {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory = $true)]
        [string]$CardPath,

        [Parameter(Mandatory = $false)]
        [string]$VerifiedBackupPath = '',

        [Parameter(Mandatory = $false)]
        [switch]$Force,

        [Parameter(Mandatory = $false)]
        [switch]$PassThru
    )
    if ($PSCmdlet.ShouldProcess($CardPath, "Reversibly inverting 2 MiB partition header (XOR 0xFF fake-format)")) {
        & $EngineScript -Action FakeFormatCard -SourceRoot $CardPath -DestinationRoot $VerifiedBackupPath -ForceFormat:$Force -PassThru:$PassThru
    }
}

function Undo-CardClear {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory = $true)]
        [string]$CardPath,

        [Parameter(Mandatory = $false)]
        [switch]$PassThru
    )
    if ($PSCmdlet.ShouldProcess($CardPath, "Re-inverting 2 MiB partition header back to original readable state")) {
        & $EngineScript -Action RestoreCard -SourceRoot $CardPath -PassThru:$PassThru
    }
}

Export-ModuleMember -Function Start-OffloadProSession, Test-MediaParity, Repair-MediaVault, New-CameraProxy, Clear-CameraCard, Undo-CardClear
