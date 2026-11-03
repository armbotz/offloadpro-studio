<#
.SYNOPSIS
    OffloadPro DIT Studio v3.3 — Standalone Test-Driven Development (TDD) & Mutation Test Runner.
.DESCRIPTION
    Executes 7 deterministic Red/Green boundary, mutation, taxonomy, collision, organizer, and privacy
    invariant tests in an isolated temporary directory without touching any real drives.
    Returns ExitCode 0 when all 7 tests pass, or ExitCode 1 on any assertion failure.
#>
$ErrorActionPreference = 'Stop'
$ScriptDir  = Split-Path -Parent $MyInvocation.MyCommand.Path
$EnginePath = Join-Path $ScriptDir 'Invoke-OffloadProEngine.ps1'
$AuditPath  = Join-Path $ScriptDir 'Invoke-3LevelAudit.ps1'

$TempRoot   = Join-Path ([System.IO.Path]::GetTempPath()) "OffloadPro_TDD_$([guid]::NewGuid().ToString('N'))"
$MockSd     = Join-Path $TempRoot 'MockSD'
$DcimDir    = Join-Path $MockSd 'DCIM\100MEDIA'
$BackupDir  = Join-Path $TempRoot 'Backups\Roll_A001'
$OrgDir     = Join-Path $TempRoot 'Organized_Vault'

$Passed = 0
$Failed = 0

function Assert-Condition {
    param([bool]$Condition, [string]$TestName, [string]$FailureDetail)
    if ($Condition) {
        Write-Host "  [PASS] $TestName" -ForegroundColor Green
        $script:Passed++
    } else {
        Write-Host "  [FAIL] $TestName -> $FailureDetail" -ForegroundColor Red
        $script:Failed++
    }
}

Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "OffloadPro v3.3 TDD & Mutation Test Suite (Red/Green/Refactor)" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan

