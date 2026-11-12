<#
.SYNOPSIS
    Cryptographically verified Dropbox 3-2-1 Cloud Sync with Windows DPAPI credential
    protection and 4 MB block SHA-256 Merkle content_hash verification.
#>

function Get-DropboxContentHash {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath
    )
    if (-not (Test-Path -LiteralPath $FilePath)) {
        throw "File not found for Dropbox content_hash computation: $FilePath"
    }

    $blockSize = 4 * 1024 * 1024 # 4 MiB (4,194,304 bytes) per Dropbox specification
    $overallHasher = [System.Security.Cryptography.SHA256]::Create()
    $blockHasher   = [System.Security.Cryptography.SHA256]::Create()
    $stream = [System.IO.File]::Open($FilePath, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::Read)

    try {
        $buffer = New-Object byte[] $blockSize
        $concatenatedBlockHashes = New-Object 'System.Collections.Generic.List[byte]'

        while ($true) {
            $bytesRead = 0
            while ($bytesRead -lt $blockSize) {
                $n = $stream.Read($buffer, $bytesRead, ($blockSize - $bytesRead))
                if ($n -le 0) { break }
                $bytesRead += $n
            }
            if ($bytesRead -le 0) { break }

            $chunkHash = $blockHasher.ComputeHash($buffer, 0, $bytesRead)
            $concatenatedBlockHashes.AddRange($chunkHash)
            if ($bytesRead -lt $blockSize) { break }
        }

        if ($concatenatedBlockHashes.Count -eq 0) {
            $emptyChunkHash = $blockHasher.ComputeHash((New-Object byte[] 0))
            $concatenatedBlockHashes.AddRange($emptyChunkHash)
        }

        $finalBytes = $overallHasher.ComputeHash($concatenatedBlockHashes.ToArray())
        return ([System.BitConverter]::ToString($finalBytes).Replace('-', '').ToLowerInvariant())
    } finally {
        $stream.Dispose()
        $blockHasher.Dispose()
        $overallHasher.Dispose()
    }
}

function Get-OffloadDpapiVaultPath {
    param([string]$CustomVaultPath = '')
    if (-not [string]::IsNullOrWhiteSpace($CustomVaultPath)) {
        return $CustomVaultPath
    }
    $baseAppData = if (-not [string]::IsNullOrWhiteSpace($env:LOCALAPPDATA)) {
        $env:LOCALAPPDATA
    } elseif (-not [string]::IsNullOrWhiteSpace($HOME)) {
        Join-Path $HOME '.local/share'
    } else {
        [System.IO.Path]::GetTempPath()
    }
    $vaultDir = Join-Path $baseAppData 'OffloadPro\Vault'
    if (-not (Test-Path -LiteralPath $vaultDir)) {
        [void][System.IO.Directory]::CreateDirectory($vaultDir)
    }
    return (Join-Path $vaultDir 'dropbox_token.dpapi.txt')
}

function Get-CrossPlatformVaultKey {
    $userPart = if ($env:USERNAME) { $env:USERNAME } elseif ($env:USER) { $env:USER } else { 'OffloadUser' }
    $machPart = [System.Environment]::MachineName
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        return $sha.ComputeHash([System.Text.Encoding]::UTF8.GetBytes("OffloadProVault::$userPart@$machPart"))
    } finally {
        $sha.Dispose()
    }
}

