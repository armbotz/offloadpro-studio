<#
.SYNOPSIS
    OffloadPro - Professional Open-Source Media Offload & DIT Archival Engine.
.DESCRIPTION
    Pure PowerShell (5.1 & 7+) module providing verified single-read media offloading,
    100% full-roll ASC-MHL & NLE (.ALE/.CSV) generation, self-healing 3-2-1 vault repair,
    automated H.264 dailies proxy rendering, and reversible safe card release.
#>

$RepoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$PrivateDir = Join-Path $PSScriptRoot 'Private'
$TelemetryJsPath = Join-Path $RepoRoot 'public\offloadpro-telemetry.js'
$CreativeSidecarExts = @('.aae', '.xmp', '.xml', '.bim', '.cpi', '.mpl', '.srt', '.vtt', '.cube', '.3dl', '.thm', '.lrv')
$OsJunkNames         = @('.ds_store', 'thumbs.db', 'desktop.ini')
$script:ExitCodeToReturn = 0

# Dot-source all private functions
if (Test-Path -LiteralPath $PrivateDir) {
    foreach ($privFile in @(Get-ChildItem -LiteralPath $PrivateDir -Filter '*.ps1' -File | Sort-Object Name)) {
        . $privFile.FullName
    }
}

Initialize-OffloadProPInvoke

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
        [switch]$RescueMode,

        [Parameter(Mandatory = $false)]
        [switch]$AllowOverwrite,

        [Parameter(Mandatory = $false)]
        [bool]$VerifyLevel1 = $true,

        [Parameter(Mandatory = $false)]
        [bool]$VerifyLevel2 = $true,

        [Parameter(Mandatory = $false)]
        [bool]$VerifyLevel3 = $false,

        [Parameter(Mandatory = $false)]
        [int]$Threads = 6,

        [Parameter(Mandatory = $false)]
        [switch]$PassThru
    )
    process {
        Invoke-OffloadSession `
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
    Invoke-CompareArchives -ArchiveA $ArchiveA -ArchiveB $ArchiveB -PassThru:$PassThru
}

function Repair-MediaVault {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$PrimaryArchivePath,

        [Parameter(Mandatory = $true)]
        [string]$MirrorArchivePath,

        [Parameter(Mandatory = $false)]
        [string]$MhlPath = '',

        [Parameter(Mandatory = $false)]
        [int]$Threads = 6,

        [Parameter(Mandatory = $false)]
        [switch]$PassThru
    )
    Invoke-HealFromMirror -ArchivePath $PrimaryArchivePath -MirrorArchivePath $MirrorArchivePath -ExplicitMhlPath $MhlPath -MaxThreads $Threads -PassThru:$PassThru
}

function Test-MediaArchive {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ArchivePath,

        [Parameter(Mandatory = $false)]
        [string]$MhlPath = '',

        [Parameter(Mandatory = $false)]
        [int]$Threads = 6,

        [Parameter(Mandatory = $false)]
        [switch]$PassThru
    )
    Invoke-VerifyMhlLedger -ArchivePath $ArchivePath -ExplicitMhlPath $MhlPath -MaxThreads $Threads -PassThru:$PassThru
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
        [ValidateSet('cpu', 'nvenc')]
        [string]$Encoder = 'cpu',

        [Parameter(Mandatory = $false)]
        [switch]$BurnIn,

        [Parameter(Mandatory = $false)]
        [switch]$AllowOverwrite,

        [Parameter(Mandatory = $false)]
        [int]$Threads = 4,

        [Parameter(Mandatory = $false)]
        [switch]$PassThru
    )
    Invoke-GenerateProxies -SourceArchive $SourceArchivePath -ProxyDestination $ProxyDestination -Resolution $Resolution -Encoder $Encoder -BurnIn:$BurnIn -AllowOverwrite:$AllowOverwrite -MaxThreads $Threads -PassThru:$PassThru
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
        Invoke-FakeFormatCard -CardPath $CardPath -VerifiedBackupPath $VerifiedBackupPath -Force:$Force -PassThru:$PassThru
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
        Invoke-RestoreCard -CardPath $CardPath -PassThru:$PassThru
    }
}

function Get-CameraCardXRay {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$CardPath,

        [Parameter(Mandatory = $false)]
        [switch]$PassThru
    )
    Invoke-PreflightScan -ScanPath $CardPath
}

function Find-DuplicateMedia {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$ArchivePath,

        [Parameter(Mandatory = $false)]
        [ValidateSet('SHA256', 'MD5', 'SHA1')]
        [string]$Algorithm = 'SHA256',

        [Parameter(Mandatory = $false)]
        [int]$Threads = 6,

        [Parameter(Mandatory = $false)]
        [switch]$PassThru
    )
    Invoke-DedupeScan -ArchivePath $ArchivePath -HashAlgorithm $Algorithm -MaxThreads $Threads -PassThru:$PassThru
}

function Invoke-MediaOrganization {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$SourcePath,

        [Parameter(Mandatory = $true)]
        [string]$DestinationPath,

        [Parameter(Mandatory = $false)]
        [switch]$UseHardlinks,

        [Parameter(Mandatory = $false)]
        [switch]$PassThru
    )
    Invoke-OrganizeByDate -SourceArchive $SourcePath -OrganizedRoot $DestinationPath -CreateHardlinks:$UseHardlinks -PassThru:$PassThru
}

function Publish-MediaToDropbox {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ArchivePath,

        [Parameter(Mandatory = $false)]
        [ValidateSet('CertificatesOnly', 'FullRoll')]
        [string]$SyncMode = 'CertificatesOnly',

        [Parameter(Mandatory = $false)]
        [string]$DropboxRemoteFolder = '/OffloadPro_Vault',

        [Parameter(Mandatory = $false)]
        [string]$VaultFilePath = '',

        [Parameter(Mandatory = $false)]
        [string]$MockCloudRoot = '',

        [Parameter(Mandatory = $false)]
        [switch]$PassThru
    )
    Invoke-DropboxCloudSync `
        -ArchivePath $ArchivePath `
        -SyncMode $SyncMode `
        -DropboxRemoteFolder $DropboxRemoteFolder `
        -VaultFilePath $VaultFilePath `
        -MockCloudRoot $MockCloudRoot `
        -PassThru:$PassThru
}

function Start-OffloadProApp {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$InitialSourcePath = 'D:\',

        [Parameter(Mandatory = $false)]
        [string]$InitialDestinationPath = '',

        [Parameter(Mandatory = $false)]
        [switch]$HeadlessTest,

        [Parameter(Mandatory = $false)]
        [switch]$InProcessModal
    )
    Start-OffloadProStudioWindow `
        -InitialSourcePath $InitialSourcePath `
        -InitialDestinationPath $InitialDestinationPath `
        -HeadlessTest:$HeadlessTest `
        -InProcessModal:$InProcessModal
}

Export-ModuleMember -Function Start-OffloadProSession, Test-MediaParity, Repair-MediaVault, Test-MediaArchive, New-CameraProxy, Clear-CameraCard, Undo-CardClear, Get-CameraCardXRay, Find-DuplicateMedia, Invoke-MediaOrganization, Publish-MediaToDropbox, Start-OffloadProApp, Get-DropboxContentHash, Save-OffloadDropboxToken, Get-OffloadDropboxToken, Test-StudioGuiSafetyPreflight, Get-NextSequentialRollPath