try {
    [void][System.IO.Directory]::CreateDirectory($DcimDir)

    # Seed synthetic camera roll:
    # - Sequence C0001.pdf, C0002.pdf, C0004.pdf (missing C0003 -> 1 sequence gap)
    # - Live Photo pair IMG_0001.jpg + IMG_0001.mov + edited IMG_0001.aae sidecar (with later mtime)
    # - Orphan sidecar IMG_9999.xmp (no matching primary media -> 1 orphan sidecar)
    # - Tier-2 macOS AppleDouble ._IMG_0001.jpg + .DS_Store
    $captureDate = [DateTime]::SpecifyKind([DateTime]::Parse('2026-06-15T14:30:00Z'), [DateTimeKind]::Utc)
    $laterEditDate = [DateTime]::SpecifyKind([DateTime]::Parse('2026-08-20T09:15:00Z'), [DateTimeKind]::Utc)

    foreach ($name in @('C0001.pdf', 'C0002.pdf', 'C0004.pdf')) {
        $p = Join-Path $DcimDir $name
        [System.IO.File]::WriteAllText($p, "%PDF-1.7`nSynthetic Camera Clip $name")
        [System.IO.File]::SetLastWriteTimeUtc($p, $captureDate)
    }

    $jpgPath = Join-Path $DcimDir 'IMG_0001.jpg'
    $movPath = Join-Path $DcimDir 'IMG_0001.mov'
    $aaePath = Join-Path $DcimDir 'IMG_0001.aae'
    $orphanPath = Join-Path $DcimDir 'IMG_9999.xmp'
    $appleDoublePath = Join-Path $DcimDir '._IMG_0001.jpg'
    $dsStorePath = Join-Path $DcimDir '.DS_Store'

    [System.IO.File]::WriteAllText($jpgPath, "SYNTHETIC_JPEG_PAYLOAD_0001")
    [System.IO.File]::SetLastWriteTimeUtc($jpgPath, $captureDate)
    [System.IO.File]::WriteAllText($movPath, "SYNTHETIC_MOV_PAYLOAD_0001")
    [System.IO.File]::SetLastWriteTimeUtc($movPath, $captureDate)
    [System.IO.File]::WriteAllText($aaePath, "<plist>Protected iOS Edit</plist>")
    [System.IO.File]::SetLastWriteTimeUtc($aaePath, $laterEditDate)
    [System.IO.File]::WriteAllText($orphanPath, "<x:xmpmeta>Orphan Sidecar</x:xmpmeta>")
    [System.IO.File]::WriteAllBytes($appleDoublePath, ([byte[]](0..63)))
    [System.IO.File]::WriteAllBytes($dsStorePath, ([byte[]](0..31)))

    # --- TEST 1: Pre-Flight Sequence Gap, Orphan Sidecar & Merkle Determinism ---
    $preflightOut = & $EnginePath -Action Preflight -TargetPath $MockSd *>&1 | Out-String
    Assert-Condition `
        -Condition ($preflightOut -match 'Sequence Numbering Gaps\s*:\s*1' -and $preflightOut -match 'Orphan Sidecars:\s*1' -and $preflightOut -match 'Live Photo Pairs:\s*1') `
        -TestName "Test 1: Pre-Flight detects Sequence Gaps (1), Orphan Sidecars (1) & Live Photo Pairs (1)" `
        -FailureDetail "Unexpected preflight output: $preflightOut"

    # --- TEST 2: Single-Read Offload & 3-Tier Sidecar Taxonomy Invariant ---
    $offloadOut = & $EnginePath -Action Offload -SourceRoot $MockSd -DestinationRoot $BackupDir -Algorithm SHA256 -MacMode forensic_split -VerifyLevel1 $true -VerifyLevel2 $false -VerifyLevel3 $false -Threads 2 *>&1 | Out-String
    $aaeSurvived   = Test-Path -LiteralPath (Join-Path $BackupDir 'DCIM\100MEDIA\IMG_0001.aae')
    $junkIsolated  = (Test-Path -LiteralPath (Join-Path "${BackupDir}_forensics" 'DCIM\100MEDIA\._IMG_0001.jpg')) -and
                     (-not (Test-Path -LiteralPath (Join-Path $BackupDir 'DCIM\100MEDIA\._IMG_0001.jpg')))
    Assert-Condition `
        -Condition ($aaeSurvived -and $junkIsolated) `
        -TestName "Test 2: 3-Tier Sidecar Taxonomy preserves .AAE in primary backup & routes ._* to _forensics" `
        -FailureDetail "aaeSurvived=$aaeSurvived, junkIsolated=$junkIsolated"

    # --- TEST 3: 100% Full-Roll ASC-MHL Sealing & Green VerifyMhl Pass ---
    $mhlFile = Join-Path (Split-Path -Parent $BackupDir) 'Roll_A001.mhl'
    [xml]$mhlXml = Get-Content -LiteralPath $mhlFile -Raw
    $sealedCount = @($mhlXml.hashlist.hash).Count
    $verifyGreenOut = & $EnginePath -Action VerifyMhl -TargetPath $BackupDir -Threads 2 *>&1 | Out-String
    Assert-Condition `
        -Condition ($sealedCount -eq 7 -and $verifyGreenOut -match 'Verified OK: 7/7' -and $verifyGreenOut -match 'Bitrot Hash Errors: 0') `
        -TestName "Test 3: 100% Full-Roll ASC-MHL Sealer seals all 7 real files & VerifyMhl passes (7/7)" `
        -FailureDetail "sealedCount=$sealedCount, out=$verifyGreenOut"

    # --- TEST 4: Red/Green Bit-Flip Mutation Test (VerifyMhl Must Catch 1-Byte Corruption & Exit 1) ---
    $targetPdf = Join-Path $BackupDir 'DCIM\100MEDIA\C0001.pdf'
    $origBytes = [System.IO.File]::ReadAllBytes($targetPdf)
    $mutatedBytes = [byte[]]$origBytes.Clone()
    $mutatedBytes[$mutatedBytes.Length - 1] = $mutatedBytes[$mutatedBytes.Length - 1] -bxor 1
    [System.IO.File]::WriteAllBytes($targetPdf, $mutatedBytes)

    $pwshExe = (Get-Process -Id $PID).Path
    $proc = Start-Process -FilePath $pwshExe -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $EnginePath, '-Action', 'VerifyMhl', '-TargetPath', $BackupDir, '-Threads', '2') -Wait -NoNewWindow -PassThru
    Assert-Condition `
        -Condition ($proc.ExitCode -eq 1) `
        -TestName "Test 4: Bit-Flip Mutation Test catches 1-bit corruption (same file size) & exits with code 1" `
        -FailureDetail "Expected ExitCode 1 on bit-flip mutation, got $($proc.ExitCode)"

    # Restore clean file bytes
    [System.IO.File]::WriteAllBytes($targetPdf, $origBytes)

    # --- TEST 5: Roll-Name Collision Guard Test ---
    [System.IO.File]::WriteAllText($targetPdf, "%PDF-1.7`nDIFFERENT_ROLL_COLLISION_SIZE_PAYLOAD_LONGER")
    $collisionBlocked = $false
    try {
        & $EnginePath -Action Offload -SourceRoot $MockSd -DestinationRoot $BackupDir -VerifyLevel1 $true -VerifyLevel2 $false
    } catch {
        if ($_.Exception.Message -match 'DIT ROLL-COLLISION GUARD BLOCKED') {
            $collisionBlocked = $true
        }
    }
    Assert-Condition `
        -Condition $collisionBlocked `
        -TestName "Test 5: Roll-Name Collision Guard blocks accidental overwrite of different-sized roll clip" `
        -FailureDetail "Collision guard did not throw expected exception."
    [System.IO.File]::WriteAllBytes($targetPdf, $origBytes)

    # --- TEST 6: Non-Destructive Sidecar-Glued Date Organizer (-Action OrganizeByDate) ---
    [void](& $EnginePath -Action OrganizeByDate -SourceRoot $BackupDir -DestinationRoot $OrgDir *>&1)
    # Even though IMG_0001.aae was edited on 2026-08-20, it MUST be glued into 2026\2026-06-15 with IMG_0001.jpg and IMG_0001.mov!
    $expectedBucket = Join-Path $OrgDir '2026\2026-06-15'
    $gluedTogether = (Test-Path -LiteralPath (Join-Path $expectedBucket 'IMG_0001.jpg')) -and
                     (Test-Path -LiteralPath (Join-Path $expectedBucket 'IMG_0001.mov')) -and
                     (Test-Path -LiteralPath (Join-Path $expectedBucket 'IMG_0001.aae'))
    Assert-Condition `
        -Condition $gluedTogether `
        -TestName "Test 6: OrganizeByDate glues Live Photo (.JPG+.MOV) and later-edited .AAE into same YYYY\YYYY-MM-DD bucket" `
        -FailureDetail "Files were not glued into $expectedBucket"

    # --- TEST 7: Zero-PII stdout Privacy Invariant ---
    $combinedStdout = "$preflightOut`n$offloadOut`n$verifyGreenOut"
    $leakedPii = $combinedStdout -match '(IMG_0001|IMG_9999|C0001\.pdf|C0002\.pdf)'
    Assert-Condition `
        -Condition (-not $leakedPii) `
        -TestName "Test 7: Zero-PII stdout Privacy Invariant (0 personal filenames printed to console)" `
        -FailureDetail "Personal filename detected in stdout!"

} finally {
    Remove-Item -LiteralPath $TempRoot -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host "----------------------------------------------------------------" -ForegroundColor Cyan
Write-Host "TDD Summary: $Passed Passed, $Failed Failed" -ForegroundColor $(if ($Failed -eq 0) { 'Green' } else { 'Red' })
if ($Failed -gt 0) { exit 1 }
exit 0