function Save-OffloadDropboxToken {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$PlainToken,

        [Parameter(Mandatory = $false)]
        [string]$VaultFilePath = ''
    )
    $trimmed = $PlainToken.Trim()
    if ([string]::IsNullOrWhiteSpace($trimmed) -or $trimmed.Length -lt 12) {
        throw "Invalid Dropbox API token: token must be at least 12 characters."
    }

    $targetVault = Get-OffloadDpapiVaultPath -CustomVaultPath $VaultFilePath
    $parentDir = Split-Path -Parent $targetVault
    if (-not (Test-Path -LiteralPath $parentDir)) {
        [void][System.IO.Directory]::CreateDirectory($parentDir)
    }

    $secStr = ConvertTo-SecureString -String $trimmed -AsPlainText -Force
    $encryptedHex = try {
        ConvertFrom-SecureString -SecureString $secStr -ErrorAction Stop
    } catch {
        ConvertFrom-SecureString -SecureString $secStr -Key (Get-CrossPlatformVaultKey)
    }
    [System.IO.File]::WriteAllText($targetVault, $encryptedHex, [System.Text.Encoding]::ASCII)

    return [PSCustomObject]@{
        saved     = $true
        vaultPath = $targetVault
        encrypted = $true
    }
}

function Get-OffloadDropboxToken {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$VaultFilePath = ''
    )
    $targetVault = Get-OffloadDpapiVaultPath -CustomVaultPath $VaultFilePath
    if (-not (Test-Path -LiteralPath $targetVault)) {
        return ''
    }
    $encContent = ([System.IO.File]::ReadAllText($targetVault, [System.Text.Encoding]::ASCII)).Trim()
    if ([string]::IsNullOrWhiteSpace($encContent)) {
        return ''
    }
    $secStr = try {
        ConvertTo-SecureString -String $encContent -ErrorAction Stop
    } catch {
        ConvertTo-SecureString -String $encContent -Key (Get-CrossPlatformVaultKey)
    }
    $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secStr)
    try {
        return [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)
    } finally {
        [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
    }
}

function Invoke-DropboxCloudSync {
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

    $safeArchive = Assert-SafeTargetPath -InputPath $ArchivePath -IsMutating $false
    $folderName  = Split-Path -Leaf $safeArchive
    $parentDir   = Split-Path -Parent $safeArchive

    $candidateFiles = New-Object 'System.Collections.Generic.List[object]'

    # Gather companion root manifests (.mhl, .ale, .csv, .html)
    $companionPaths = @(
        (Join-Path $parentDir "$folderName.mhl"),
        (Join-Path $parentDir "$folderName.ale"),
        (Join-Path $parentDir "${folderName}_PostHouse_Manifest.csv"),
        (Join-Path $parentDir "${folderName}_Offload_Certificate.html")
    )
    foreach ($cp in $companionPaths) {
        if (Test-Path -LiteralPath $cp) {
            $fItem = Get-Item -LiteralPath $cp -Force
            $candidateFiles.Add([PSCustomObject]@{
                FullPath = $fItem.FullName
                RelPath  = $fItem.Name
                Size     = $fItem.Length
            })
        }
    }

    # Include internal ascmhl manifests or full roll files
    if ($SyncMode -eq 'CertificatesOnly') {
        $ascDir = Join-Path $safeArchive 'ascmhl'
        if (Test-Path -LiteralPath $ascDir) {
            foreach ($af in @(Get-ChildItem -LiteralPath $ascDir -File -Recurse -Force -ErrorAction SilentlyContinue)) {
                $rel = Get-RelativePathSafe -BasePath $safeArchive -FullPath $af.FullName
                $candidateFiles.Add([PSCustomObject]@{
                    FullPath = $af.FullName
                    RelPath  = "$folderName/$($rel.Replace('\','/'))"
                    Size     = $af.Length
                })
            }
        }
    } else {
        foreach ($rf in @(Get-ChildItem -LiteralPath $safeArchive -File -Recurse -Force -ErrorAction SilentlyContinue)) {
            if ($rf.Name.StartsWith('._') -or ($OsJunkNames -contains $rf.Name.ToLowerInvariant())) { continue }
            $rel = Get-RelativePathSafe -BasePath $safeArchive -FullPath $rf.FullName
            $candidateFiles.Add([PSCustomObject]@{
                FullPath = $rf.FullName
                RelPath  = "$folderName/$($rel.Replace('\','/'))"
                Size     = $rf.Length
            })
        }
    }

    if ($candidateFiles.Count -eq 0) {
        throw "No deliverable files found to sync for archive: $folderName"
    }

    $uploadedCount = 0
    $verifiedHashes = 0
    $hashMismatches = 0
    $totalBytesSynced = [int64]0

    $cleanRemoteBase = $DropboxRemoteFolder.Trim().Replace('\', '/')
    if (-not $cleanRemoteBase.StartsWith('/')) { $cleanRemoteBase = '/' + $cleanRemoteBase }
    $cleanRemoteBase = $cleanRemoteBase.TrimEnd('/')

    if (-not [string]::IsNullOrWhiteSpace($MockCloudRoot)) {
        # Deterministic offline test mode using local directory simulating Dropbox content_hash verification
        if (-not (Test-Path -LiteralPath $MockCloudRoot)) {
            [void][System.IO.Directory]::CreateDirectory($MockCloudRoot)
        }
        foreach ($cf in $candidateFiles) {
            $localContentHash = Get-DropboxContentHash -FilePath $cf.FullPath
            $mockDestFile = Join-Path $MockCloudRoot ($cf.RelPath.Replace('/', '\'))
            $mockDestDir  = Split-Path -Parent $mockDestFile
            if (-not (Test-Path -LiteralPath $mockDestDir)) {
                [void][System.IO.Directory]::CreateDirectory($mockDestDir)
            }
            [System.IO.File]::Copy($cf.FullPath, $mockDestFile, $true)
            $remoteContentHash = Get-DropboxContentHash -FilePath $mockDestFile

            $uploadedCount++
            $totalBytesSynced += $cf.Size
            if ($localContentHash -eq $remoteContentHash) {
                $verifiedHashes++
            } else {
                $hashMismatches++
            }
        }
    } else {
        $token = Get-OffloadDropboxToken -VaultFilePath $VaultFilePath
        if ([string]::IsNullOrWhiteSpace($token)) {
            throw "No Dropbox API token found in Windows DPAPI Vault. Save your token first using Save-OffloadDropboxToken or the Studio Cloud tab."
        }

        foreach ($cf in $candidateFiles) {
            $localContentHash = Get-DropboxContentHash -FilePath $cf.FullPath
            $remotePath = "$cleanRemoteBase/$($cf.RelPath.TrimStart('/'))"
            $apiArgObj = @{
                path            = $remotePath
                mode            = 'overwrite'
                autorename      = $false
                mute            = $true
                strict_conflict = $false
            }
            $apiArgJson = ConvertTo-Json -InputObject $apiArgObj -Compress

            $headers = @{
                'Authorization'   = "Bearer $token"
                'Dropbox-API-Arg' = $apiArgJson
                'Content-Type'    = 'application/octet-stream'
            }

            $resp = Invoke-RestMethod -Uri 'https://content.dropboxapi.com/2/files/upload' `
                -Method Post `
                -Headers $headers `
                -InFile $cf.FullPath `
                -ErrorAction Stop

            $uploadedCount++
            $totalBytesSynced += $cf.Size
            if ($resp.content_hash -and ($resp.content_hash.ToLowerInvariant() -eq $localContentHash)) {
                $verifiedHashes++
            } else {
                $hashMismatches++
                throw "Dropbox cloud content_hash mismatch! Expected $localContentHash, got $($resp.content_hash)"
            }
        }
    }

    Write-Host "[DROPBOX 3-2-1 SYNC] Uploaded $uploadedCount file(s) ($verifiedHashes/$uploadedCount 4MB-Block SHA-256 content_hash verified)." -ForegroundColor Green

    $res = [PSCustomObject]@{
        syncMode          = $SyncMode
        uploadedCount     = $uploadedCount
        verifiedHashes    = $verifiedHashes
        hashMismatches    = $hashMismatches
        totalBytesSynced  = $totalBytesSynced
        status            = if ($hashMismatches -eq 0) { 'VERIFIED_CLOUD_SYNC' } else { 'CLOUD_HASH_MISMATCH' }
    }
    if ($PassThru) { return $res }
}
